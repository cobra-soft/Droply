import { Env, CreateSessionResponse, SessionInfo, SessionStub, sessionUrl, MIN_TTL_MINUTES, MAX_TTL_MINUTES, MAX_FILE_SIZE, isAllowedExtension } from './types';
import { DB } from './db';
import { R2Store, r2Key } from './r2';
import { checkRateLimit } from './rateLimit';

export { SessionDO } from './session';
export { RateLimiterDO } from './rateLimit';

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const clientIP = request.headers.get('cf-connecting-ip') ?? 'unknown';
    const reqOrigin = request.headers.get('origin') ?? '';

    // Разрешенные origenы фронтенда (задаются через wrangler vars / .dev.vars).
    // Если пусто — разрешаем любой origin (для локальной разработки без переменных).
    const allowedOrigins = (env.ALLOWED_ORIGINS ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);

    // Отвечаем только тем origin, который в whitelist (или своему, если списка нет).
    const resolveOrigin = (): string => {
      if (!reqOrigin) return url.origin;
      if (allowedOrigins.length === 0 || allowedOrigins.includes(reqOrigin)) {
        return reqOrigin;
      }
      return url.origin;
    };
    const origin = resolveOrigin();

    // Health check
    if (pathname === '/api/health') {
      return new Response(JSON.stringify({ ok: true }), { headers: { 'content-type': 'application/json' } });
    }

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(env, origin) });
    }

    const db = new DB(env.DB);
    const r2 = new R2Store(env.BUCKET);
    const now = Date.now();

    // ---------------- WS /api/sessions/:id/ws ------------------------------
    // Must be checked before the plain GET /api/sessions/:id route below.
    const wsMatch = pathname.match(/^\/api\/sessions\/([0-9]{4})\/ws$/);
    if (wsMatch) {
      const sessionId = wsMatch[1];

      // Reject unknown/expired IDs *before* touching the Durable Object.
      // Otherwise connecting to a random 4-digit ID would spin up (and leak)
      // an empty DO — an easy way to exhaust the DO quota.
      const session = await db.getSession(sessionId);
      if (!session || session.expires_at <= now) {
        return json({ error: 'Session not found or expired' }, 404, env, origin);
      }

      const id = env.SESSIONS.idFromName(sessionId);
      const stub = env.SESSIONS.get(id) as unknown as SessionStub;
      // Forward the upgrade request as-is; the Durable Object owns the
      // WebSocket pair and connection lifecycle.
      return stub.fetch(request);
    }

    // ---------------- POST /api/sessions --------------------------------
    if (pathname === '/api/sessions' && request.method === 'POST') {
      // CSRF / Origin check. Same-origin requests are always allowed (so a
      // custom domain attached to the Worker keeps working); when a whitelist
      // is configured, cross-origin requests must be on it.
      const sameOrigin = reqOrigin === url.origin;
      if (reqOrigin && !sameOrigin && allowedOrigins.length > 0 && !allowedOrigins.includes(reqOrigin)) {
        return json({ error: 'Invalid origin' }, 403, env, origin);
      }

      // Rate limit: session creation (5/min/IP)
      const createLimit = await checkRateLimit(env, clientIP, 'session-create', 60 * 1000, 5);
      if (!createLimit.allowed) {
        return json({ error: 'Too many sessions. Try again later.' }, 429, env, origin, { 'Retry-After': String(Math.ceil(createLimit.resetIn / 1000)) });
      }

      // Active sessions per IP limit (<= 3)
      const activeCount = await db.getActiveSessionCountByIP(clientIP, now);
      if (activeCount >= 3) {
        return json({ error: 'Maximum active sessions reached.' }, 429, env, origin);
      }

      let body: { ttl?: number };
      try { body = await request.json(); } catch { return json({ error: 'Invalid JSON' }, 400, env, origin); }

      const ttl = Number(body.ttl);
      if (!Number.isFinite(ttl) || ttl < MIN_TTL_MINUTES || ttl > MAX_TTL_MINUTES) {
        return json({ error: `ttl must be between ${MIN_TTL_MINUTES} and ${MAX_TTL_MINUTES} minutes` }, 400, env, origin);
      }

      // Generate unique 4-digit session id
      let sessionId: string;
      let attempts = 0;
      do {
        sessionId = String(Math.floor(1000 + Math.random() * 9000));
        attempts++;
        if (attempts > 100) {
          return json({ error: 'Unable to generate session id' }, 500, env, origin);
        }
      } while (await db.getSession(sessionId));

      const createdAt = now;
      const expiresAt = createdAt + ttl * 60 * 1000;

      await db.createSession(sessionId, createdAt, expiresAt, ttl, clientIP);

      // Init Durable Object
      const id = env.SESSIONS.idFromName(sessionId);
      const stub = env.SESSIONS.get(id) as unknown as SessionStub;
      await stub.init(ttl, expiresAt);

      const res: CreateSessionResponse = {
        sessionId: sessionId,
        expiresAt,
        url: sessionUrl(url.host, sessionId),
      };
      return json(res, 200, env, origin);
    }

    // ---------------- GET /api/sessions/:id --------------------------------
    const sessionMatch = pathname.match(/^\/api\/sessions\/([0-9]{4})$/);
    if (sessionMatch && request.method === 'GET') {
      const sessionId = sessionMatch[1];

      // Rate limit: session info lookup (20/min/IP) — защита от brute-force
      // 4-значных sessionId (9000 комбинаций).
      const lookupLimit = await checkRateLimit(env, clientIP, 'session-lookup', 60 * 1000, 20);
      if (!lookupLimit.allowed) {
        return json({ error: 'Too many requests. Try again later.' }, 429, env, origin, { 'Retry-After': String(Math.ceil(lookupLimit.resetIn / 1000)) });
      }

      const session = await db.getSession(sessionId);
      if (!session || session.expires_at <= now) {
        return json({ error: 'Session not found or expired' }, 404, env, origin);
      }
      const files = await db.getFilesBySession(sessionId);
      const info: SessionInfo = {
        id: session.id,
        expires_at: session.expires_at,
        ttl_minutes: session.ttl_minutes,
        files: files.map((f) => ({ id: f.id, name: f.original_name, size: f.size })),
      };
      return json(info, 200, env, origin);
    }

    // ---------------- POST /api/sessions/:id/upload -----------------------
    const uploadMatch = pathname.match(/^\/api\/sessions\/([0-9]{4})\/upload$/);
    if (uploadMatch && request.method === 'POST') {
      const sessionId = uploadMatch[1];

      // Session must exist and not be expired
      const session = await db.getSession(sessionId);
      if (!session || session.expires_at <= now) {
        return json({ error: 'Session not found or expired' }, 404, env, origin);
      }

      // Rate limit: uploads (10/min/IP)
      const upLimit = await checkRateLimit(env, clientIP, 'upload', 60 * 1000, 10);
      if (!upLimit.allowed) {
        return json({ error: 'Too many uploads. Try again later.' }, 429, env, origin, { 'Retry-After': String(Math.ceil(upLimit.resetIn / 1000)) });
      }

      // Parse multipart
      const contentType = request.headers.get('content-type') ?? '';
      // Ранний отказ до чтения тела: если boundary отсутствует, форма невалидна.
      const boundaryMatch = contentType.match(/boundary=([^\s;]+)/);
      if (!boundaryMatch) {
        return json({ error: 'Missing multipart boundary' }, 400, env, origin);
      }

      const formData = await request.formData();
      // workers-types declares FormData.get() as string | null even for file
      // parts; at runtime a file part is a File, so widen to unknown first.
      const entry: unknown = formData.get('file');
      if (!(entry instanceof File)) {
        return json({ error: 'No file provided' }, 400, env, origin);
      }
      const file = entry;

      if (file.size > MAX_FILE_SIZE) {
        return json({ error: 'File too large (max 50 MB)' }, 400, env, origin);
      }

      if (!isAllowedExtension(file.name)) {
        return json({ error: 'File type not allowed' }, 400, env, origin);
      }

      // MIME sniffing from first bytes (buffer) - do not trust client header
      const arrayBuffer = await file.arrayBuffer();
      const sniffed = sniffMime(new Uint8Array(arrayBuffer));
      const mime = sniffed ?? file.type ?? 'application/octet-stream';

      const fileId = crypto.randomUUID();
      const key = r2Key(fileId, file.name);

      await r2.putFile(key, arrayBuffer, file.name, mime);
      await db.createFile(fileId, sessionId, key, file.name, file.size, mime, now);

      // Notify Durable Object (real-time) — must include r2_key, otherwise
      // the DO's own expiry cleanup has no key to delete from R2 with.
      const id = env.SESSIONS.idFromName(sessionId);
      const stub = env.SESSIONS.get(id) as unknown as SessionStub;
      await stub.fileAdded({ id: fileId, name: file.name, size: file.size, r2_key: key });

      return json({ id: fileId, name: file.name, size: file.size }, 201, env, origin);
    }

    // ---------------- GET /api/files/:fileId ------------------------------
    const fileMatch = pathname.match(/^\/api\/files\/([^/]+)$/);
    if (fileMatch && request.method === 'GET') {
      const fileId = fileMatch[1];
      const file = await db.getFile(fileId);
      if (!file) {
        return json({ error: 'File not found' }, 404, env, origin);
      }
      const session = await db.getSession(file.session_id);
      if (!session || session.expires_at <= now) {
        return json({ error: 'Session expired' }, 410, env, origin);
      }

      // Stream straight from the R2 binding — no need for an S3-compatible
      // presigned URL (and the separate R2 API token that would require):
      // the Worker already has direct access to the bucket.
      const object = await r2.getFile(file.r2_key);
      if (!object) {
        return json({ error: 'File not found in storage' }, 404, env, origin);
      }

      const headers = new Headers();
      object.writeHttpMetadata(headers);
      headers.set('content-disposition', `attachment; filename*=UTF-8''${encodeURIComponent(file.original_name)}`);
      headers.set('cache-control', 'private, max-age=0, no-store');
      headers.set('access-control-allow-origin', origin);
      return new Response(object.body, { status: 200, headers });
    }

    // ---------------- DELETE /api/files/:fileId (optional) ----------------
    if (fileMatch && request.method === 'DELETE') {
      const fileId = fileMatch[1];

      // Rate limit: file deletion (10/min/IP) — защита от brute-force удаления
      // чужих файлов перебором id.
      const delLimit = await checkRateLimit(env, clientIP, 'file-delete', 60 * 1000, 10);
      if (!delLimit.allowed) {
        return json({ error: 'Too many requests. Try again later.' }, 429, env, origin, { 'Retry-After': String(Math.ceil(delLimit.resetIn / 1000)) });
      }

      const file = await db.getFile(fileId);
      if (!file) {
        return json({ error: 'File not found' }, 404, env, origin);
      }
      const session = await db.getSession(file.session_id);
      if (!session || session.expires_at <= now) {
        return json({ error: 'Session expired' }, 410, env, origin);
      }

      const id = env.SESSIONS.idFromName(file.session_id);
      const stub = env.SESSIONS.get(id) as unknown as SessionStub;
      await stub.fileRemoved(fileId);
      await db.deleteFile(fileId);

      return json({ ok: true }, 200, env, origin);
    }

    // ---------------- Not found ------------------------------
    // Static assets are served by Cloudflare Workers Static Assets
    // (wrangler.toml [assets] section). Any request that reaches this point
    // did not match an API route and did not match a static file.
    return new Response('Not found', { status: 404 });
  },

  /** Hourly cron: purge expired sessions from D1 AND their files from R2. */
  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    const db = new DB(env.DB);
    const r2 = new R2Store(env.BUCKET);
    const now = Date.now();

    // Read the R2 keys BEFORE the rows are deleted — otherwise there is no
    // way to know which objects belonged to the sessions just removed.
    const keys = await db.getExpiredFileKeys(now);
    await db.cleanupExpired(now);
    for (const key of keys) {
      try { await r2.deleteFile(key); } catch { /* ignore */ }
    }
  },
};

function json(data: unknown, status: number, env: Env, origin: string, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json', ...corsHeaders(env, origin), ...extra },
  });
}

function corsHeaders(env: Env, origin: string): Record<string, string> {
  const allowedOrigins = (env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  const headers: Record<string, string> = {
    'access-control-allow-methods': 'GET, POST, DELETE, OPTIONS',
    'access-control-allow-headers': 'Content-Type',
  };

  // Если задан whitelist — отдаём ACAO только для разрешённых origin.
  // Если пусто — разрешаем любой (локальная разработка без переменных).
  if (allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
    headers['access-control-allow-origin'] = origin;
  }

  return headers;
}

/** Sniff MIME type from first bytes (magic numbers). Do not trust client header. */
function sniffMime(buf: Uint8Array): string | null {
  if (buf.length < 4) return null;
  const b = buf;

  // PDF
  if (b[0] === 0x25 && b[1] === 0x50 && b[2] === 0x44 && b[3] === 0x46) return 'application/pdf';
  // PNG
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return 'image/png';
  // JPEG
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return 'image/jpeg';
  // GIF
  if (b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46) return 'image/gif';
  // WebP
  if (b[0] === 0x52 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x46 && b.length >= 12 && b[8] === 0x57 && b[9] === 0x45 && b[10] === 0x42 && b[11] === 0x50) return 'image/webp';
  // ZIP / EPUB / ODF / JAR
  if (b[0] === 0x50 && b[1] === 0x4b && b[2] === 0x03 && b[3] === 0x04) return 'application/zip';
  // GZIP
  if (b[0] === 0x1f && b[1] === 0x8b) return 'application/gzip';
  // MP4
  if (b.length >= 12 && b[4] === 0x66 && b[5] === 0x74 && b[6] === 0x79 && b[7] === 0x70) return 'video/mp4';
  // MKV (EBML)
  if (b[0] === 0x1a && b[1] === 0x45 && b[2] === 0xdf && b[3] === 0xa3) return 'video/x-matroska';
  // MP3 (ID3)
  if (b[0] === 0x49 && b[1] === 0x44 && b[2] === 0x33) return 'audio/mpeg';
  // MP3 (MPEG frame sync)
  if (b[0] === 0xff && (b[1] & 0xf0) === 0xf0) return 'audio/mpeg';
  // RAR
  if (b[0] === 0x52 && b[1] === 0x61 && b[2] === 0x72 && b[3] === 0x21) return 'application/vnd.rar';
  // 7z
  if (b[0] === 0x37 && b[1] === 0x7a && b[2] === 0xbc && b[3] === 0xaf) return 'application/x-7z-compressed';
  // ELF / EXE (MZ)
  if (b[0] === 0x4d && b[1] === 0x5a) return 'application/x-msdownload';
  // Python text
  if (b[0] === 0x23 && b[1] === 0x21) return 'text/x-python';

  return null;
}
