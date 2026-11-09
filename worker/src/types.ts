export interface Session {
  id: string;
  created_at: number;
  expires_at: number;
  ttl_minutes: number;
  creator_ip: string;
}

export interface File {
  id: string;
  session_id: string;
  r2_key: string;
  original_name: string;
  size: number;
  mime: string;
  uploaded_at: number;
}

export interface FilePreview {
  id: string;
  name: string;
  size: number;
}

export interface CreateSessionResponse {
  sessionId: string;
  expiresAt: number;
  url: string;
}

export interface SessionInfo {
  id: string;
  expires_at: number;
  ttl_minutes: number;
  files: FilePreview[];
}

export interface Env {
  DB: D1Database;
  BUCKET: R2Bucket;
  SESSIONS: DurableObjectNamespace;
  RATE_LIMITER: DurableObjectNamespace;
  ALLOWED_ORIGINS?: string;
}

/** RPC methods exposed by SessionDO (called on the Durable Object stub). */
export type SessionStub = DurableObjectStub & {
  init(ttl: number, expiresAt: number): Promise<void>;
  fileAdded(file: { id: string; name: string; size: number; r2_key: string }): Promise<void>;
  fileRemoved(fileId: string): Promise<void>;
};

/** RPC methods exposed by RateLimiterDO. */
export type RateLimiterStub = DurableObjectStub & {
  check(windowMs: number, maxHits: number): Promise<{ allowed: boolean; resetIn: number }>;
};

export interface WSMessage {
  type: 'init' | 'file_added' | 'file_removed' | 'session_expiring';
  files?: FilePreview[];
  file?: FilePreview;
  fileId?: string;
}

export const MIN_TTL_MINUTES = 10;
export const MAX_TTL_MINUTES = 360; // 6 hours
export const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50 MB

export const ALLOWED_EXTENSIONS = new Set([
  '.apk', '.exe', '.py', '.zip', '.rar', '.7z',
  '.pdf', '.doc', '.docx', '.txt',
  '.jpg', '.jpeg', '.png', '.gif', '.webp',
  '.mp3', '.mp4', '.mkv',
  '.json', '.csv', '.md',
]);

export function getExtension(filename: string): string {
  const idx = filename.lastIndexOf('.');
  if (idx === -1) return '';
  return filename.slice(idx).toLowerCase();
}

export function isAllowedExtension(filename: string): boolean {
  return ALLOWED_EXTENSIONS.has(getExtension(filename));
}

export function sessionUrl(host: string, sessionId: string): string {
  // Short root-level link, e.g. https://droply.xxx/4820 — easy to type by hand.
  return `https://${host}/${sessionId}`;
}
