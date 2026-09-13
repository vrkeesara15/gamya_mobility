import { Router } from 'express';
import dayjs from 'dayjs';
import { z } from 'zod';
import { parse as parseCsv } from 'csv-parse/sync';
import { stringify } from 'csv-stringify/sync';
import type { Prisma } from '@prisma/client';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { parse } from '../utils/validate.js';
import { badRequest, notFound } from '../utils/errors.js';
import { pageParams, paged, str } from '../utils/pagination.js';
import { nextBookingCode, nextTripCode } from '../utils/codes.js';
import { logActivity } from '../utils/activity.js';
import { notifyUser } from '../services/notifications.js';
import { requireRole } from '../middleware/auth.js';
import { estimateAmount } from './adhoc.js';

export const bookingsRouter = Router();
bookingsRouter.use(requireRole('ADMIN', 'SUPERVISOR'));

const VEHICLE_TYPES = ['SEDAN', 'SUV', 'INNOVA', 'TEMPO_TRAVELLER', 'TEMPO', 'OTHER'] as const;
const include = { client: true, supervisor: { include: { user: true } }, vehicle: { include: { photos: true } }, driver: { include: { user: true } }, platform: true, adhocRequest: true, trips: { include: { events: { orderBy: { at: 'asc' as const } } }, orderBy: { createdAt: 'desc' as const } } } satisfies Prisma.BookingInclude;

export function shapeBooking(b: Prisma.BookingGetPayload<{ include: typeof include }>) {
  const trip = b.trips[0];
  return {
    id: b.id, code: b.code, date: b.date, employeeName: b.employeeName, employeeMobile: b.employeeMobile, employeeEmail: b.employeeEmail,
    clientId: b.clientId, clientName: b.client?.name ?? b.supervisor?.companyName ?? null, supervisor: b.supervisor ? { id: b.supervisor.id, fullName: b.supervisor.user.fullName, mobile: b.supervisor.user.mobile } : null,
    tripType: b.tripType, adhocRequestId: b.adhocRequestId, adhocCode: b.adhocRequest?.code ?? null, fromLocation: b.fromLocation, toLocation: b.toLocation, passengers: b.passengers, vehicleType: b.vehicleType,
    vehicle: b.vehicle ? { id: b.vehicle.id, number: b.vehicle.number, make: b.vehicle.make, model: b.vehicle.model, type: b.vehicle.type, photoUrl: b.vehicle.photos[0]?.url ?? null } : null,
    driver: b.driver ? { id: b.driver.id, code: b.driver.code, fullName: b.driver.user.fullName, mobile: b.driver.user.mobile, avatarUrl: b.driver.user.avatarUrl } : null,
    platform: b.platform ? { id: b.platform.id, name: b.platform.name, code: b.platform.code, color: b.platform.color } : null,
    status: b.status, estimatedAmount: b.estimatedAmount ? Number(b.estimatedAmount) : null, notes: b.notes, cancelReason: b.cancelReason, createdAt: b.createdAt, updatedAt: b.updatedAt,
    trip: trip ? { id: trip.id, code: trip.code, status: trip.status, startedAt: trip.startedAt, completedAt: trip.completedAt, events: trip.events } : null,
  };
}

const scope = (req: import('express').Request): Prisma.BookingWhereInput => (req.user!.role === 'SUPERVISOR' ? { supervisorId: req.user!.supervisorId } : {});

bookingsRouter.get('/stats', asyncHandler(async (req, res) => {
  const s = scope(req); const weekAgo = dayjs().subtract(7, 'day').toDate(); const monthStart = dayjs().startOf('month').toDate(); const lastMonthStart = dayjs().subtract(1, 'month').startOf('month').toDate(); const today = dayjs().startOf('day').toDate();
  const [total, confirmed, pending, cancelled, completed, rescheduled, regular, adhoc, newWeek, employees, revenue, lastRevenue, todayCount, scheduled] = await Promise.all([
    prisma.booking.count({ where: s }), prisma.booking.count({ where: { ...s, status: 'CONFIRMED' } }), prisma.booking.count({ where: { ...s, status: 'PENDING' } }), prisma.booking.count({ where: { ...s, status: 'CANCELLED' } }),
    prisma.booking.count({ where: { ...s, status: 'COMPLETED' } }), prisma.booking.count({ where: { ...s, status: 'RESCHEDULED' } }), prisma.booking.count({ where: { ...s, tripType: 'REGULAR' } }), prisma.booking.count({ where: { ...s, tripType: 'ADHOC' } }),
    prisma.booking.count({ where: { ...s, createdAt: { gte: weekAgo } } }), prisma.booking.findMany({ where: s, distinct: ['employeeName'], select: { employeeName: true } }),
    prisma.booking.aggregate({ _sum: { estimatedAmount: true }, where: { ...s, date: { gte: monthStart }, status: { not: 'CANCELLED' } } }),
    prisma.booking.aggregate({ _sum: { estimatedAmount: true }, where: { ...s, date: { gte: lastMonthStart, lt: monthStart }, status: { not: 'CANCELLED' } } }),
    prisma.booking.count({ where: { ...s, date: { gte: today, lt: dayjs(today).add(1, 'day').toDate() } } }), prisma.booking.count({ where: { ...s, date: { gt: new Date() }, status: { in: ['PENDING', 'CONFIRMED'] } } }),
  ]);
  const rev = Number(revenue._sum.estimatedAmount ?? 0); const last = Number(lastRevenue._sum.estimatedAmount ?? 0);
  res.json({ success: true, data: { total, confirmed, pending, cancelled, completed, rescheduled, regular, adhoc, newThisWeek: newWeek, uniqueEmployees: employees.length, estRevenue: rev, revenueGrowthPct: last ? Math.round(((rev - last) / last) * 100) : 0, confirmedPct: total ? Math.round((confirmed / total) * 100) : 0, pendingPct: total ? Math.round((pending / total) * 100) : 0, cancelledPct: total ? Math.round((cancelled / total) * 100) : 0, today: todayCount, scheduled } });
}));

bookingsRouter.get('/analytics', asyncHandler(async (req, res) => {
  const s = scope(req); const days = 14; const since = dayjs().subtract(days - 1, 'day').startOf('day').toDate();
  const [rows, byStatus, byType, byClient] = await Promise.all([
    prisma.booking.findMany({ where: { ...s, date: { gte: since } }, select: { date: true, tripType: true } }),
    prisma.booking.groupBy({ by: ['status'], _count: { _all: true }, where: s }), prisma.booking.groupBy({ by: ['tripType'], _count: { _all: true }, where: s }),
    prisma.booking.groupBy({ by: ['clientId'], _count: { _all: true }, where: s, orderBy: { _count: { clientId: 'desc' } }, take: 10 }),
  ]);
  const clients = await prisma.client.findMany({ where: { id: { in: byClient.map((c) => c.clientId).filter(Boolean) as string[] } } });
  const trend = Array.from({ length: days }, (_, i) => { const d = dayjs(since).add(i, 'day'); const day = rows.filter((r) => dayjs(r.date).isSame(d, 'day')); return { date: d.format('YYYY-MM-DD'), regular: day.filter((r) => r.tripType === 'REGULAR').length, adhoc: day.filter((r) => r.tripType === 'ADHOC').length }; });
  res.json({ success: true, data: { trend, byStatus: byStatus.map((x) => ({ status: x.status, count: x._count._all })), byTripType: byType.map((x) => ({ tripType: x.tripType, count: x._count._all })), topClients: byClient.map((c) => ({ clientId: c.clientId, name: clients.find((x) => x.id === c.clientId)?.name ?? 'Others', count: c._count._all })) } });
}));

function listWhere(req: import('express').Request): Prisma.BookingWhereInput {
  const q = str(req.query.q); const status = str(req.query.status); const clientId = str(req.query.clientId); const tripType = str(req.query.tripType); const location = str(req.query.location); const from = str(req.query.from); const to = str(req.query.to);
  return {
    ...scope(req),
    ...(q ? { OR: [{ code: { contains: q, mode: 'insensitive' } }, { employeeName: { contains: q, mode: 'insensitive' } }, { fromLocation: { contains: q, mode: 'insensitive' } }, { toLocation: { contains: q, mode: 'insensitive' } }, { client: { name: { contains: q, mode: 'insensitive' } } }, { driver: { user: { fullName: { contains: q, mode: 'insensitive' } } } }, { vehicle: { number: { contains: q, mode: 'insensitive' } } }] } : {}),
    ...(status ? { status: status.toUpperCase() as any } : {}), ...(clientId ? { clientId } : {}), ...(tripType ? { tripType: tripType.toUpperCase() as any } : {}),
    ...(location ? { OR: [{ fromLocation: { contains: location, mode: 'insensitive' } }, { toLocation: { contains: location, mode: 'insensitive' } }] } : {}),
    ...(from || to ? { date: { ...(from ? { gte: dayjs(from).startOf('day').toDate() } : {}), ...(to ? { lte: dayjs(to).endOf('day').toDate() } : {}) } } : {}),
  };
}

bookingsRouter.get('/', asyncHandler(async (req, res) => {
  const p = pageParams(req); const where = listWhere(req);
  const [items, total] = await Promise.all([prisma.booking.findMany({ where, include, orderBy: [{ date: 'desc' }, { code: 'desc' }], skip: p.skip, take: p.take }), prisma.booking.count({ where })]);
  res.json({ success: true, data: paged(items.map(shapeBooking), total, p) });
}));

bookingsRouter.get('/export', asyncHandler(async (req, res) => {
  const items = await prisma.booking.findMany({ where: listWhere(req), include, orderBy: { date: 'desc' }, take: 5000 });
  const csv = stringify(items.map(shapeBooking).map((b) => ({ 'Booking ID': b.code, Date: dayjs(b.date).format('YYYY-MM-DD HH:mm'), Employee: b.employeeName, Client: b.clientName, 'Trip Type': b.tripType, From: b.fromLocation, To: b.toLocation, 'Vehicle No': b.vehicle?.number ?? '', Driver: b.driver?.fullName ?? '', Platform: b.platform?.name ?? '', Status: b.status, Amount: b.estimatedAmount ?? '' })), { header: true });
  res.setHeader('Content-Type', 'text/csv'); res.setHeader('Content-Disposition', `attachment; filename="bookings-${dayjs().format('YYYYMMDD')}.csv"`); res.send(csv);
}));

const createSchema = z.object({
  date: z.string(), employeeName: z.string().min(1), employeeMobile: z.string().optional(), employeeEmail: z.string().email().optional(), clientId: z.string().optional(), clientName: z.string().optional(),
  tripType: z.enum(['REGULAR', 'ADHOC']).default('REGULAR'), adhocRequestId: z.string().optional(), fromLocation: z.string().min(1), toLocation: z.string().min(1), passengers: z.coerce.number().int().min(1).default(1),
  vehicleType: z.enum(VEHICLE_TYPES).optional(), vehicleId: z.string().nullable().optional(), driverId: z.string().nullable().optional(), platformId: z.string().nullable().optional(), status: z.enum(['PENDING', 'CONFIRMED', 'RESCHEDULED', 'CANCELLED', 'COMPLETED']).optional(), estimatedAmount: z.coerce.number().optional(), notes: z.string().optional(),
});

async function resolveClient(b: { clientId?: string; clientName?: string }, req: import('express').Request) {
  if (b.clientId) return b.clientId;
  if (b.clientName) return (await prisma.client.upsert({ where: { name: b.clientName }, update: {}, create: { name: b.clientName } })).id;
  if (req.user!.role === 'SUPERVISOR') return (await prisma.supervisor.findUnique({ where: { id: req.user!.supervisorId! } }))?.clientId ?? undefined;
  return undefined;
}

bookingsRouter.post('/', asyncHandler(async (req, res) => {
  const b = parse(createSchema, req.body);
  const date = new Date(b.date);
  const bk = await prisma.booking.create({ data: { code: await nextBookingCode(date), date, employeeName: b.employeeName, employeeMobile: b.employeeMobile, employeeEmail: b.employeeEmail, clientId: await resolveClient(b, req), supervisorId: req.user!.supervisorId, tripType: b.tripType, adhocRequestId: b.adhocRequestId, fromLocation: b.fromLocation, toLocation: b.toLocation, passengers: b.passengers, vehicleType: b.vehicleType, vehicleId: b.vehicleId ?? undefined, driverId: b.driverId ?? undefined, platformId: b.platformId ?? undefined, status: b.status ?? 'PENDING', estimatedAmount: b.estimatedAmount ?? (b.vehicleType ? await estimateAmount(b.vehicleType) : undefined), notes: b.notes }, include });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'BOOKING', entityId: bk.id, action: 'CREATED', details: `${bk.code} ${bk.fromLocation} → ${bk.toLocation}` });
  res.status(201).json({ success: true, data: shapeBooking(bk) });
}));

bookingsRouter.post('/import', requireRole('ADMIN'), asyncHandler(async (req, res) => {
  const rowsIn: Record<string, string>[] = Array.isArray(req.body?.rows) ? req.body.rows : typeof req.body?.csv === 'string' ? parseCsv(req.body.csv, { columns: true, skip_empty_lines: true, trim: true }) : [];
  if (!rowsIn.length) throw badRequest('Provide { rows: [...] } or { csv: "..." }');
  const results: { row: number; ok: boolean; code?: string; error?: string }[] = [];
  for (const [i, r] of rowsIn.entries()) {
    try {
      const b = parse(createSchema, { date: r.date ?? r.Date, employeeName: r.employeeName ?? r.Employee, employeeMobile: r.employeeMobile ?? r.Mobile, clientName: r.clientName ?? r.Client, tripType: String(r.tripType ?? r['Trip Type'] ?? 'REGULAR').toUpperCase().replace('-', ''), fromLocation: r.fromLocation ?? r.From, toLocation: r.toLocation ?? r.To, passengers: r.passengers ?? r.Pax ?? 1, vehicleType: r.vehicleType ? String(r.vehicleType).toUpperCase().replace(' ', '_') : undefined });
      const date = new Date(b.date);
      const bk = await prisma.booking.create({ data: { code: await nextBookingCode(date), date, employeeName: b.employeeName, employeeMobile: b.employeeMobile, clientId: await resolveClient(b, req), tripType: b.tripType, fromLocation: b.fromLocation, toLocation: b.toLocation, passengers: b.passengers, vehicleType: b.vehicleType, status: 'PENDING', estimatedAmount: b.vehicleType ? await estimateAmount(b.vehicleType) : undefined } });
      results.push({ row: i + 1, ok: true, code: bk.code });
    } catch (e) { results.push({ row: i + 1, ok: false, error: e instanceof Error ? e.message : 'invalid' }); }
  }
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'BOOKING', action: 'IMPORTED', details: `${results.filter((r) => r.ok).length}/${results.length} bookings imported` });
  res.json({ success: true, data: { imported: results.filter((r) => r.ok).length, failed: results.filter((r) => !r.ok).length, results } });
}));

bookingsRouter.get('/:id', asyncHandler(async (req, res) => {
  const bk = await prisma.booking.findFirst({ where: { OR: [{ id: req.params.id }, { code: req.params.id }], ...scope(req) }, include });
  if (!bk) throw notFound('Booking not found');
  const activities = await prisma.activityLog.findMany({ where: { entityType: 'BOOKING', entityId: bk.id }, orderBy: { createdAt: 'desc' } });
  res.json({ success: true, data: { ...shapeBooking(bk), activities } });
}));

bookingsRouter.put('/:id', asyncHandler(async (req, res) => {
  const b = parse(createSchema.partial(), req.body);
  const existing = await prisma.booking.findFirst({ where: { id: req.params.id, ...scope(req) } });
  if (!existing) throw notFound('Booking not found');
  const bk = await prisma.booking.update({ where: { id: existing.id }, data: { ...b, clientName: undefined, clientId: b.clientId ?? (b.clientName ? await resolveClient(b, req) : undefined), date: b.date ? new Date(b.date) : undefined } as any, include });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'BOOKING', entityId: bk.id, action: 'UPDATED', details: 'Booking updated' });
  res.json({ success: true, data: shapeBooking(bk) });
}));

bookingsRouter.post('/:id/confirm', requireRole('ADMIN'), asyncHandler(async (req, res) => {
  const bk = await prisma.booking.findUnique({ where: { id: req.params.id }, include });
  if (!bk) throw notFound('Booking not found');
  if (bk.status === 'CANCELLED' || bk.status === 'COMPLETED') throw badRequest(`Booking is ${bk.status.toLowerCase()}`);
  let updated = await prisma.booking.update({ where: { id: bk.id }, data: { status: 'CONFIRMED' }, include });
  if (updated.driverId && updated.vehicleId && !updated.trips.length) {
    await prisma.trip.create({ data: { code: await nextTripCode(bk.date), bookingId: bk.id, driverId: updated.driverId, vehicleId: updated.vehicleId, platformId: updated.platformId, supervisorId: updated.supervisorId, clientId: updated.clientId, fromLocation: bk.fromLocation, toLocation: bk.toLocation, scheduledStart: bk.date, amount: bk.estimatedAmount, status: 'ASSIGNED', events: { create: [{ type: 'REQUIREMENT_POSTED', at: bk.createdAt, note: `Booking ${bk.code} created` }, { type: 'VENDOR_ASSIGNED', note: `Confirmed by ${req.user!.fullName}` }] } } });
    updated = await prisma.booking.findUniqueOrThrow({ where: { id: bk.id }, include });
    await notifyUser(updated.driver!.userId, { type: 'TRIP_REQUEST', title: 'New trip assigned', body: `${bk.code}: ${bk.fromLocation} → ${bk.toLocation} on ${dayjs(bk.date).format('DD MMM, hh:mm A')}`, data: { bookingId: bk.id } });
  }
  if (bk.supervisor) await notifyUser(bk.supervisor.userId, { type: 'TRIP_UPDATE', title: 'Booking confirmed', body: `Your booking ${bk.code} has been confirmed.` });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'BOOKING', entityId: bk.id, action: 'CONFIRMED', details: `${bk.code} confirmed` });
  res.json({ success: true, data: shapeBooking(updated) });
}));

bookingsRouter.post('/:id/assign', requireRole('ADMIN'), asyncHandler(async (req, res) => {
  const b = parse(z.object({ vehicleId: z.string(), driverId: z.string().optional(), platformId: z.string().optional() }), req.body);
  const vehicle = await prisma.vehicle.findUnique({ where: { id: b.vehicleId } });
  if (!vehicle) throw notFound('Vehicle not found');
  const driverId = b.driverId ?? vehicle.driverId;
  if (!driverId) throw badRequest('Vehicle has no assigned driver; provide driverId');
  const bk = await prisma.booking.update({ where: { id: req.params.id }, data: { vehicleId: vehicle.id, driverId, platformId: b.platformId ?? vehicle.platformId ?? undefined }, include });
  for (const t of bk.trips) if (!['COMPLETED', 'CANCELLED'].includes(t.status)) await prisma.trip.update({ where: { id: t.id }, data: { vehicleId: vehicle.id, driverId, events: { create: { type: 'VENDOR_ASSIGNED', note: `Re-assigned to ${vehicle.number}` } } } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'BOOKING', entityId: bk.id, action: 'ASSIGNED', details: `Assigned ${vehicle.number} / ${bk.driver?.user.fullName ?? ''}` });
  res.json({ success: true, data: shapeBooking(bk) });
}));

bookingsRouter.post('/:id/cancel', asyncHandler(async (req, res) => {
  const b = parse(z.object({ reason: z.string().optional() }), req.body ?? {});
  const bk = await prisma.booking.findFirst({ where: { id: req.params.id, ...scope(req) }, include });
  if (!bk) throw notFound('Booking not found');
  if (bk.status === 'COMPLETED') throw badRequest('Completed booking cannot be cancelled');
  await prisma.$transaction([
    prisma.booking.update({ where: { id: bk.id }, data: { status: 'CANCELLED', cancelReason: b.reason ?? 'Cancelled' } }),
    prisma.trip.updateMany({ where: { bookingId: bk.id, status: { notIn: ['COMPLETED', 'CANCELLED'] } }, data: { status: 'CANCELLED' } }),
  ]);
  if (bk.driver) await notifyUser(bk.driver.userId, { type: 'TRIP_UPDATE', title: 'Booking cancelled', body: `${bk.code} was cancelled.${b.reason ? ` Reason: ${b.reason}` : ''}` });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'BOOKING', entityId: bk.id, action: 'CANCELLED', details: b.reason ?? 'Cancelled' });
  res.json({ success: true, data: shapeBooking(await prisma.booking.findUniqueOrThrow({ where: { id: bk.id }, include })) });
}));

bookingsRouter.post('/:id/reschedule', asyncHandler(async (req, res) => {
  const b = parse(z.object({ date: z.string(), reason: z.string().optional() }), req.body);
  const existing = await prisma.booking.findFirst({ where: { id: req.params.id, ...scope(req) } });
  if (!existing) throw notFound('Booking not found');
  const bk = await prisma.booking.update({ where: { id: existing.id }, data: { date: new Date(b.date), status: 'RESCHEDULED', notes: b.reason }, include });
  await prisma.trip.updateMany({ where: { bookingId: bk.id, status: { notIn: ['COMPLETED', 'CANCELLED'] } }, data: { scheduledStart: new Date(b.date) } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'BOOKING', entityId: bk.id, action: 'RESCHEDULED', details: `Rescheduled to ${dayjs(b.date).format('DD MMM YYYY hh:mm A')}` });
  res.json({ success: true, data: shapeBooking(bk) });
}));
