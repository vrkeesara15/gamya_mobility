import type { NotificationType, Prisma } from '@prisma/client';
import { prisma } from '../config/prisma.js';
import { env } from '../config/env.js';
import { logger } from '../config/logger.js';

let messaging: import('firebase-admin/messaging').Messaging | null = null;
async function fcm() {
  if (!env.fcmEnabled) return null;
  if (messaging) return messaging;
  try {
    const admin = await import('firebase-admin');
    const app = admin.default.apps.length ? admin.default.app() : admin.default.initializeApp(
      env.firebaseServiceAccountJson ? { credential: admin.default.credential.cert(JSON.parse(env.firebaseServiceAccountJson)) } : undefined,
    );
    messaging = admin.default.messaging(app);
    return messaging;
  } catch (e) {
    logger.warn({ e }, 'FCM init failed');
    return null;
  }
}

export async function notifyUser(userId: string, p: { type?: NotificationType; title: string; body: string; data?: Prisma.InputJsonValue }) {
  const n = await prisma.notification.create({ data: { userId, type: p.type ?? 'SYSTEM', title: p.title, body: p.body, data: p.data } });
  const m = await fcm();
  if (m) {
    const u = await prisma.user.findUnique({ where: { id: userId }, select: { fcmToken: true } });
    if (u?.fcmToken) {
      m.send({ token: u.fcmToken, notification: { title: p.title, body: p.body }, data: p.data ? Object.fromEntries(Object.entries(p.data as object).map(([k, v]) => [k, String(v)])) : undefined })
        .catch((e) => logger.warn({ e }, 'FCM send failed'));
    }
  }
  return n;
}

export async function notifyMany(userIds: string[], p: { type?: NotificationType; title: string; body: string; data?: Prisma.InputJsonValue }) {
  return Promise.all([...new Set(userIds)].map((id) => notifyUser(id, p)));
}

export async function notifyAdmins(p: { type?: NotificationType; title: string; body: string; data?: Prisma.InputJsonValue }) {
  const admins = await prisma.user.findMany({ where: { role: 'ADMIN', status: 'ACTIVE' }, select: { id: true } });
  return notifyMany(admins.map((a) => a.id), p);
}
