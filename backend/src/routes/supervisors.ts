import { Router } from 'express';
import bcrypt from 'bcryptjs';
import dayjs from 'dayjs';
import { z } from 'zod';
import type { Prisma } from '@prisma/client';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { parse } from '../utils/validate.js';
import { conflict, notFound } from '../utils/errors.js';
import { pageParams, paged, str } from '../utils/pagination.js';
import { nextSupervisorCode } from '../utils/codes.js';
import { logActivity } from '../utils/activity.js';
import { notifyUser } from '../services/notifications.js';
import { requireAdmin } from '../middleware/auth.js';

export const supervisorsRouter = Router();
supervisorsRouter.use(requireAdmin);

const include = { user: true, client: true, locations: true, _count: { select: { adhocRequests: true, bookings: true } } } satisfies Prisma.SupervisorInclude;

export function shapeSupervisor(s: Prisma.SupervisorGetPayload<{ include: typeof include }>) {
  return {
    id: s.id, code: s.code, userId: s.userId, fullName: s.user.fullName, email: s.user.email, mobile: s.user.mobile, avatarUrl: s.user.avatarUrl,
    status: s.user.status, employeeId: s.employeeId, companyName: s.companyName, clientId: s.clientId, clientName: s.client?.name ?? s.companyName,
    designation: s.designation, dateOfJoining: s.dateOfJoining, lastLoginAt: s.user.lastLoginAt, faceVerified: s.faceVerified, faceMatchScore: s.faceMatchScore, selfieUrl: s.selfieUrl,
    approvedAt: s.approvedAt, locations: s.locations.map((l) => ({ id: l.id, name: l.name })), assignedLocations: s.locations.map((l) => l.name).join(', ') || 'All Locations',
    totalRequests: s._count.adhocRequests, totalBookings: s._count.bookings, createdAt: s.createdAt,
  };
}

supervisorsRouter.get('/stats', asyncHandler(async (_req, res) => {
  const weekAgo = dayjs().subtract(7, 'day').toDate();
  const [total, active, inactive, pending, requests, bookings, newThisWeek, requestsWeek, bookingsWeek] = await Promise.all([
    prisma.supervisor.count(), prisma.supervisor.count({ where: { user: { status: 'ACTIVE' } } }), prisma.supervisor.count({ where: { user: { status: 'INACTIVE' } } }),
    prisma.supervisor.count({ where: { user: { status: 'PENDING' } } }), prisma.adhocRequest.count(), prisma.booking.count(),
    prisma.supervisor.count({ where: { createdAt: { gte: weekAgo } } }), prisma.adhocRequest.count({ where: { createdAt: { gte: weekAgo } } }), prisma.booking.count({ where: { createdAt: { gte: weekAgo } } }),
  ]);
  res.json({ success: true, data: { total, active, inactive, pending, totalRequests: requests, totalBookings: bookings, newThisWeek, requestsThisWeek: requestsWeek, bookingsThisWeek: bookingsWeek } });
}));

supervisorsRouter.get('/', asyncHandler(async (req, res) => {
  const p = pageParams(req);
  const q = str(req.query.q); const status = str(req.query.status); const location = str(req.query.location); const clientId = str(req.query.clientId);
  const where: Prisma.SupervisorWhereInput = {
    ...(q ? { OR: [{ user: { fullName: { contains: q, mode: 'insensitive' } } }, { user: { email: { contains: q, mode: 'insensitive' } } }, { user: { mobile: { contains: q } } }, { code: { contains: q, mode: 'insensitive' } }, { companyName: { contains: q, mode: 'insensitive' } }] } : {}),
    ...(status ? { user: { status: status.toUpperCase() as any } } : {}),
    ...(location ? { locations: { some: { OR: [{ id: location }, { name: { contains: location, mode: 'insensitive' } }] } } } : {}),
    ...(clientId ? { clientId } : {}),
  };
  const [items, total] = await Promise.all([
    prisma.supervisor.findMany({ where, include, orderBy: { code: 'asc' }, skip: p.skip, take: p.take }),
    prisma.supervisor.count({ where }),
  ]);
  res.json({ success: true, data: paged(items.map(shapeSupervisor), total, p) });
}));

supervisorsRouter.get('/activities', asyncHandler(async (req, res) => {
  const p = pageParams(req, 10);
  const [items, total] = await Promise.all([
    prisma.activityLog.findMany({ where: { OR: [{ entityType: 'SUPERVISOR' }, { actor: { role: 'SUPERVISOR' } }] }, orderBy: { createdAt: 'desc' }, skip: p.skip, take: p.take }),
    prisma.activityLog.count({ where: { OR: [{ entityType: 'SUPERVISOR' }, { actor: { role: 'SUPERVISOR' } }] } }),
  ]);
  res.json({ success: true, data: paged(items, total, p) });
}));

const createSchema = z.object({
  fullName: z.string().min(2), email: z.string().email(), mobile: z.string().min(10), password: z.string().min(6).optional(),
  employeeId: z.string().optional(), companyName: z.string().min(1), clientId: z.string().optional(), designation: z.string().optional(),
  dateOfJoining: z.string().optional(), locationIds: z.array(z.string()).optional(), status: z.enum(['ACTIVE', 'INACTIVE', 'PENDING']).optional(),
});

supervisorsRouter.post('/', asyncHandler(async (req, res) => {
  const b = parse(createSchema, req.body);
  const email = b.email.toLowerCase();
  if (await prisma.user.findFirst({ where: { OR: [{ email }, { mobile: b.mobile }] } })) throw conflict('Email or mobile already exists');
  const client = b.clientId ? await prisma.client.findUnique({ where: { id: b.clientId } }) : await prisma.client.upsert({ where: { name: b.companyName }, update: {}, create: { name: b.companyName } });
  const password = b.password ?? 'Gamya@123';
  const s = await prisma.supervisor.create({
    data: {
      code: await nextSupervisorCode(), employeeId: b.employeeId, companyName: client?.name ?? b.companyName, client: client ? { connect: { id: client.id } } : undefined, designation: b.designation,
      dateOfJoining: b.dateOfJoining ? new Date(b.dateOfJoining) : new Date(), approvedAt: new Date(), approvedById: req.user!.adminId,
      user: { create: { role: 'SUPERVISOR', fullName: b.fullName, email, mobile: b.mobile, passwordHash: await bcrypt.hash(password, 10), status: b.status ?? 'ACTIVE' } },
      locations: b.locationIds?.length ? { connect: b.locationIds.map((id) => ({ id })) } : undefined,
    },
    include,
  });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'SUPERVISOR', entityId: s.id, action: 'CREATED', details: `Added supervisor ${b.fullName}` });
  res.status(201).json({ success: true, data: shapeSupervisor(s) });
}));

supervisorsRouter.get('/:id', asyncHandler(async (req, res) => {
  const s = await prisma.supervisor.findFirst({ where: { OR: [{ id: req.params.id }, { code: req.params.id }] }, include });
  if (!s) throw notFound('Supervisor not found');
  const [activities, recentRequests] = await Promise.all([
    prisma.activityLog.findMany({ where: { OR: [{ entityType: 'SUPERVISOR', entityId: s.id }, { actorId: s.userId }] }, orderBy: { createdAt: 'desc' }, take: 20 }),
    prisma.adhocRequest.findMany({ where: { supervisorId: s.id }, orderBy: { createdAt: 'desc' }, take: 10, include: { platform: true, assignedVehicle: true } }),
  ]);
  res.json({ success: true, data: { ...shapeSupervisor(s), activities, recentRequests } });
}));

supervisorsRouter.put('/:id', asyncHandler(async (req, res) => {
  const b = parse(createSchema.partial(), req.body);
  const s = await prisma.supervisor.findUnique({ where: { id: req.params.id } });
  if (!s) throw notFound('Supervisor not found');
  const updated = await prisma.supervisor.update({
    where: { id: s.id },
    data: {
      employeeId: b.employeeId, companyName: b.companyName, client: b.clientId ? { connect: { id: b.clientId } } : undefined, designation: b.designation, dateOfJoining: b.dateOfJoining ? new Date(b.dateOfJoining) : undefined,
      user: { update: { fullName: b.fullName, email: b.email?.toLowerCase(), mobile: b.mobile, status: b.status, ...(b.password ? { passwordHash: await bcrypt.hash(b.password, 10) } : {}) } },
      locations: b.locationIds ? { set: b.locationIds.map((id) => ({ id })) } : undefined,
    },
    include,
  });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'SUPERVISOR', entityId: s.id, action: 'UPDATED', details: 'Supervisor details updated' });
  res.json({ success: true, data: shapeSupervisor(updated) });
}));

supervisorsRouter.patch('/:id/status', asyncHandler(async (req, res) => {
  const b = parse(z.object({ status: z.enum(['ACTIVE', 'INACTIVE', 'BLACKLISTED']) }), req.body);
  const s = await prisma.supervisor.update({ where: { id: req.params.id }, data: { user: { update: { status: b.status } } }, include });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'SUPERVISOR', entityId: s.id, action: 'STATUS_CHANGED', details: `Status set to ${b.status}` });
  await notifyUser(s.userId, { type: 'ACCOUNT', title: 'Account update', body: `Your account status is now ${b.status.toLowerCase()}.` });
  res.json({ success: true, data: shapeSupervisor(s) });
}));

supervisorsRouter.post('/:id/reset-password', asyncHandler(async (req, res) => {
  const b = parse(z.object({ newPassword: z.string().min(6).optional() }), req.body ?? {});
  const s = await prisma.supervisor.findUnique({ where: { id: req.params.id } });
  if (!s) throw notFound('Supervisor not found');
  const pwd = b.newPassword ?? `Gamya@${Math.floor(1000 + Math.random() * 9000)}`;
  await prisma.user.update({ where: { id: s.userId }, data: { passwordHash: await bcrypt.hash(pwd, 10) } });
  await notifyUser(s.userId, { type: 'ACCOUNT', title: 'Password reset', body: 'Your password was reset by the admin.' });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'SUPERVISOR', entityId: s.id, action: 'PASSWORD_RESET', details: 'Password reset by admin' });
  res.json({ success: true, data: { temporaryPassword: pwd } });
}));

supervisorsRouter.put('/:id/locations', asyncHandler(async (req, res) => {
  const b = parse(z.object({ locationIds: z.array(z.string()) }), req.body);
  const s = await prisma.supervisor.update({ where: { id: req.params.id }, data: { locations: { set: b.locationIds.map((id) => ({ id })) } }, include });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'SUPERVISOR', entityId: s.id, action: 'LOCATIONS_ASSIGNED', details: s.locations.map((l) => l.name).join(', ') });
  res.json({ success: true, data: shapeSupervisor(s) });
}));

supervisorsRouter.post('/:id/notify', asyncHandler(async (req, res) => {
  const b = parse(z.object({ title: z.string().min(1), body: z.string().min(1) }), req.body);
  const s = await prisma.supervisor.findUnique({ where: { id: req.params.id } });
  if (!s) throw notFound('Supervisor not found');
  await notifyUser(s.userId, { type: 'SYSTEM', title: b.title, body: b.body });
  res.json({ success: true });
}));

supervisorsRouter.delete('/:id', asyncHandler(async (req, res) => {
  const s = await prisma.supervisor.findUnique({ where: { id: req.params.id } });
  if (!s) throw notFound('Supervisor not found');
  await prisma.user.delete({ where: { id: s.userId } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'SUPERVISOR', entityId: s.id, action: 'DELETED' });
  res.json({ success: true });
}));
