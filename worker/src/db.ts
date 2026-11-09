import { D1Database } from '@cloudflare/workers-types';
import { Session, File } from './types';

export class DB {
  constructor(private db: D1Database) {}

  async createSession(
    id: string,
    createdAt: number,
    expiresAt: number,
    ttlMinutes: number,
    creatorIp: string,
  ): Promise<void> {
    await this.db
      .prepare(
        'INSERT INTO sessions (id, created_at, expires_at, ttl_minutes, creator_ip) VALUES (?, ?, ?, ?, ?)',
      )
      .bind(id, createdAt, expiresAt, ttlMinutes, creatorIp)
      .run();
  }

  async getSession(id: string): Promise<Session | null> {
    return this.db
      .prepare('SELECT * FROM sessions WHERE id = ?')
      .bind(id)
      .first<Session>();
  }

  async getActiveSessionCountByIP(ip: string, now: number): Promise<number> {
    const { results } = await this.db
      .prepare(
        'SELECT COUNT(*) as cnt FROM sessions WHERE creator_ip = ? AND expires_at > ?',
      )
      .bind(ip, now)
      .all<{ cnt: number }>();
    return (results?.[0]?.cnt ?? 0) as number;
  }

  async createFile(
    id: string,
    sessionId: string,
    r2Key: string,
    originalName: string,
    size: number,
    mime: string,
    uploadedAt: number,
  ): Promise<void> {
    await this.db
      .prepare(
        'INSERT INTO files (id, session_id, r2_key, original_name, size, mime, uploaded_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      )
      .bind(id, sessionId, r2Key, originalName, size, mime, uploadedAt)
      .run();
  }

  async getFilesBySession(sessionId: string): Promise<File[]> {
    const { results } = await this.db
      .prepare(
        'SELECT * FROM files WHERE session_id = ? ORDER BY uploaded_at DESC',
      )
      .bind(sessionId)
      .all<File>();
    return (results ?? []) as File[];
  }

  async getFile(fileId: string): Promise<File | null> {
    return this.db
      .prepare('SELECT * FROM files WHERE id = ?')
      .bind(fileId)
      .first<File>();
  }

  async deleteFile(fileId: string): Promise<void> {
    await this.db.prepare('DELETE FROM files WHERE id = ?').bind(fileId).run();
  }

  /** R2 keys of files belonging to sessions that have already expired.
   *  Must be read BEFORE cleanupExpired() deletes the rows. */
  async getExpiredFileKeys(now: number): Promise<string[]> {
    const { results } = await this.db
      .prepare(
        'SELECT r2_key FROM files WHERE session_id IN (SELECT id FROM sessions WHERE expires_at < ?)',
      )
      .bind(now)
      .all<{ r2_key: string }>();
    return (results ?? []).map((r) => r.r2_key);
  }

  async cleanupExpired(now: number): Promise<void> {
    await this.db
      .prepare(
        'DELETE FROM files WHERE session_id IN (SELECT id FROM sessions WHERE expires_at < ?)',
      )
      .bind(now)
      .run();
    await this.db
      .prepare('DELETE FROM sessions WHERE expires_at < ?')
      .bind(now)
      .run();
  }
}
