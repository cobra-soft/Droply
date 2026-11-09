import { R2Bucket } from '@cloudflare/workers-types';
import { getExtension } from './types';

export class R2Store {
  constructor(private bucket: R2Bucket) {}

  async putFile(key: string, body: ArrayBuffer | ArrayBufferView, originalName: string, contentType: string): Promise<void> {
    await this.bucket.put(key, body, {
      httpMetadata: { contentType },
      customMetadata: { originalName },
    });
  }

  async getFile(key: string) {
    return this.bucket.get(key);
  }

  async deleteFile(key: string): Promise<void> {
    await this.bucket.delete(key);
  }
}

export function r2Key(fileId: string, originalName: string): string {
  const ext = getExtension(originalName);
  return `file/${fileId}${ext}`;
}
