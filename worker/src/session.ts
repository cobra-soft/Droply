import { DurableObject } from 'cloudflare:workers';
import { Env, FilePreview, WSMessage } from './types';

interface StoredFile {
  id: string;
  r2_key: string;
}

/**
 * One Durable Object per session.
 *
 * Uses the WebSocket Hibernation API (`ctx.acceptWebSocket` + `ctx.getWebSockets`).
 * All mutable state is mirrored into `ctx.storage` and lazily reloaded because
 * the in-memory fields are lost whenever the object hibernates or is evicted.
 */
export class SessionDO extends DurableObject<Env> {
  private files: FilePreview[] = [];
  private filesFull: StoredFile[] = [];
  private expiresAt = 0;
  private loaded = false;
  private loadPromise: Promise<void> | null = null;

  // Kept as a live Set of every socket we have accepted in this incarnation.
  // It is merged with ctx.getWebSockets() for broadcasting so that sockets
  // restored by hibernation are still reached even though they are not in
  // this Set after a restart.
  private clients = new Set<WebSocket>();

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
  }

  private async ensureLoaded(): Promise<void> {
    if (this.loaded) return;
    if (!this.loadPromise) {
      this.loadPromise = (async () => {
        this.files = ((await this.ctx.storage.get('files')) as FilePreview[]) ?? [];
        this.filesFull = ((await this.ctx.storage.get('files_full')) as StoredFile[]) ?? [];
        this.expiresAt = ((await this.ctx.storage.get('expiresAt')) as number) ?? 0;
      })();
    }
    await this.loadPromise;
    this.loaded = true;
  }

  async init(ttl: number, expiresAt: number): Promise<void> {
    await this.ensureLoaded();
    this.expiresAt = expiresAt;
    await this.ctx.storage.put('ttl', ttl);
    await this.ctx.storage.put('expiresAt', expiresAt);
    await this.ctx.storage.put('files', this.files);
    await this.ctx.storage.put('files_full', this.filesFull);
    await this.scheduleAlarm();
  }

  /** Arm the alarm at (expiresAt - 60s) so we can emit session_expiring first. */
  private async scheduleAlarm(): Promise<void> {
    const now = Date.now();
    if (!this.expiresAt || this.expiresAt <= now) {
      await this.ctx.storage.setAlarm(now);
      return;
    }
    const warnAt = this.expiresAt - 60_000;
    await this.ctx.storage.setAlarm(warnAt > now ? warnAt : this.expiresAt);
  }

  // --- HTTP / WebSocket upgrade ------------------------------------------------
  async fetch(request: Request): Promise<Response> {
    const upgrade = (request.headers.get('upgrade') ?? '').toLowerCase();
    if (upgrade !== 'websocket') {
      return new Response('expected websocket', { status: 400 });
    }

    await this.ensureLoaded();

    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];

    this.ctx.acceptWebSocket(server);
    this.clients.add(server);

    // Hibernation API has no "open" callback, so the initial snapshot is
    // pushed here, immediately after the socket is accepted.
    this.send(server, { type: 'init', files: this.files });

    return new Response(null, { status: 101, webSocket: client });
  }

  // --- WebSocket lifecycle -----------------------------------------------------
  async webSocketOpen(ws: WebSocket): Promise<void> {
    this.clients.add(ws);
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    await this.ensureLoaded();

    let data: { type?: string };
    try {
      data = JSON.parse(typeof message === 'string' ? message : new TextDecoder().decode(message));
    } catch {
      return;
    }

    // Clients may request a fresh file list.
    if (data?.type === 'init') {
      this.send(ws, { type: 'init', files: this.files });
    }
  }

  async webSocketClose(ws: WebSocket, code: number, reason: string, wasClean: boolean): Promise<void> {
    this.clients.delete(ws);
  }

  async webSocketError(ws: WebSocket, error: unknown): Promise<void> {
    this.clients.delete(ws);
  }

  // --- TTL ---------------------------------------------------------------------
  async alarm(): Promise<void> {
    await this.ensureLoaded();
    const now = Date.now();

    // Warning alarm: session is still alive → notify, then re-arm for expiry.
    if (this.expiresAt && now < this.expiresAt - 1_000) {
      this.broadcastRaw({ type: 'session_expiring' });
      await this.ctx.storage.setAlarm(this.expiresAt);
      return;
    }

    await this.expireSession();
  }

  private async expireSession(): Promise<void> {
    this.broadcastRaw({ type: 'session_expiring' });

    for (const ws of this.allSockets()) {
      try { ws.close(1001, 'Session expired'); } catch { /* ignore */ }
    }
    this.clients.clear();

    for (const f of this.filesFull) {
      try { await this.env.BUCKET.delete(f.r2_key); } catch { /* ignore */ }
    }

    this.files = [];
    this.filesFull = [];
    this.expiresAt = 0;
    await this.ctx.storage.deleteAll();
  }

  // --- Helpers -----------------------------------------------------------------
  /** Union of live sockets from hibernation state and this incarnation's Set. */
  private allSockets(): Set<WebSocket> {
    const sockets = new Set<WebSocket>(this.ctx.getWebSockets());
    for (const ws of this.clients.values()) sockets.add(ws);
    return sockets;
  }

  /** Called by the Worker router when a file is added to this session. */
  async fileAdded(file: { id: string; name: string; size: number; r2_key: string }): Promise<void> {
    await this.ensureLoaded();

    if (!this.files.some((f) => f.id === file.id)) {
      this.files.unshift({ id: file.id, name: file.name, size: file.size });
      await this.ctx.storage.put('files', this.files);
    }
    if (!this.filesFull.some((f) => f.id === file.id)) {
      this.filesFull.unshift({ id: file.id, r2_key: file.r2_key });
      await this.ctx.storage.put('files_full', this.filesFull);
    }

    const preview: FilePreview = { id: file.id, name: file.name, size: file.size };
    this.broadcastRaw({ type: 'file_added', file: preview });
  }

  /** Remove a file preview and its R2 object (manual delete). */
  async fileRemoved(fileId: string): Promise<void> {
    await this.ensureLoaded();

    this.files = this.files.filter((f) => f.id !== fileId);
    await this.ctx.storage.put('files', this.files);

    const removed = this.filesFull.find((f) => f.id === fileId);
    if (removed) {
      try { await this.env.BUCKET.delete(removed.r2_key); } catch { /* ignore */ }
    }
    this.filesFull = this.filesFull.filter((f) => f.id !== fileId);
    await this.ctx.storage.put('files_full', this.filesFull);

    this.broadcastRaw({ type: 'file_removed', fileId });
  }

  private broadcastRaw(msg: WSMessage): void {
    const payload = JSON.stringify(msg);
    for (const ws of this.allSockets()) {
      this.sendRaw(ws, payload);
    }
  }

  private send(ws: WebSocket, msg: WSMessage): void {
    this.sendRaw(ws, JSON.stringify(msg));
  }

  private sendRaw(ws: WebSocket, payload: string): void {
    try { ws.send(payload); } catch { /* ignore */ }
  }
}
