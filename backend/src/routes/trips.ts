import { Router } from 'express';
import dayjs from 'dayjs';
import { z } from 'zod';
import type { Prisma, TripStatus, TripEventType } from '@prisma/client';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { parse } from '../utils/validate.js';
import { badRequest, forbidden, notFound } from '../utils/errors.js';
import { pageParams, paged, str } from '../utils/pagination.js';
import { logActivity } from '../utils/activity.js';
import { notifyAdmins, notifyUser } from '../services/notifications.js';
import { requireRole } from '../middleware/auth.js';

export const tripsRouter = Router();
tripsRouter.use(requireRole('ADMIN', 'SUPERVISOR', 'DRIVER'));

const include = { driver: { include: { user: true } }, vehicle: { include: { photos: true } }, platform: true, supervisor: { include: { user: true } }, client: true, booking: true, adhocRequest: true, events: { orderBy: { at: 'asc' as const } } } satisfies Prisma.TripInclude;

export function shapeTrip(t: Prisma.TripGetPayload<{ include: typeof include }>) {
  const src = t.adhocRequest;
  return {
    id: t.id, code: t.code, status: t.status, bookingId: t.bookingId, bookingCode: t.booking?.code ?? null, adhocRequestId: t.adhocRequestId, adhocCode: t.adhocRequest?.code ?? null,
    driver: { id: t.driver.id, code: t.driver.code, fullName: t.driver.user.fullName, mobile: t.driver.user.mobile, avatarUrl: t.driver.user.avatarUrl ?? t.driver.selfieUrl },
    vehicle: { id: t.vehicle.id, number: t.vehicle.number, make: t.vehicle.make, model: t.vehicle.model, type: t.vehicle.type, year: t.vehicle.year, photoUrl: t.vehicle.photos[0]?.url ?? null },
    platform: t.platform ? { id: t.platform.id, name: t.platform.name, code: t.platform.code, color: t.platform.color, deepLinkScheme: t.platform.deepLinkScheme, websiteUrl: t.platform.websiteUrl } : null,
    supervisor: t.supervisor ? { id: t.supervisor.id, fullName: t.supervisor.user.fullName, mobile: t.supervisor.user.mobile, companyName: t.supervisor.companyName } : null, clientName: t.client?.name ?? t.supervisor?.companyName ?? null,
    fromLocation: t.fromLocation, toLocation: t.toLocation, scheduledStart: t.scheduledStart, loginTime: t.loginTime ?? src?.loginTime ?? null, reportingTime: t.reportingTime ?? src?.reportingTime ?? null, startedAt: t.startedAt, completedAt: t.completedAt,
    vehicleType: src?.vehicleType ?? t.vehicle.type, modelYearMin: src?.modelYearMin ?? null, bookingType: src?.bookingType ?? (t.booking ? 'SCHEDULED' : 'INSTANT'), passengers: src?.passengers ?? t.booking?.passengers ?? 1, specialInstructions: src?.specialInstructions ?? null,
    amount: t.amount ? Number(t.amount) : null, distanceKm: t.distanceKm, onTime: t.onTime, externalTripId: t.externalTripId, notes: t.notes, createdAt: t.createdAt,
    events: t.events.map((e) => ({ id: e.id, type: e.type, note: e.note, at: e.at })),
  };
}

const LIVE: TripStatus[] = ['ACCEPTED', 'YET_TO_START', 'ON_TRIP', 'DELAYED'];

function scope(req: import('express').Request): Prisma.TripWhereInput {
  if (req.user!.role === 'DRIVER') return { driverId: req.user!.driverId };
  if (req.user!.role === 'SUPERVISOR') return { supervisorId: req.user!.supervisorId };
  return {};
}

tripsRouter.get('/stats', asyncHandler(async (req, res) => {
  const s = scope(req); const today = dayjs().startOf('day').toDate(); const tomorrow = dayjs(today).add(1, 'day').toDate(); const yesterday = dayjs(today).subtract(1, 'day').toDate();
  const [live, onTrip, delayed, yetToStart, completedToday, completedYesterday, cancelledToday, todayTotal, total, completed] = await Promise.all([
    prisma.trip.count({ where: { ...s, status: { in: LIVE } } }), prisma.trip.count({ where: { ...s, status: 'ON_TRIP' } }), prisma.trip.count({ where: { ...s, status: 'DELAYED' } }), prisma.trip.count({ where: { ...s, status: { in: ['ASSIGNED', 'ACCEPTED', 'YET_TO_START'] }, scheduledStart: { gte: today, lt: tomorrow } } }),
    prisma.trip.count({ where: { ...s, status: 'COMPLETED', completedAt: { gte: today } } }), prisma.trip.count({ where: { ...s, status: 'COMPLETED', completedAt: { gte: yesterday, lt: today } } }), prisma.trip.count({ where: { ...s, status: 'CANCELLED', updatedAt: { gte: today } } }),
    prisma.trip.count({ where: { ...s, scheduledStart: { gte: today, lt: tomorrow } } }), prisma.trip.count({ where: s }), prisma.trip.count({ where: { ...s, status: 'COMPLETED' } }),
  ]);
  const onTimeToday = await prisma.trip.count({ where: { ...s, status: 'COMPLETED', completedAt: { gte: today }, onTime: true } });
  res.json({ success: true, data: { live, onTrip, delayed, yetToStart, completedToday, completedYesterday, cancelledToday, todayTotal, total, completed, onTimeToday, completedGrowthPct: completedYesterday ? Math.round(((completedToday - completedYesterday) / completedYesterday) * 100) : 0 } });
}));

tripsRouter.get('/', asyncHandler(async (req, res) => {
  const p = pageParams(req);
  const q = str(req.query.q); const status = str(req.query.status); const view = str(req.query.view); const platform = str(req.query.platform); const from = str(req.query.from); const to = str(req.query.to); const clientId = str(req.query.clientId);
  const where: Prisma.TripWhereInput = {
    ...scope(req),
    ...(view === 'live' ? { status: { in: LIVE } } : view === 'completed' ? { status: 'COMPLETED' } : view === 'cancelled' ? { status: 'CANCELLED' } : view === 'ongoing' ? { status: { in: ['ASSIGNED', ...LIVE] } } : view === 'upcoming' ? { status: { in: ['ASSIGNED', 'ACCEPTED', 'YET_TO_START'] }, scheduledStart: { gt: new Date() } } : {}),
    ...(status ? { status: status.toUpperCase() as any } : {}), ...(clientId ? { clientId } : {}),
    ...(platform ? { platform: { OR: [{ id: platform }, { code: platform.toUpperCase() }] } } : {}),
    ...(q ? { OR: [{ code: { contains: q, mode: 'insensitive' } }, { fromLocation: { contains: q, mode: 'insensitive' } }, { toLocation: { contains: q, mode: 'insensitive' } }, { driver: { user: { fullName: { contains: q, mode: 'insensitive' } } } }, { vehicle: { number: { contains: q, mode: 'insensitive' } } }, { client: { name: { contains: q, mode: 'insensitive' } } }] } : {}),
    ...(from || to ? { scheduledStart: { ...(from ? { gte: dayjs(from).startOf('day').toDate() } : {}), ...(to ? { lte: dayjs(to).endOf('day').toDate() } : {}) } } : {}),
  };
  const [items, total] = await Promise.all([prisma.trip.findMany({ where, include, orderBy: { scheduledStart: 'desc' }, skip: p.skip, take: p.take }), prisma.trip.count({ where })]);
  res.json({ success: true, data: paged(items.map(shapeTrip), total, p) });
}));

/** Driver: trip requests awaiting acceptance (assigned to me or open requests matching my vehicle) */
tripsRouter.get('/available', requireRole('DRIVER'), asyncHandler(async (req, res) => {
  const me = await prisma.driver.findUniqueOrThrow({ where: { id: req.user!.driverId! }, include: { vehicles: true } });
  const types = me.vehicles.map((v) => v.type);
  const assigned = await prisma.trip.findMany({ where: { driverId: me.id, status: 'ASSIGNED' }, include, orderBy: { scheduledStart: 'asc' } });
  const open = await prisma.adhocRequest.findMany({ where: { status: 'PENDING', vehicleType: { in: types.length ? types : ['SEDAN'] }, scheduledAt: { gte: dayjs().subtract(2, 'hour').toDate() } }, include: { platform: true, client: true, supervisor: { include: { user: true } } }, orderBy: { scheduledAt: 'asc' }, take: 20 });
  res.json({ success: true, data: { assigned: assigned.map(shapeTrip), open: open.map((a) => ({ id: a.id, code: a.code, vehicleType: a.vehicleType, modelYearMin: a.modelYearMin, scheduledAt: a.scheduledAt, loginTime: a.loginTime, reportingTime: a.reportingTime, fromLocation: a.fromLocation, toLocation: a.toLocation, bookingType: a.bookingType, platform: a.platform ? { id: a.platform.id, name: a.platform.name, color: a.platform.color } : null, estimatedAmount: a.estimatedAmount ? Number(a.estimatedAmount) : null, clientName: a.client?.name ?? a.supervisor?.companyName ?? null, createdAt: a.createdAt })) } });
}));

tripsRouter.get('/:id', asyncHandler(async (req, res) => {
  const t = await prisma.trip.findFirst({ where: { OR: [{ id: req.params.id }, { code: req.params.id }], ...scope(req) }, include });
  if (!t) throw notFound('Trip not found');
  res.json({ success: true, data: shapeTrip(t) });
}));

async function ownTrip(req: import('express').Request) {
  const t = await prisma.trip.findFirst({ where: { OR: [{ id: req.params.id }, { code: req.params.id }] }, include });
  if (!t) throw notFound('Trip not found');
  if (req.user!.role === 'DRIVER' && t.driverId !== req.user!.driverId) throw forbidden('Not your trip');
  if (req.user!.role === 'SUPERVISOR' && t.supervisorId !== req.user!.supervisorId) throw forbidden('Not your trip');
  return t;
}

tripsRouter.post('/:id/accept', requireRole('DRIVER'), asyncHandler(async (req, res) => {
  const t = await ownTrip(req);
  if (t.status !== 'ASSIGNED') throw badRequest(`Trip is already ${t.status.toLowerCase()}`);
  const platformName = t.platform?.name ?? 'the tracking platform';
  const u = await prisma.trip.update({ where: { id: t.id }, data: { status: 'ACCEPTED', events: { create: [{ type: 'DRIVER_ACCEPTED', note: `Accepted by ${t.driver.user.fullName}` }, { type: 'TRIP_CREATED_IN_PLATFORM', note: `Trip to be performed in ${platformName}` }] } }, include });
  if (t.adhocRequestId) await prisma.adhocRequest.update({ where: { id: t.adhocRequestId }, data: { status: 'ACCEPTED' } });
  if (t.supervisor) await notifyUser(t.supervisor.userId, { type: 'TRIP_UPDATE', title: 'Driver accepted', body: `${t.driver.user.fullName} accepted trip ${t.code}. Track it in ${platformName}.`, data: { tripId: t.id } });
  await notifyAdmins({ type: 'TRIP_UPDATE', title: 'Trip accepted', body: `${t.driver.user.fullName} accepted ${t.code}.`, data: { tripId: t.id } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'TRIP', entityId: t.id, action: 'ACCEPTED', details: `Accepted ad-hoc request ${t.adhocRequest?.code ?? t.code}` });
  res.json({ success: true, data: shapeTrip(u) });
}));

tripsRouter.post('/:id/decline', requireRole('DRIVER'), asyncHandler(async (req, res) => {
  const b = parse(z.object({ reason: z.string().optional() }), req.body ?? {});
  const t = await ownTrip(req);
  if (t.status !== 'ASSIGNED') throw badRequest(`Trip is already ${t.status.toLowerCase()}`);
  await prisma.trip.update({ where: { id: t.id }, data: { status: 'CANCELLED', notes: b.reason, events: { create: { type: 'DRIVER_DECLINED', note: b.reason ?? `Declined by ${t.driver.user.fullName}` } } } });
  if (t.adhocRequestId) await prisma.adhocRequest.update({ where: { id: t.adhocRequestId }, data: { status: 'PENDING', assignedDriverId: null, assignedVehicleId: null, assignedAt: null } });
  await notifyAdmins({ type: 'TRIP_UPDATE', title: 'Driver declined trip', body: `${t.driver.user.fullName} declined ${t.code}. Please re-assign.`, data: { tripId: t.id, adhocId: t.adhocRequestId } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'TRIP', entityId: t.id, action: 'DECLINED', details: b.reason ?? 'Declined' });
  res.json({ success: true });
}));

/** Driver accepts an open (unassigned) ad-hoc request directly – first come first served. */
tripsRouter.post('/adhoc/:adhocId/accept', requireRole('DRIVER'), asyncHandler(async (req, res) => {
  const me = await prisma.driver.findUniqueOrThrow({ where: { id: req.user!.driverId! }, include: { user: true, vehicles: { where: { status: 'ACTIVE' } } } });
  if (me.user.status !== 'ACTIVE') throw forbidden('Account not active');
  const a = await prisma.adhocRequest.findUnique({ where: { id: req.params.adhocId }, include: { supervisor: true, platform: true } });
  if (!a) throw notFound('Request not found');
  if (a.status !== 'PENDING') throw badRequest('Request already taken');
  const vehicle = me.vehicles.find((v) => v.type === a.vehicleType) ?? me.vehicles[0];
  if (!vehicle) throw badRequest('You have no active vehicle');
  const { nextTripCode } = await import('../utils/codes.js');
  const trip = await prisma.$transaction(async (tx) => {
    await tx.adhocRequest.update({ where: { id: a.id }, data: { status: 'ACCEPTED', assignedDriverId: me.id, assignedVehicleId: vehicle.id, assignedAt: new Date() } });
    return tx.trip.create({ data: { code: await nextTripCode(a.scheduledAt), adhocRequestId: a.id, driverId: me.id, vehicleId: vehicle.id, platformId: a.platformId, supervisorId: a.supervisorId, clientId: a.clientId, fromLocation: a.fromLocation, toLocation: a.toLocation, scheduledStart: a.scheduledAt, loginTime: a.loginTime, reportingTime: a.reportingTime, amount: a.estimatedAmount, status: 'ACCEPTED', events: { create: [{ type: 'REQUIREMENT_POSTED', at: a.createdAt, note: `Requirement ${a.code} posted` }, { type: 'VENDOR_ASSIGNED', note: `${me.user.fullName} / ${vehicle.number}` }, { type: 'DRIVER_ACCEPTED', note: `Accepted by ${me.user.fullName}` }, { type: 'TRIP_CREATED_IN_PLATFORM', note: `Trip to be performed in ${a.platform?.name ?? 'platform'}` }] } }, include });
  });
  if (a.supervisor) await notifyUser(a.supervisor.userId, { type: 'TRIP_UPDATE', title: 'Driver accepted', body: `${me.user.fullName} (${vehicle.number}) accepted your request ${a.code}.`, data: { tripId: trip.id, adhocId: a.id } });
  await notifyAdmins({ type: 'TRIP_UPDATE', title: 'Ad-hoc request accepted', body: `${me.user.fullName} accepted ${a.code}.`, data: { tripId: trip.id } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'TRIP', entityId: trip.id, action: 'ACCEPTED', details: `Accepted ad-hoc request ${a.code}` });
  res.json({ success: true, data: shapeTrip(trip) });
}));

tripsRouter.post('/:id/start', requireRole('DRIVER', 'ADMIN'), asyncHandler(async (req, res) => {
  const b = parse(z.object({ externalTripId: z.string().optional() }), req.body ?? {});
  const t = await ownTrip(req);
  if (!['ACCEPTED', 'YET_TO_START', 'ASSIGNED'].includes(t.status)) throw badRequest(`Trip cannot be started from ${t.status}`);
  const late = dayjs().isAfter(dayjs(t.scheduledStart).add(15, 'minute'));
  const u = await prisma.trip.update({ where: { id: t.id }, data: { status: late ? 'DELAYED' : 'ON_TRIP', startedAt: new Date(), externalTripId: b.externalTripId, events: { create: [{ type: 'DRIVER_STARTED', note: late ? 'Started late' : 'Driver started the trip' }, ...(late ? [{ type: 'TRIP_DELAYED' as const, note: 'Started more than 15 min after scheduled time' }] : [])] } }, include });
  if (t.adhocRequestId) await prisma.adhocRequest.update({ where: { id: t.adhocRequestId }, data: { status: 'IN_PROGRESS' } });
  if (t.supervisor) await notifyUser(t.supervisor.userId, { type: 'TRIP_UPDATE', title: 'Driver started', body: `${t.driver.user.fullName} started trip ${t.code}.`, data: { tripId: t.id } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'TRIP', entityId: t.id, action: 'STARTED' });
  res.json({ success: true, data: shapeTrip(u) });
}));

tripsRouter.post('/:id/complete', requireRole('DRIVER', 'ADMIN'), asyncHandler(async (req, res) => {
  const b = parse(z.object({ amount: z.coerce.number().optional(), distanceKm: z.coerce.number().optional(), notes: z.string().optional() }), req.body ?? {});
  const t = await ownTrip(req);
  if (!['ON_TRIP', 'DELAYED', 'ACCEPTED', 'YET_TO_START'].includes(t.status)) throw badRequest(`Trip cannot be completed from ${t.status}`);
  const amount = b.amount ?? (t.amount ? Number(t.amount) : 0);
  const u = await prisma.$transaction(async (tx) => {
    const up = await tx.trip.update({ where: { id: t.id }, data: { status: 'COMPLETED', completedAt: new Date(), amount, distanceKm: b.distanceKm, notes: b.notes, onTime: t.status !== 'DELAYED', events: { create: { type: 'TRIP_COMPLETED', note: 'Trip completed' } } }, include });
    await tx.earning.create({ data: { driverId: t.driverId, tripId: t.id, amount, date: new Date() } });
    if (t.adhocRequestId) await tx.adhocRequest.update({ where: { id: t.adhocRequestId }, data: { status: 'COMPLETED' } });
    if (t.bookingId) await tx.booking.update({ where: { id: t.bookingId }, data: { status: 'COMPLETED' } });
    return up;
  });
  if (t.supervisor) await notifyUser(t.supervisor.userId, { type: 'TRIP_UPDATE', title: 'Trip completed', body: `Trip ${t.code} completed by ${t.driver.user.fullName}.`, data: { tripId: t.id } });
  await notifyUser(t.driver.userId, { type: 'PAYMENT', title: 'Trip completed', body: `₹${amount} added to your earnings for ${t.code}.`, data: { tripId: t.id } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'TRIP', entityId: t.id, action: 'COMPLETED', details: `Trip ${t.code} marked as completed` });
  res.json({ success: true, data: shapeTrip(u) });
}));

tripsRouter.patch('/:id/status', requireRole('ADMIN'), asyncHandler(async (req, res) => {
  const b = parse(z.object({ status: z.enum(['ASSIGNED', 'ACCEPTED', 'YET_TO_START', 'ON_TRIP', 'DELAYED', 'COMPLETED', 'CANCELLED']), note: z.string().optional() }), req.body);
  const t = await ownTrip(req);
  const evt: Record<string, TripEventType> = { DELAYED: 'TRIP_DELAYED', CANCELLED: 'TRIP_CANCELLED', COMPLETED: 'TRIP_COMPLETED', ON_TRIP: 'DRIVER_STARTED', ACCEPTED: 'DRIVER_ACCEPTED' };
  const u = await prisma.trip.update({ where: { id: t.id }, data: { status: b.status, ...(b.status === 'COMPLETED' ? { completedAt: new Date() } : {}), events: { create: { type: evt[b.status] ?? 'NOTE', note: b.note ?? `Status set to ${b.status} by admin` } } }, include });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'TRIP', entityId: t.id, action: 'STATUS_CHANGED', details: b.status });
  res.json({ success: true, data: shapeTrip(u) });
}));

tripsRouter.post('/:id/events', asyncHandler(async (req, res) => {
  const b = parse(z.object({ note: z.string().min(1) }), req.body);
  const t = await ownTrip(req);
  await prisma.tripEvent.create({ data: { tripId: t.id, type: 'NOTE', note: b.note } });
  res.json({ success: true });
}));
