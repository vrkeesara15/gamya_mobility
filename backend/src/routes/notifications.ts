import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { parse } from '../utils/validate.js';
import { pageParams, paged, str } from '../utils/pagination.js';
import { notifyMany } from '../services/notifications.js';
import { logActivity } from '../utils/activity.js';
import { requireAdmin } from '../middleware/auth.js';

export const notificationsRouter = Router();

notificationsRouter.get('/', asyncHandler(async (req, res) => {
  const p = pageParams(req, 20); const type = str(req.query.type); const unread = str(req.query.unread);
  const where = { userId: req.user!.id, ...(type ? { type: type.toUpperCase() as any } : {}), ...(unread ? { read: false } : {}) };
  const [items, total, unreadCount] = await Promise.all([prisma.notification.findMany({ where, orderBy: { createdAt: 'desc' }, skip: p.skip, take: p.take }), prisma.notification.count({ where }), prisma.notification.count({ where: { userId: req.user!.id, read: false } })]);
  res.json({ success: true, data: { ...paged(items, total, p), unreadCount } });
}));
notificationsRouter.get('/unread-count', asyncHandler(async (req, res) => { res.json({ success: true, data: { count: await prisma.notification.count({ where: { userId: req.user!.id, read: false } }) } }); }));
notificationsRouter.post('/read-all', asyncHandler(async (req, res) => { await prisma.notification.updateMany({ where: { userId: req.user!.id, read: false }, data: { read: true } }); res.json({ success: true }); }));
notificationsRouter.patch('/:id/read', asyncHandler(async (req, res) => { await prisma.notification.updateMany({ where: { id: req.params.id, userId: req.user!.id }, data: { read: true } }); res.json({ success: true }); }));
notificationsRouter.delete('/:id', asyncHandler(async (req, res) => { await prisma.notification.deleteMany({ where: { id: req.params.id, userId: req.user!.id } }); res.json({ success: true }); }));

/** Admin broadcast: to all drivers / supervisors / specific users. */
notificationsRouter.post('/send', requireAdmin, asyncHandler(async (req, res) => {
  const b = parse(z.object({ title: z.string().min(1), body: z.string().min(1), audience: z.enum(['DRIVERS', 'SUPERVISORS', 'ADMINS', 'ALL', 'USERS']).default('USERS'), userIds: z.array(z.string()).optional(), type: z.enum(['TRIP_REQUEST', 'TRIP_UPDATE', 'ACCOUNT', 'APPROVAL', 'PAYMENT', 'SYSTEM']).optional() }), req.body);
  let ids = b.userIds ?? [];
  if (b.audience !== 'USERS') {
    const roles = b.audience === 'ALL' ? ['DRIVER', 'SUPERVISOR', 'ADMIN'] : [b.audience.slice(0, -1)];
    ids = (await prisma.user.findMany({ where: { role: { in: roles as any }, status: 'ACTIVE' }, select: { id: true } })).map((u) => u.id);
  }
  await notifyMany(ids, { type: b.type ?? 'SYSTEM', title: b.title, body: b.body });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'NOTIFICATION', action: 'SENT', details: `${b.title} → ${b.audience} (${ids.length})` });
  res.json({ success: true, data: { recipients: ids.length } });
}));

/** Admin: outbox / recently sent (all notifications, newest first). */
notificationsRouter.get('/all', requireAdmin, asyncHandler(async (req, res) => {
  const p = pageParams(req, 20);
  const [items, total] = await Promise.all([prisma.notification.findMany({ include: { user: { select: { fullName: true, role: true } } }, orderBy: { createdAt: 'desc' }, skip: p.skip, take: p.take }), prisma.notification.count()]);
  res.json({ success: true, data: paged(items.map((n) => ({ ...n, recipient: n.user.fullName, recipientRole: n.user.role })), total, p) });
}));
