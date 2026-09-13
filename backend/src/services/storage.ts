import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import multer from 'multer';
import { env } from '../config/env.js';

export interface StoredFile { url: string; key: string; fileName: string; mimeType: string; size: number }

export const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const ok = /^(image\/(jpeg|png|webp|heic)|application\/pdf)$/i.test(file.mimetype);
    if (ok) cb(null, true); else cb(new Error('Only JPEG/PNG/WEBP images or PDF files are allowed'));
  },
});

function keyFor(folder: string, originalName: string) {
  const ext = path.extname(originalName).toLowerCase() || '.bin';
  return `${folder}/${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`;
}

async function saveLocal(folder: string, file: Express.Multer.File): Promise<StoredFile> {
  const key = keyFor(folder, file.originalname);
  const abs = path.join(process.cwd(), env.localUploadDir, key);
  await fs.mkdir(path.dirname(abs), { recursive: true });
  await fs.writeFile(abs, file.buffer);
  return { url: `${env.publicBaseUrl}/uploads/${key}`, key, fileName: file.originalname, mimeType: file.mimetype, size: file.size };
}

let gcsBucket: import('@google-cloud/storage').Bucket | null = null;
async function bucket() {
  if (!gcsBucket) {
    const { Storage } = await import('@google-cloud/storage');
    const storage = new Storage(env.gcsProjectId ? { projectId: env.gcsProjectId } : undefined);
    gcsBucket = storage.bucket(env.gcsBucket);
  }
  return gcsBucket;
}

async function saveGcs(folder: string, file: Express.Multer.File): Promise<StoredFile> {
  const key = keyFor(folder, file.originalname);
  const b = await bucket();
  await b.file(key).save(file.buffer, { contentType: file.mimetype, resumable: false, metadata: { cacheControl: 'public, max-age=31536000' } });
  return { url: `https://storage.googleapis.com/${env.gcsBucket}/${key}`, key, fileName: file.originalname, mimeType: file.mimetype, size: file.size };
}

export async function storeFile(folder: string, file: Express.Multer.File): Promise<StoredFile> {
  if (env.storageDriver === 'gcs' && env.gcsBucket) return saveGcs(folder, file);
  return saveLocal(folder, file);
}

export async function deleteFile(key: string) {
  try {
    if (env.storageDriver === 'gcs' && env.gcsBucket) await (await bucket()).file(key).delete({ ignoreNotFound: true });
    else await fs.unlink(path.join(process.cwd(), env.localUploadDir, key));
  } catch { /* ignore */ }
}
