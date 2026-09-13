import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { parse } from '../utils/validate.js';
import { conflict, notFound } from '../utils/errors.js';
import { pageParams, paged, str } from '../utils/pagination.js';
import { logActivity } from '../utils/activity.js';
import { requireAdmin, requireRole, requireSuperAdmin } from '../middleware/auth.js';

// ───────── Platforms ─────────
export const platformsRouter = Router();
platformsRouter.get('/', asyncHandler(async (req, res) => {
  const all = str(req.query.all);
  const items = await prisma.platform.findMany({ where: all ? {} : { active: true }, orderBy: { sortOrder: 'asc' }, include: { _count: { select: { drivers: true, vehicles: true, trips: true, adhocRequests: true, bookings: true } } } });
  res.json({ success: true, data: items.map((p) => ({ id: p.id, name: p.name, code: p.code, color: p.color, deepLinkScheme: p.deepLinkScheme, websiteUrl: p.websiteUrl, active: p.active, sortOrder: p.sortOrder, drivers: p._count.drivers, vehicles: p._count.vehicles, trips: p._count.trips, adhocRequests: p._count.adhocRequests, bookings: p._count.bookings })) });
}));
platformsRouter.get('/usage', requireAdmin, asyncHandler(async (_req, res) => {
  const [platforms, byTrips, byBookings, byAdhoc] = await Promise.all([prisma.platform.findMany({ orderBy: { sortOrder: 'asc' } }), prisma.trip.groupBy({ by: ['platformId'], _count: { _all: true } }), prisma.booking.groupBy({ by: ['platformId'], _count: { _all: true } }), prisma.adhocRequest.groupBy({ by: ['platformId'], _count: { _all: true } })]);
  const other = platforms.find((p) => p.code === 'OTHER');
  const rows = platforms.map((p) => ({ id: p.id, name: p.name, code: p.code, color: p.color, active: p.active, trips: byTrips.find((x) => x.platformId === p.id)?._count._all ?? 0, bookings: byBookings.find((x) => x.platformId === p.id)?._count._all ?? 0, adhocRequests: byAdhoc.find((x) => x.platformId === p.id)?._count._all ?? 0 }));
  const nullTrips = byTrips.find((x) => x.platformId === null)?._count._all ?? 0; const nullBookings = byBookings.find((x) => x.platformId === null)?._count._all ?? 0; const nullAdhoc = byAdhoc.find((x) => x.platformId === null)?._count._all ?? 0;
  if (other) { const o = rows.find((r) => r.id === other.id)!; o.trips += nullTrips; o.bookings += nullBookings; o.adhocRequests += nullAdhoc; }
  res.json({ success: true, data: rows });
}));
const platformSchema = z.object({ name: z.string().min(2), code: z.string().min(2).optional(), color: z.string().optional(), deepLinkScheme: z.string().optional(), websiteUrl: z.string().optional(), active: z.boolean().optional(), sortOrder: z.number().int().optional() });
platformsRouter.post('/', requireAdmin, asyncHandler(async (req, res) => {
  const b = parse(platformSchema, req.body);
  const p = await prisma.platform.create({ data: { ...b, code: (b.code ?? b.name).toUpperCase().replace(/[^A-Z0-9]+/g, '_') } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'PLATFORM', entityId: p.id, action: 'CREATED', details: p.name });
  res.status(201).json({ success: true, data: p });
}));
platformsRouter.put('/:id', requireAdmin, asyncHandler(async (req, res) => {
  const b = parse(platformSchema.partial(), req.body);
  const p = await prisma.platform.update({ where: { id: req.params.id }, data: { ...b, code: b.code?.toUpperCase() } });
  res.json({ success: true, data: p });
}));
platformsRouter.delete('/:id', requireAdmin, asyncHandler(async (req, res) => {
  const p = await prisma.platform.update({ where: { id: req.params.id }, data: { active: false } });
  res.json({ success: true, data: p });
}));

// ───────── Clients ─────────
export const clientsRouter = Router();
clientsRouter.get('/', asyncHandler(async (req, res) => {
  const q = str(req.query.q);
  const items = await prisma.client.findMany({ where: { ...(q ? { name: { contains: q, mode: 'insensitive' } } : {}), ...(str(req.query.all) ? {} : { active: true }) }, orderBy: { name: 'asc' }, include: { _count: { select: { supervisors: true, bookings: true, adhocRequests: true, trips: true } } } });
  res.json({ success: true, data: items.map((c) => ({ id: c.id, name: c.name, code: c.code, contactName: c.contactName, contactMobile: c.contactMobile, email: c.email, address: c.address, active: c.active, supervisors: c._count.supervisors, bookings: c._count.bookings, adhocRequests: c._count.adhocRequests, trips: c._count.trips })) });
}));
const clientSchema = z.object({ name: z.string().min(1), code: z.string().optional(), contactName: z.string().optional(), contactMobile: z.string().optional(), email: z.string().email().optional(), address: z.string().optional(), active: z.boolean().optional() });
clientsRouter.post('/', requireAdmin, asyncHandler(async (req, res) => { const b = parse(clientSchema, req.body); res.status(201).json({ success: true, data: await prisma.client.create({ data: b }) }); }));
clientsRouter.put('/:id', requireAdmin, asyncHandler(async (req, res) => { const b = parse(clientSchema.partial(), req.body); res.json({ success: true, data: await prisma.client.update({ where: { id: req.params.id }, data: b }) }); }));
clientsRouter.delete('/:id', requireAdmin, asyncHandler(async (req, res) => { res.json({ success: true, data: await prisma.client.update({ where: { id: req.params.id }, data: { active: false } }) }); }));

// ───────── Locations ─────────
export const locationsRouter = Router();
locationsRouter.get('/', asyncHandler(async (req, res) => {
  const q = str(req.query.q);
  res.json({ success: true, data: await prisma.location.findMany({ where: { ...(q ? { name: { contains: q, mode: 'insensitive' } } : {}), ...(str(req.query.all) ? {} : { active: true }) }, orderBy: { name: 'asc' } }) });
}));
const locationSchema = z.object({ name: z.string().min(1), city: z.string().optional(), area: z.string().optional(), latitude: z.number().optional(), longitude: z.number().optional(), active: z.boolean().optional() });
locationsRouter.post('/', requireAdmin, asyncHandler(async (req, res) => { const b = parse(locationSchema, req.body); res.status(201).json({ success: true, data: await prisma.location.create({ data: b }) }); }));
locationsRouter.put('/:id', requireAdmin, asyncHandler(async (req, res) => { const b = parse(locationSchema.partial(), req.body); res.json({ success: true, data: await prisma.location.update({ where: { id: req.params.id }, data: b }) }); }));
locationsRouter.delete('/:id', requireAdmin, asyncHandler(async (req, res) => { res.json({ success: true, data: await prisma.location.update({ where: { id: req.params.id }, data: { active: false } }) }); }));

// ───────── Tariffs & Settings ─────────
export const settingsRouter = Router();
settingsRouter.get('/tariffs', asyncHandler(async (_req, res) => { res.json({ success: true, data: (await prisma.tariff.findMany()).map((t) => ({ ...t, baseAmount: Number(t.baseAmount), perKm: Number(t.perKm), perHour: t.perHour ? Number(t.perHour) : null })) }); }));
settingsRouter.put('/tariffs/:vehicleType', requireAdmin, asyncHandler(async (req, res) => {
  const b = parse(z.object({ baseAmount: z.coerce.number(), perKm: z.coerce.number(), perHour: z.coerce.number().optional() }), req.body);
  const t = await prisma.tariff.upsert({ where: { vehicleType: req.params.vehicleType.toUpperCase() as any }, update: b, create: { vehicleType: req.params.vehicleType.toUpperCase() as any, ...b } });
  res.json({ success: true, data: t });
}));
settingsRouter.get('/', requireAdmin, asyncHandler(async (_req, res) => { const rows = await prisma.setting.findMany(); res.json({ success: true, data: Object.fromEntries(rows.map((r) => [r.key, r.value])) }); }));
settingsRouter.get('/public', asyncHandler(async (_req, res) => { const c = await prisma.setting.findUnique({ where: { key: 'company' } }); res.json({ success: true, data: { company: c?.value ?? {} } }); }));
settingsRouter.put('/:key', requireAdmin, asyncHandler(async (req, res) => {
  const value = req.body?.value ?? req.body;
  const s = await prisma.setting.upsert({ where: { key: req.params.key }, update: { value }, create: { key: req.params.key, value } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'SETTING', entityId: s.key, action: 'UPDATED' });
  res.json({ success: true, data: s });
}));

// ───────── Admin users ─────────
export const adminUsersRouter = Router();
adminUsersRouter.use(requireAdmin);
const shapeAdmin = (a: any) => ({ id: a.id, userId: a.userId, fullName: a.user.fullName, email: a.user.email, mobile: a.user.mobile, avatarUrl: a.user.avatarUrl, status: a.user.status, adminRole: a.adminRole, designation: a.designation, lastLoginAt: a.user.lastLoginAt, createdAt: a.createdAt });
adminUsersRouter.get('/', asyncHandler(async (req, res) => {
  const p = pageParams(req, 20); const q = str(req.query.q);
  const where = q ? { user: { OR: [{ fullName: { contains: q, mode: 'insensitive' as const } }, { email: { contains: q, mode: 'insensitive' as const } }] } } : {};
  const [items, total] = await Promise.all([prisma.adminUser.findMany({ where, include: { user: true }, orderBy: { createdAt: 'asc' }, skip: p.skip, take: p.take }), prisma.adminUser.count({ where })]);
  res.json({ success: true, data: paged(items.map(shapeAdmin), total, p) });
}));
const adminSchema = z.object({ fullName: z.string().min(2), email: z.string().email(), mobile: z.string().optional(), password: z.string().min(6).optional(), adminRole: z.enum(['SUPER_ADMIN', 'ADMIN', 'OPS']).optional(), designation: z.string().optional(), status: z.enum(['ACTIVE', 'INACTIVE']).optional() });
adminUsersRouter.post('/', requireSuperAdmin, asyncHandler(async (req, res) => {
  const b = parse(adminSchema, req.body);
  if (await prisma.user.findFirst({ where: { OR: [{ email: b.email.toLowerCase() }, ...(b.mobile ? [{ mobile: b.mobile }] : [])] } })) throw conflict('Email or mobile already exists');
  const a = await prisma.adminUser.create({ data: { adminRole: b.adminRole ?? 'ADMIN', designation: b.designation ?? (b.adminRole === 'SUPER_ADMIN' ? 'Super Admin' : 'Admin'), user: { create: { role: 'ADMIN', fullName: b.fullName, email: b.email.toLowerCase(), mobile: b.mobile, passwordHash: await bcrypt.hash(b.password ?? 'Gamya@123', 10), status: b.status ?? 'ACTIVE' } } }, include: { user: true } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'ADMIN', entityId: a.id, action: 'CREATED', details: b.fullName });
  res.status(201).json({ success: true, data: shapeAdmin(a) });
}));
adminUsersRouter.put('/:id', requireSuperAdmin, asyncHandler(async (req, res) => {
  const b = parse(adminSchema.partial(), req.body);
  const a = await prisma.adminUser.update({ where: { id: req.params.id }, data: { adminRole: b.adminRole, designation: b.designation, user: { update: { fullName: b.fullName, email: b.email?.toLowerCase(), mobile: b.mobile, status: b.status, ...(b.password ? { passwordHash: await bcrypt.hash(b.password, 10) } : {}) } } }, include: { user: true } });
  res.json({ success: true, data: shapeAdmin(a) });
}));
adminUsersRouter.delete('/:id', requireSuperAdmin, asyncHandler(async (req, res) => {
  const a = await prisma.adminUser.findUnique({ where: { id: req.params.id } });
  if (!a) throw notFound('Admin not found');
  if (a.userId === req.user!.id) throw conflict('You cannot delete yourself');
  await prisma.user.delete({ where: { id: a.userId } });
  res.json({ success: true });
}));

// ───────── Activity log (global) ─────────
export const activityRouter = Router();
activityRouter.use(requireRole('ADMIN'));
activityRouter.get('/', asyncHandler(async (req, res) => {
  const p = pageParams(req, 20); const entityType = str(req.query.entityType); const entityId = str(req.query.entityId);
  const where = { ...(entityType ? { entityType: entityType.toUpperCase() } : {}), ...(entityId ? { entityId } : {}) };
  const [items, total] = await Promise.all([prisma.activityLog.findMany({ where, orderBy: { createdAt: 'desc' }, skip: p.skip, take: p.take }), prisma.activityLog.count({ where })]);
  res.json({ success: true, data: paged(items, total, p) });
}));
