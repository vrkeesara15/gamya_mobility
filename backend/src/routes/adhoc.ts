import { Router } from 'express';
import dayjs from 'dayjs';
import { z } from 'zod';
import type { Prisma } from '@prisma/client';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { parse } from '../utils/validate.js';
import { badRequest, forbidden, notFound } from '../utils/errors.js';
import { pageParams, paged, str } from '../utils/pagination.js';
import { nextAdhocCode, nextTripCode } from '../utils/codes.js';
import { logActivity } from '../utils/activity.js';
import { notifyAdmins, notifyMany, notifyUser } from '../services/notifications.js';
import { requireRole } from '../middleware/auth.js';

export const adhocRouter = Router();
adhocRouter.use(requireRole('ADMIN', 'SUPERVISOR'));

const VEHICLE_TYPES = ['SEDAN', 'SUV', 'INNOVA', 'TEMPO_TRAVELLER', 'TEMPO', 'OTHER'] as const;
const include = {
  client: true, supervisor: { include: { user: true } }, platform: true,
  assignedVehicle: { include: { photos: true } }, assignedDriver: { include: { user: true } },
  trips: { include: { events: { orderBy: { at: 'asc' as const } } }, orderBy: { createdAt: 'desc' as const } },
} satisfies Prisma.AdhocRequestInclude;

export function shapeAdhoc(a: Prisma.AdhocRequestGetPayload<{ include: typeof include }>) {
  const trip = a.trips[0];
  return {
    id: a.id, code: a.code, status: a.status, clientId: a.clientId, clientName: a.client?.name ?? a.supervisor?.companyName ?? null,
    supervisor: a.supervisor ? { id: a.supervisor.id, code: a.supervisor.code, fullName: a.supervisor.user.fullName, mobile: a.supervisor.user.mobile } : null,
    contactName: a.contactName ?? a.supervisor?.user.fullName ?? null, contactMobile: a.contactMobile ?? a.supervisor?.user.mobile ?? null,
    fromLocation: a.fromLocation, toLocation: a.toLocation, fromLatitude: a.fromLatitude, fromLongitude: a.fromLongitude, toLatitude: a.toLatitude, toLongitude: a.toLongitude,
    scheduledAt: a.scheduledAt, loginTime: a.loginTime, reportingTime: a.reportingTime, passengers: a.passengers, vehicleType: a.vehicleType, modelYearMin: a.modelYearMin, numberOfVehicles: a.numberOfVehicles,
    bookingType: a.bookingType, platform: a.platform ? { id: a.platform.id, name: a.platform.name, code: a.platform.code, color: a.platform.color, deepLinkScheme: a.platform.deepLinkScheme } : null, otherPlatformName: a.otherPlatformName,
    specialInstructions: a.specialInstructions, estimatedAmount: a.estimatedAmount ? Number(a.estimatedAmount) : null,
    assignedVehicle: a.assignedVehicle ? { id: a.assignedVehicle.id, number: a.assignedVehicle.number, make: a.assignedVehicle.make, model: a.assignedVehicle.model, type: a.assignedVehicle.type, photoUrl: a.assignedVehicle.photos[0]?.url ?? null } : null,
    assignedDriver: a.assignedDriver ? { id: a.assignedDriver.id, code: a.assignedDriver.code, fullName: a.assignedDriver.user.fullName, mobile: a.assignedDriver.user.mobile, avatarUrl: a.assignedDriver.user.avatarUrl } : null,
    assignedAt: a.assignedAt, cancelReason: a.cancelReason, createdAt: a.createdAt, updatedAt: a.updatedAt,
    trip: trip ? { id: trip.id, code: trip.code, status: trip.status, startedAt: trip.startedAt, completedAt: trip.completedAt, externalTripId: trip.externalTripId, events: trip.events } : null,
  };
}

export async function estimateAmount(vehicleType: (typeof VEHICLE_TYPES)[number], numberOfVehicles = 1, passengers = 1) {
  const t = await prisma.tariff.findUnique({ where: { vehicleType } });
  const base = t ? Number(t.baseAmount) : 1200;
  return Math.round(base * numberOfVehicles);
}

function supervisorScope(req: import('express').Request): Prisma.AdhocRequestWhereInput {
  return req.user!.role === 'SUPERVISOR' ? { supervisorId: req.user!.supervisorId } : {};
}

adhocRouter.get('/stats', asyncHandler(async (req, res) => {
  const scope = supervisorScope(req); const monthStart = dayjs().startOf('month').toDate(); const today = dayjs().startOf('day').toDate(); const yesterday = dayjs().subtract(1, 'day').startOf('day').toDate(); const lastMonthStart = dayjs().subtract(1, 'month').startOf('month').toDate();
  const [total, assigned, pending, cancelled, completed, todays, yesterdays, revenue, lastMonthRevenue, newMonth] = await Promise.all([
    prisma.adhocRequest.count({ where: scope }), prisma.adhocRequest.count({ where: { ...scope, status: { in: ['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS'] } } }), prisma.adhocRequest.count({ where: { ...scope, status: 'PENDING' } }),
    prisma.adhocRequest.count({ where: { ...scope, status: 'CANCELLED' } }), prisma.adhocRequest.count({ where: { ...scope, status: 'COMPLETED' } }),
    prisma.adhocRequest.count({ where: { ...scope, scheduledAt: { gte: today } } }), prisma.adhocRequest.count({ where: { ...scope, scheduledAt: { gte: yesterday, lt: today } } }),
    prisma.adhocRequest.aggregate({ _sum: { estimatedAmount: true }, where: { ...scope, createdAt: { gte: monthStart }, status: { not: 'CANCELLED' } } }),
    prisma.adhocRequest.aggregate({ _sum: { estimatedAmount: true }, where: { ...scope, createdAt: { gte: lastMonthStart, lt: monthStart }, status: { not: 'CANCELLED' } } }),
    prisma.adhocRequest.count({ where: { ...scope, createdAt: { gte: monthStart } } }),
  ]);
  const rev = Number(revenue._sum.estimatedAmount ?? 0); const lastRev = Number(lastMonthRevenue._sum.estimatedAmount ?? 0);
  res.json({ success: true, data: { total, assigned, pending, cancelled, completed, todays, yesterdays, estRevenue: rev, revenueGrowthPct: lastRev ? Math.round(((rev - lastRev) / lastRev) * 100) : 0, newThisMonth: newMonth, fulfillmentPct: total ? Math.round(((assigned + completed) / total) * 100) : 0, pendingPct: total ? Math.round((pending / total) * 100) : 0, cancelledPct: total ? Math.round((cancelled / total) * 100) : 0 } });
}));

adhocRouter.get('/analytics', asyncHandler(async (req, res) => {
  const scope = supervisorScope(req); const days = 14; const since = dayjs().subtract(days - 1, 'day').startOf('day').toDate(); const monthStart = dayjs().startOf('month').toDate();
  const [rows, byStatus, byType, byClient] = await Promise.all([
    prisma.adhocRequest.findMany({ where: { ...scope, createdAt: { gte: since } }, select: { createdAt: true } }),
    prisma.adhocRequest.groupBy({ by: ['status'], _count: { _all: true }, where: scope }),
    prisma.adhocRequest.groupBy({ by: ['vehicleType'], _count: { _all: true }, where: scope }),
    prisma.adhocRequest.groupBy({ by: ['clientId'], _count: { _all: true }, where: { ...scope, createdAt: { gte: monthStart } }, orderBy: { _count: { clientId: 'desc' } } }),
  ]);
  const clients = await prisma.client.findMany({ where: { id: { in: byClient.map((c) => c.clientId).filter(Boolean) as string[] } } });
  const trend: { date: string; count: number }[] = [];
  for (let i = 0; i < days; i++) { const d = dayjs(since).add(i, 'day'); trend.push({ date: d.format('YYYY-MM-DD'), count: rows.filter((r) => dayjs(r.createdAt).isSame(d, 'day')).length }); }
  res.json({ success: true, data: { trend, byStatus: byStatus.map((s) => ({ status: s.status, count: s._count._all })), byVehicleType: byType.map((s) => ({ vehicleType: s.vehicleType, count: s._count._all })), byClient: byClient.map((c) => ({ clientId: c.clientId, name: clients.find((x) => x.id === c.clientId)?.name ?? 'Others', count: c._count._all })) } });
}));

adhocRouter.get('/', asyncHandler(async (req, res) => {
  const p = pageParams(req);
  const q = str(req.query.q); const status = str(req.query.status); const clientId = str(req.query.clientId); const vehicleType = str(req.query.vehicleType); const location = str(req.query.location); const from = str(req.query.from); const to = str(req.query.to);
  const where: Prisma.AdhocRequestWhereInput = {
    ...supervisorScope(req),
    ...(q ? { OR: [{ code: { contains: q, mode: 'insensitive' } }, { fromLocation: { contains: q, mode: 'insensitive' } }, { toLocation: { contains: q, mode: 'insensitive' } }, { client: { name: { contains: q, mode: 'insensitive' } } }, { supervisor: { user: { fullName: { contains: q, mode: 'insensitive' } } } }, { contactName: { contains: q, mode: 'insensitive' } }] } : {}),
    ...(status ? { status: status.toUpperCase() as any } : {}), ...(clientId ? { clientId } : {}), ...(vehicleType ? { vehicleType: vehicleType.toUpperCase() as any } : {}),
    ...(location ? { OR: [{ fromLocation: { contains: location, mode: 'insensitive' } }, { toLocation: { contains: location, mode: 'insensitive' } }] } : {}),
    ...(from || to ? { scheduledAt: { ...(from ? { gte: dayjs(from).startOf('day').toDate() } : {}), ...(to ? { lte: dayjs(to).endOf('day').toDate() } : {}) } } : {}),
  };
  const [items, total] = await Promise.all([prisma.adhocRequest.findMany({ where, include, orderBy: { scheduledAt: 'desc' }, skip: p.skip, take: p.take }), prisma.adhocRequest.count({ where })]);
  res.json({ success: true, data: paged(items.map(shapeAdhoc), total, p) });
}));

const createSchema = z.object({
  clientId: z.string().optional(), contactName: z.string().optional(), contactMobile: z.string().optional(),
  fromLocation: z.string().min(2), toLocation: z.string().min(2), fromLatitude: z.number().optional(), fromLongitude: z.number().optional(), toLatitude: z.number().optional(), toLongitude: z.number().optional(),
  scheduledAt: z.string(), loginTime: z.string().optional(), reportingTime: z.string().optional(), passengers: z.coerce.number().int().min(1).default(1),
  vehicleType: z.enum(VEHICLE_TYPES), modelYearMin: z.coerce.number().int().optional(), numberOfVehicles: z.coerce.number().int().min(1).default(1),
  bookingType: z.enum(['INSTANT', 'SCHEDULED']).default('INSTANT'), platformId: z.string().optional(), platformCode: z.string().optional(), otherPlatformName: z.string().optional(),
  specialInstructions: z.string().optional(), estimatedAmount: z.coerce.number().optional(),
});

adhocRouter.post('/estimate', asyncHandler(async (req, res) => {
  const b = parse(z.object({ vehicleType: z.enum(VEHICLE_TYPES), numberOfVehicles: z.coerce.number().int().min(1).default(1), passengers: z.coerce.number().int().min(1).default(1) }), req.body);
  res.json({ success: true, data: { estimatedAmount: await estimateAmount(b.vehicleType, b.numberOfVehicles, b.passengers), currency: 'INR' } });
}));

adhocRouter.post('/', asyncHandler(async (req, res) => {
  const b = parse(createSchema, req.body);
  const sup = req.user!.role === 'SUPERVISOR' ? await prisma.supervisor.findUnique({ where: { id: req.user!.supervisorId! }, include: { user: true } }) : null;
  if (sup && sup.user.status !== 'ACTIVE') throw forbidden('Your account is awaiting approval');
  const platform = b.platformId ? await prisma.platform.findUnique({ where: { id: b.platformId } }) : b.platformCode ? await prisma.platform.findUnique({ where: { code: b.platformCode.toUpperCase() } }) : null;
  const scheduledAt = new Date(b.scheduledAt);
  const a = await prisma.adhocRequest.create({
    data: {
      code: await nextAdhocCode(scheduledAt), clientId: b.clientId ?? sup?.clientId ?? undefined, supervisorId: sup?.id, contactName: b.contactName ?? sup?.user.fullName, contactMobile: b.contactMobile ?? sup?.user.mobile,
      fromLocation: b.fromLocation, toLocation: b.toLocation, fromLatitude: b.fromLatitude, fromLongitude: b.fromLongitude, toLatitude: b.toLatitude, toLongitude: b.toLongitude,
      scheduledAt, loginTime: b.loginTime, reportingTime: b.reportingTime, passengers: b.passengers, vehicleType: b.vehicleType, modelYearMin: b.modelYearMin, numberOfVehicles: b.numberOfVehicles,
      bookingType: b.bookingType, platformId: platform?.id, otherPlatformName: b.otherPlatformName, specialInstructions: b.specialInstructions,
      estimatedAmount: b.estimatedAmount ?? (await estimateAmount(b.vehicleType, b.numberOfVehicles, b.passengers)),
    },
    include,
  });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'ADHOC', entityId: a.id, action: 'POSTED', details: `${a.vehicleType} | ${a.fromLocation} → ${a.toLocation} | Platform: ${platform?.name ?? b.otherPlatformName ?? 'Other'}` });
  await notifyAdmins({ type: 'TRIP_REQUEST', title: 'New ad-hoc requirement', body: `${a.code}: ${a.vehicleType} ${a.fromLocation} → ${a.toLocation} on ${dayjs(scheduledAt).format('DD MMM YYYY hh:mm A')}`, data: { adhocId: a.id } });
  // broadcast to active drivers who have a matching vehicle type
  const drivers = await prisma.driver.findMany({ where: { user: { status: 'ACTIVE' }, vehicles: { some: { type: a.vehicleType, status: 'ACTIVE' } } }, select: { userId: true } });
  if (drivers.length) await notifyMany(drivers.map((d) => d.userId), { type: 'TRIP_REQUEST', title: 'New Ad-hoc Requirement', body: `${a.vehicleType.replace('_', ' ')} • ${dayjs(scheduledAt).format('DD MMM YYYY')} • ${a.fromLocation}`, data: { adhocId: a.id, code: a.code } });
  res.status(201).json({ success: true, data: shapeAdhoc(a) });
}));

adhocRouter.get('/:id', asyncHandler(async (req, res) => {
  const a = await prisma.adhocRequest.findFirst({ where: { OR: [{ id: req.params.id }, { code: req.params.id }], ...supervisorScope(req) }, include });
  if (!a) throw notFound('Request not found');
  const activities = await prisma.activityLog.findMany({ where: { entityType: 'ADHOC', entityId: a.id }, orderBy: { createdAt: 'desc' } });
  res.json({ success: true, data: { ...shapeAdhoc(a), activities } });
}));

adhocRouter.put('/:id', asyncHandler(async (req, res) => {
  const b = parse(createSchema.partial(), req.body);
  const existing = await prisma.adhocRequest.findFirst({ where: { id: req.params.id, ...supervisorScope(req) } });
  if (!existing) throw notFound('Request not found');
  if (['COMPLETED', 'CANCELLED'].includes(existing.status)) throw badRequest('Cannot edit a completed or cancelled request');
  const platform = b.platformId ? await prisma.platform.findUnique({ where: { id: b.platformId } }) : b.platformCode ? await prisma.platform.findUnique({ where: { code: b.platformCode.toUpperCase() } }) : undefined;
  const a = await prisma.adhocRequest.update({ where: { id: existing.id }, data: { ...b, platformCode: undefined, scheduledAt: b.scheduledAt ? new Date(b.scheduledAt) : undefined, platformId: platform === undefined ? undefined : platform?.id } as any, include });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'ADHOC', entityId: a.id, action: 'UPDATED', details: 'Modified time and location for the requirement' });
  res.json({ success: true, data: shapeAdhoc(a) });
}));

adhocRouter.post('/:id/assign', requireRole('ADMIN'), asyncHandler(async (req, res) => {
  const b = parse(z.object({ vehicleId: z.string(), driverId: z.string().optional(), amount: z.coerce.number().optional() }), req.body);
  const a = await prisma.adhocRequest.findUnique({ where: { id: req.params.id }, include });
  if (!a) throw notFound('Request not found');
  if (['COMPLETED', 'CANCELLED'].includes(a.status)) throw badRequest('Request is closed');
  const vehicle = await prisma.vehicle.findUnique({ where: { id: b.vehicleId }, include: { driver: true } });
  if (!vehicle) throw notFound('Vehicle not found');
  const driverId = b.driverId ?? vehicle.driverId;
  if (!driverId) throw badRequest('Vehicle has no assigned driver; provide driverId');
  const driver = await prisma.driver.findUniqueOrThrow({ where: { id: driverId }, include: { user: true } });
  const amount = b.amount ?? (a.estimatedAmount ? Number(a.estimatedAmount) : await estimateAmount(a.vehicleType, a.numberOfVehicles));
  const [updated] = await prisma.$transaction(async (tx) => {
    const u = await tx.adhocRequest.update({ where: { id: a.id }, data: { status: 'ASSIGNED', assignedVehicleId: vehicle.id, assignedDriverId: driver.id, assignedAt: new Date(), estimatedAmount: amount } });
    const existingTrip = a.trips.find((t) => !['CANCELLED'].includes(t.status));
    const trip = existingTrip
      ? await tx.trip.update({ where: { id: existingTrip.id }, data: { driverId: driver.id, vehicleId: vehicle.id, status: 'ASSIGNED', amount } })
      : await tx.trip.create({ data: { code: await nextTripCode(a.scheduledAt), adhocRequestId: a.id, driverId: driver.id, vehicleId: vehicle.id, platformId: a.platformId, supervisorId: a.supervisorId, clientId: a.clientId, fromLocation: a.fromLocation, toLocation: a.toLocation, scheduledStart: a.scheduledAt, loginTime: a.loginTime, reportingTime: a.reportingTime, amount, status: 'ASSIGNED', events: { create: [{ type: 'REQUIREMENT_POSTED', at: a.createdAt, note: `Requirement ${a.code} posted` }, { type: 'VENDOR_ASSIGNED', note: `${driver.user.fullName} / ${vehicle.number} assigned by ${req.user!.fullName}` }] } } });
    if (!existingTrip) { /* noop */ } else await tx.tripEvent.create({ data: { tripId: trip.id, type: 'VENDOR_ASSIGNED', note: `Re-assigned to ${driver.user.fullName} / ${vehicle.number}` } });
    return [u, trip];
  });
  await notifyUser(driver.userId, { type: 'TRIP_REQUEST', title: 'New Ad-hoc Requirement', body: `${a.vehicleType.replace('_', ' ')} • ${dayjs(a.scheduledAt).format('DD MMM YYYY')} • ${a.fromLocation} → ${a.toLocation}`, data: { adhocId: a.id, code: a.code } });
  if (a.supervisor) await notifyUser(a.supervisor.userId, { type: 'TRIP_UPDATE', title: 'Vendor assigned', body: `Vehicle ${vehicle.number} (${driver.user.fullName}) assigned to your request ${a.code}.`, data: { adhocId: a.id } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'ADHOC', entityId: a.id, action: 'ASSIGNED', details: `Assigned ${vehicle.number} / ${driver.user.fullName}` });
  const out = await prisma.adhocRequest.findUniqueOrThrow({ where: { id: updated.id }, include });
  res.json({ success: true, data: shapeAdhoc(out) });
}));

adhocRouter.post('/:id/cancel', asyncHandler(async (req, res) => {
  const b = parse(z.object({ reason: z.string().optional() }), req.body ?? {});
  const a = await prisma.adhocRequest.findFirst({ where: { id: req.params.id, ...supervisorScope(req) }, include });
  if (!a) throw notFound('Request not found');
  if (a.status === 'COMPLETED') throw badRequest('Completed request cannot be cancelled');
  await prisma.$transaction([
    prisma.adhocRequest.update({ where: { id: a.id }, data: { status: 'CANCELLED', cancelReason: b.reason ?? 'Cancelled' } }),
    prisma.trip.updateMany({ where: { adhocRequestId: a.id, status: { notIn: ['COMPLETED', 'CANCELLED'] } }, data: { status: 'CANCELLED' } }),
    prisma.booking.updateMany({ where: { adhocRequestId: a.id, status: { notIn: ['COMPLETED', 'CANCELLED'] } }, data: { status: 'CANCELLED', cancelReason: b.reason ?? 'Requirement cancelled' } }),
  ]);
  for (const t of a.trips) if (!['COMPLETED', 'CANCELLED'].includes(t.status)) await prisma.tripEvent.create({ data: { tripId: t.id, type: 'TRIP_CANCELLED', note: b.reason ?? 'Requirement cancelled' } });
  if (a.assignedDriver) await notifyUser(a.assignedDriver.userId, { type: 'TRIP_UPDATE', title: 'Trip cancelled', body: `Requirement ${a.code} was cancelled.${b.reason ? ` Reason: ${b.reason}` : ''}`, data: { adhocId: a.id } });
  if (a.supervisor && req.user!.role === 'ADMIN') await notifyUser(a.supervisor.userId, { type: 'TRIP_UPDATE', title: 'Requirement cancelled', body: `${a.code} was cancelled by Gamya Mobility.${b.reason ? ` Reason: ${b.reason}` : ''}` });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'ADHOC', entityId: a.id, action: 'CANCELLED', details: b.reason ?? 'Requirement cancelled due to client request' });
  res.json({ success: true, data: shapeAdhoc(await prisma.adhocRequest.findUniqueOrThrow({ where: { id: a.id }, include })) });
}));
