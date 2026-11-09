// Cloudflare runtime types.
//
// Official declarations for the Worker runtime (Request, Response, WebSocket,
// DurableObject, DurableObjectState, DurableObjectStorage, R2Bucket, D1Database,
// the "cloudflare:workers" module, etc.) are supplied by the
// `@cloudflare/workers-types` package and wired in through tsconfig `types`.
//
// This file is intentionally a module with no re-declarations. A hand-written
// stub for the "cloudflare:workers" module used to shadow the real types and
// produced conflicting duplicate globals (WebSocket, Headers, DurableObject*),
// which broke `tsc --noEmit`. Keep it empty on purpose.
export {};
