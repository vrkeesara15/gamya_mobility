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
import { nextDriverCode } from '../utils/codes.js';
import { logActivity } from '../utils/activity.js';
import { notifyUser } from '../services/notifications.js';
import { requireAdmin } from '../middleware/auth.js';

export const driversRouter = Router();
driversRouter.use(requireAdmin);

export const REQUIRED_DRIVER_DOCS = ['RC', 'PERMIT', 'INSURANCE', 'DRIVING_LICENCE', 'VEHICLE_PHOTO_1', 'VEHICLE_PHOTO_2', 'FACE_VERIFICATION'] as const;

const include = {
  user: true, platforms: true, documents: true,
  vehicles: { include: { photos: true, platform: true, documents: true }, orderBy: { createdAt: 'desc' as const } },
  _count: { select: { trips: true } },
} satisfies Prisma.DriverInclude;

export function docSummary(docs: { type: string; status: string }[], required: readonly string[] = REQUIRED_DRIVER_DOCS) {
  const verified = required.filter((t) => docs.some((d) => d.type === t && d.status === 'VERIFIED')).length;
  const uploaded = required.filter((t) => docs.some((d) => d.type === t)).length;
  return { verified, uploaded, required: required.length, label: `${verified}/${required.length}` };
}

export function shapeDriver(d: Prisma.DriverGetPayload<{ include: typeof include }>) {
  const v = d.vehicles[0];
  // vehicle photos + vehicle docs count toward the driver's 7 documents
  const allDocs = [...d.documents, ...(v?.documents ?? [])];
  return {
    id: d.id, code: d.code, userId: d.userId, fullName: d.user.fullName, email: d.user.email, mobile: d.user.mobile, avatarUrl: d.user.avatarUrl ?? d.selfieUrl,
    status: d.user.status, dateOfBirth: d.dateOfBirth, address: d.address, city: d.city, licenceNumber: d.licenceNumber, joiningDate: d.joiningDate ?? d.createdAt,
    faceVerified: d.faceVerified, faceMatchScore: d.faceMatchScore, selfieUrl: d.selfieUrl, idPhotoUrl: d.idPhotoUrl, reVerificationDue: d.reVerificationDue, blacklistReason: d.blacklistReason,
    approvedAt: d.approvedAt, rating: d.rating, lastActiveAt: d.user.lastLoginAt,
    platforms: d.platforms.map((p) => ({ id: p.id, name: p.name, code: p.code, color: p.color })), platformNames: d.platforms.map((p) => p.name).join(', ') || 'Other',
    vehicle: v ? { id: v.id, number: v.number, make: v.make, model: v.model, year: v.year, type: v.type, status: v.status, color: v.color, photos: v.photos.map((p) => p.url), platform: v.platform?.name } : null,
    vehicles: d.vehicles.map((x) => ({ id: x.id, number: x.number, make: x.make, model: x.model, year: x.year, type: x.type, status: x.status })),
    documents: allDocs.map((x) => ({ id: x.id, type: x.type, status: x.status, fileUrl: x.fileUrl, validTill: x.validTill, verifiedAt: x.verifiedAt, remarks: x.remarks, vehicleId: x.vehicleId })),
    docs: docSummary(allDocs), totalTrips: d._count.trips, createdAt: d.createdAt,
  };
}

driversRouter.get('/stats', asyncHandler(async (_req, res) => {
  const monthAgo = dayjs().subtract(30, 'day').toDate(); const weekAgo = dayjs().subtract(7, 'day').toDate(); const in30 = dayjs().add(30, 'day').toDate();
  const [total, active, pending, inactive, blacklisted, reverif, newMonth, activeMonth, pendingWeek, inactiveWeek] = await Promise.all([
    prisma.driver.count(), prisma.driver.count({ where: { user: { status: 'ACTIVE' } } }), prisma.driver.count({ where: { user: { status: 'PENDING' } } }),
    prisma.driver.count({ where: { user: { status: 'INACTIVE' } } }), prisma.driver.count({ where: { user: { status: 'BLACKLISTED' } } }),
    prisma.driver.count({ where: { reVerificationDue: { lte: in30 } } }),
    prisma.driver.count({ where: { createdAt: { gte: monthAgo } } }), prisma.driver.count({ where: { approvedAt: { gte: monthAgo } } }),
    prisma.driver.count({ where: { user: { status: 'PENDING' }, createdAt: { gte: weekAgo } } }), prisma.driver.count({ where: { user: { status: 'INACTIVE' }, updatedAt: { gte: weekAgo } } }),
  ]);
  res.json({ success: true, data: { total, active, pending, inactive, blacklisted, reVerificationDue: reverif, newThisMonth: newMonth, activeThisMonth: activeMonth, pendingThisWeek: pendingWeek, inactiveThisWeek: inactiveWeek } });
}));

driversRouter.get('/', asyncHandler(async (req, res) => {
  const p = pageParams(req);
  const q = str(req.query.q); const status = str(req.query.status); const vehicleType = str(req.query.vehicleType); const platform = str(req.query.platform); const location = str(req.query.location);
  const where: Prisma.DriverWhereInput = {
    ...(q ? { OR: [{ user: { fullName: { contains: q, mode: 'insensitive' } } }, { user: { mobile: { contains: q } } }, { code: { contains: q, mode: 'insensitive' } }, { vehicles: { some: { number: { contains: q, mode: 'insensitive' } } } }] } : {}),
    ...(status ? { user: { status: status.toUpperCase() as any } } : {}),
    ...(vehicleType ? { vehicles: { some: { type: vehicleType.toUpperCase() as any } } } : {}),
    ...(platform ? { platforms: { some: { OR: [{ id: platform }, { code: platform.toUpperCase() }, { name: { equals: platform, mode: 'insensitive' } }] } } } : {}),
    ...(location ? { OR: [{ city: { contains: location, mode: 'insensitive' } }, { address: { contains: location, mode: 'insensitive' } }] } : {}),
  };
  const [items, total] = await Promise.all([
    prisma.driver.findMany({ where, include, orderBy: { code: 'asc' }, skip: p.skip, take: p.take }),
    prisma.driver.count({ where }),
  ]);
  res.json({ success: true, data: paged(items.map(shapeDriver), total, p) });
}));

driversRouter.get('/performance', asyncHandler(async (_req, res) => {
  const since = dayjs().subtract(30, 'day').toDate();
  const [trips, completed, delayed, earnings, byPlatform] = await Promise.all([
    prisma.trip.count({ where: { createdAt: { gte: since } } }),
    prisma.trip.count({ where: { status: 'COMPLETED', completedAt: { gte: since } } }),
    prisma.trip.count({ where: { createdAt: { gte: since }, OR: [{ status: 'DELAYED' }, { onTime: false }] } }),
    prisma.earning.aggregate({ _sum: { amount: true }, where: { date: { gte: since } } }),
    prisma.trip.groupBy({ by: ['platformId'], _count: { _all: true }, where: { createdAt: { gte: since } } }),
  ]);
  const platforms = await prisma.platform.findMany();
  const onTime = Math.max(0, completed - delayed);
  res.json({ success: true, data: {
    totalTrips: trips, completed, onTime, onTimePct: completed ? Math.round((onTime / completed) * 100) : 0, delayed, delayedPct: completed ? Math.round((delayed / completed) * 100) : 0,
    earnings: Number(earnings._sum.amount ?? 0),
    platformWise: byPlatform.map((g) => { const pl = platforms.find((x) => x.id === g.platformId); return { platformId: g.platformId, name: pl?.name ?? 'Other', color: pl?.color ?? '#9CA3AF', count: g._count._all }; }),
  } });
}));

driversRouter.get('/activities', asyncHandler(async (req, res) => {
  const p = pageParams(req, 10);
  const where: Prisma.ActivityLogWhereInput = { OR: [{ entityType: 'DRIVER' }, { actor: { role: 'DRIVER' } }] };
  const [items, total] = await Promise.all([prisma.activityLog.findMany({ where, orderBy: { createdAt: 'desc' }, skip: p.skip, take: p.take }), prisma.activityLog.count({ where })]);
  res.json({ success: true, data: paged(items, total, p) });
}));

const createSchema = z.object({
  fullName: z.string().min(2), email: z.string().email().optional(), mobile: z.string().min(10), password: z.string().min(6).optional(),
  dateOfBirth: z.string().optional(), address: z.string().optional(), city: z.string().optional(), licenceNumber: z.string().optional(), joiningDate: z.string().optional(),
  platformIds: z.array(z.string()).optional(), status: z.enum(['ACTIVE', 'INACTIVE', 'PENDING']).optional(),
  vehicle: z.object({ number: z.string().min(4), make: z.string(), model: z.string(), year: z.number().int(), type: z.enum(['SEDAN', 'SUV', 'INNOVA', 'TEMPO_TRAVELLER', 'TEMPO', 'OTHER']), color: z.string().optional() }).optional(),
});

driversRouter.post('/', asyncHandler(async (req, res) => {
  const b = parse(createSchema, req.body);
  if (await prisma.user.findFirst({ where: { OR: [{ mobile: b.mobile }, ...(b.email ? [{ email: b.email.toLowerCase() }] : [])] } })) throw conflict('Email or mobile already exists');
  const d = await prisma.driver.create({
    data: {
      code: await nextDriverCode(), dateOfBirth: b.dateOfBirth ? new Date(b.dateOfBirth) : undefined, address: b.address, city: b.city, licenceNumber: b.licenceNumber,
      joiningDate: b.joiningDate ? new Date(b.joiningDate) : new Date(), approvedAt: b.status === 'PENDING' ? undefined : new Date(), approvedById: req.user!.adminId,
      reVerificationDue: dayjs().add(12, 'month').toDate(),
      user: { create: { role: 'DRIVER', fullName: b.fullName, email: b.email?.toLowerCase(), mobile: b.mobile, passwordHash: await bcrypt.hash(b.password ?? 'Gamya@123', 10), status: b.status ?? 'ACTIVE' } },
      platforms: b.platformIds?.length ? { connect: b.platformIds.map((id) => ({ id })) } : undefined,
      vehicles: b.vehicle ? { create: { ...b.vehicle, number: b.vehicle.number.toUpperCase(), status: 'ACTIVE', platformId: b.platformIds?.[0] } } : undefined,
    },
    include,
  });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'DRIVER', entityId: d.id, action: 'CREATED', details: `Added driver ${b.fullName}` });
  res.status(201).json({ success: true, data: shapeDriver(d) });
}));

driversRouter.get('/:id', asyncHandler(async (req, res) => {
  const d = await prisma.driver.findFirst({ where: { OR: [{ id: req.params.id }, { code: req.params.id }] }, include });
  if (!d) throw notFound('Driver not found');
  const since = dayjs().subtract(30, 'day').toDate();
  const [trips, earnings, activities, tripsCount, onTimeCount, delayedCount, earningsSum] = await Promise.all([
    prisma.trip.findMany({ where: { driverId: d.id }, orderBy: { scheduledStart: 'desc' }, take: 20, include: { platform: true, vehicle: true, client: true } }),
    prisma.earning.findMany({ where: { driverId: d.id }, orderBy: { date: 'desc' }, take: 20, include: { trip: { include: { platform: true } } } }),
    prisma.activityLog.findMany({ where: { OR: [{ entityType: 'DRIVER', entityId: d.id }, { actorId: d.userId }] }, orderBy: { createdAt: 'desc' }, take: 20 }),
    prisma.trip.count({ where: { driverId: d.id, createdAt: { gte: since } } }),
    prisma.trip.count({ where: { driverId: d.id, status: 'COMPLETED', onTime: true, createdAt: { gte: since } } }),
    prisma.trip.count({ where: { driverId: d.id, createdAt: { gte: since }, OR: [{ status: 'DELAYED' }, { onTime: false }] } }),
    prisma.earning.aggregate({ _sum: { amount: true }, where: { driverId: d.id, date: { gte: since } } }),
  ]);
  res.json({ success: true, data: { ...shapeDriver(d), trips, earnings, activities, performance: { totalTrips: tripsCount, onTime: onTimeCount, delayed: delayedCount, earnings: Number(earningsSum._sum.amount ?? 0) } } });
}));

driversRouter.put('/:id', asyncHandler(async (req, res) => {
  const b = parse(createSchema.partial(), req.body);
  const d = await prisma.driver.findUnique({ where: { id: req.params.id } });
  if (!d) throw notFound('Driver not found');
  const updated = await prisma.driver.update({
    where: { id: d.id },
    data: {
      dateOfBirth: b.dateOfBirth ? new Date(b.dateOfBirth) : undefined, address: b.address, city: b.city, licenceNumber: b.licenceNumber, joiningDate: b.joiningDate ? new Date(b.joiningDate) : undefined,
      user: { update: { fullName: b.fullName, email: b.email?.toLowerCase(), mobile: b.mobile, status: b.status, ...(b.password ? { passwordHash: await bcrypt.hash(b.password, 10) } : {}) } },
      platforms: b.platformIds ? { set: b.platformIds.map((id) => ({ id })) } : undefined,
    },
    include,
  });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'DRIVER', entityId: d.id, action: 'UPDATED', details: 'Profile updated' });
  res.json({ success: true, data: shapeDriver(updated) });
}));

driversRouter.patch('/:id/status', asyncHandler(async (req, res) => {
  const b = parse(z.object({ status: z.enum(['ACTIVE', 'INACTIVE', 'BLACKLISTED']), reason: z.string().optional() }), req.body);
  const d = await prisma.driver.update({ where: { id: req.params.id }, data: { blacklistReason: b.status === 'BLACKLISTED' ? b.reason ?? 'Blacklisted by admin' : null, user: { update: { status: b.status } } }, include });
  if (b.status !== 'ACTIVE') await prisma.vehicle.updateMany({ where: { driverId: d.id }, data: { status: b.status === 'BLACKLISTED' ? 'BLACKLISTED' : 'INACTIVE' } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'DRIVER', entityId: d.id, action: 'STATUS_CHANGED', details: `Status set to ${b.status}${b.reason ? ` – ${b.reason}` : ''}` });
  await notifyUser(d.userId, { type: 'ACCOUNT', title: 'Account update', body: b.status === 'ACTIVE' ? 'Your account is active again.' : `Your account has been marked ${b.status.toLowerCase()}.${b.reason ? ` Reason: ${b.reason}` : ''}` });
  res.json({ success: true, data: shapeDriver(d) });
}));

driversRouter.post('/:id/notify', asyncHandler(async (req, res) => {
  const b = parse(z.object({ title: z.string().min(1), body: z.string().min(1) }), req.body);
  const d = await prisma.driver.findUnique({ where: { id: req.params.id } });
  if (!d) throw notFound('Driver not found');
  await notifyUser(d.userId, { type: 'SYSTEM', title: b.title, body: b.body });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'DRIVER', entityId: d.id, action: 'NOTIFIED', details: b.title });
  res.json({ success: true });
}));

driversRouter.patch('/:id/documents/:docId', asyncHandler(async (req, res) => {
  const b = parse(z.object({ status: z.enum(['PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED']), remarks: z.string().optional(), validTill: z.string().optional() }), req.body);
  const doc = await prisma.document.update({ where: { id: req.params.docId }, data: { status: b.status, remarks: b.remarks, validTill: b.validTill ? new Date(b.validTill) : undefined, verifiedAt: b.status === 'VERIFIED' ? new Date() : null, verifiedById: b.status === 'VERIFIED' ? req.user!.adminId : null } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'DRIVER', entityId: req.params.id, action: 'DOCUMENT_' + b.status, details: `${doc.type} marked ${b.status}` });
  res.json({ success: true, data: doc });
}));

driversRouter.delete('/:id', asyncHandler(async (req, res) => {
  const d = await prisma.driver.findUnique({ where: { id: req.params.id } });
  if (!d) throw notFound('Driver not found');
  await prisma.user.delete({ where: { id: d.userId } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'DRIVER', entityId: d.id, action: 'DELETED' });
  res.json({ success: true });
}));
