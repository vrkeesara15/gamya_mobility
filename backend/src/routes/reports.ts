import { Router } from 'express';
import dayjs from 'dayjs';
import { stringify } from 'csv-stringify/sync';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { str } from '../utils/pagination.js';
import { requireAdmin } from '../middleware/auth.js';

export const reportsRouter = Router();
reportsRouter.use(requireAdmin);

function range(req: import('express').Request) {
  const from = str(req.query.from) ? dayjs(str(req.query.from)).startOf('day') : dayjs().subtract(30, 'day').startOf('day');
  const to = str(req.query.to) ? dayjs(str(req.query.to)).endOf('day') : dayjs().endOf('day');
  return { from: from.toDate(), to: to.toDate(), days: to.diff(from, 'day') + 1 };
}

reportsRouter.get('/summary', asyncHandler(async (req, res) => {
  const { from, to } = range(req);
  const [trips, completed, cancelled, delayed, revenue, bookings, adhoc, newDrivers, newVehicles, newSupervisors, earnings] = await Promise.all([
    prisma.trip.count({ where: { scheduledStart: { gte: from, lte: to } } }), prisma.trip.count({ where: { status: 'COMPLETED', completedAt: { gte: from, lte: to } } }), prisma.trip.count({ where: { status: 'CANCELLED', updatedAt: { gte: from, lte: to } } }),
    prisma.trip.count({ where: { scheduledStart: { gte: from, lte: to }, OR: [{ status: 'DELAYED' }, { onTime: false }] } }), prisma.trip.aggregate({ _sum: { amount: true }, where: { status: 'COMPLETED', completedAt: { gte: from, lte: to } } }),
    prisma.booking.count({ where: { date: { gte: from, lte: to } } }), prisma.adhocRequest.count({ where: { scheduledAt: { gte: from, lte: to } } }),
    prisma.driver.count({ where: { createdAt: { gte: from, lte: to } } }), prisma.vehicle.count({ where: { createdAt: { gte: from, lte: to } } }), prisma.supervisor.count({ where: { createdAt: { gte: from, lte: to } } }),
    prisma.earning.aggregate({ _sum: { amount: true }, where: { date: { gte: from, lte: to } } }),
  ]);
  res.json({ success: true, data: { from, to, trips, completed, cancelled, delayed, onTimePct: completed ? Math.round(((completed - delayed) / completed) * 100) : 0, revenue: Number(revenue._sum.amount ?? 0), driverPayout: Number(earnings._sum.amount ?? 0), bookings, adhocRequests: adhoc, newDrivers, newVehicles, newSupervisors } });
}));

reportsRouter.get('/trips-trend', asyncHandler(async (req, res) => {
  const { from, days } = range(req);
  const rows = await prisma.trip.findMany({ where: { scheduledStart: { gte: from, lte: dayjs(from).add(days, 'day').toDate() } }, select: { scheduledStart: true, status: true, amount: true, adhocRequestId: true } });
  const out = Array.from({ length: days }, (_, i) => { const d = dayjs(from).add(i, 'day'); const r = rows.filter((x) => dayjs(x.scheduledStart).isSame(d, 'day')); return { date: d.format('YYYY-MM-DD'), total: r.length, completed: r.filter((x) => x.status === 'COMPLETED').length, cancelled: r.filter((x) => x.status === 'CANCELLED').length, adhoc: r.filter((x) => !!x.adhocRequestId).length, scheduled: r.filter((x) => !x.adhocRequestId).length, revenue: r.filter((x) => x.status === 'COMPLETED').reduce((s, x) => s + Number(x.amount ?? 0), 0) }; });
  res.json({ success: true, data: out });
}));

reportsRouter.get('/by-platform', asyncHandler(async (req, res) => {
  const { from, to } = range(req);
  const [platforms, groups] = await Promise.all([prisma.platform.findMany({ orderBy: { sortOrder: 'asc' } }), prisma.trip.groupBy({ by: ['platformId'], _count: { _all: true }, _sum: { amount: true }, where: { scheduledStart: { gte: from, lte: to } } })]);
  res.json({ success: true, data: platforms.map((p) => { const g = groups.find((x) => x.platformId === p.id); return { id: p.id, name: p.name, color: p.color, trips: g?._count._all ?? 0, revenue: Number(g?._sum.amount ?? 0) }; }) });
}));

reportsRouter.get('/by-client', asyncHandler(async (req, res) => {
  const { from, to } = range(req);
  const groups = await prisma.trip.groupBy({ by: ['clientId'], _count: { _all: true }, _sum: { amount: true }, where: { scheduledStart: { gte: from, lte: to } }, orderBy: { _count: { clientId: 'desc' } } });
  const clients = await prisma.client.findMany({ where: { id: { in: groups.map((g) => g.clientId).filter(Boolean) as string[] } } });
  res.json({ success: true, data: groups.map((g) => ({ clientId: g.clientId, name: clients.find((c) => c.id === g.clientId)?.name ?? 'Others', trips: g._count._all, revenue: Number(g._sum.amount ?? 0) })) });
}));

reportsRouter.get('/driver-performance', asyncHandler(async (req, res) => {
  const { from, to } = range(req);
  const groups = await prisma.trip.groupBy({ by: ['driverId'], _count: { _all: true }, _sum: { amount: true }, where: { scheduledStart: { gte: from, lte: to } }, orderBy: { _count: { driverId: 'desc' } }, take: 50 });
  const [drivers, delayedGroups, completedGroups] = await Promise.all([
    prisma.driver.findMany({ where: { id: { in: groups.map((g) => g.driverId) } }, include: { user: true, vehicles: true } }),
    prisma.trip.groupBy({ by: ['driverId'], _count: { _all: true }, where: { scheduledStart: { gte: from, lte: to }, OR: [{ status: 'DELAYED' }, { onTime: false }] } }),
    prisma.trip.groupBy({ by: ['driverId'], _count: { _all: true }, where: { scheduledStart: { gte: from, lte: to }, status: 'COMPLETED' } }),
  ]);
  res.json({ success: true, data: groups.map((g) => { const d = drivers.find((x) => x.id === g.driverId); const delayed = delayedGroups.find((x) => x.driverId === g.driverId)?._count._all ?? 0; const completed = completedGroups.find((x) => x.driverId === g.driverId)?._count._all ?? 0; return { driverId: g.driverId, code: d?.code, fullName: d?.user.fullName, mobile: d?.user.mobile, vehicleNumber: d?.vehicles[0]?.number, trips: g._count._all, completed, delayed, onTimePct: completed ? Math.round(((completed - delayed) / completed) * 100) : 0, earnings: Number(g._sum.amount ?? 0), rating: d?.rating }; }) });
}));

reportsRouter.get('/vehicle-utilisation', asyncHandler(async (req, res) => {
  const { from, to, days } = range(req);
  const groups = await prisma.trip.groupBy({ by: ['vehicleId'], _count: { _all: true }, _sum: { distanceKm: true, amount: true }, where: { scheduledStart: { gte: from, lte: to } }, orderBy: { _count: { vehicleId: 'desc' } }, take: 50 });
  const vehicles = await prisma.vehicle.findMany({ where: { id: { in: groups.map((g) => g.vehicleId) } }, include: { driver: { include: { user: true } } } });
  res.json({ success: true, data: groups.map((g) => { const v = vehicles.find((x) => x.id === g.vehicleId); return { vehicleId: g.vehicleId, number: v?.number, makeModel: v ? `${v.make} ${v.model}` : null, type: v?.type, driverName: v?.driver?.user.fullName, trips: g._count._all, tripsPerDay: Number((g._count._all / days).toFixed(2)), distanceKm: g._sum.distanceKm ?? 0, revenue: Number(g._sum.amount ?? 0) }; }) });
}));

reportsRouter.get('/export', asyncHandler(async (req, res) => {
  const { from, to } = range(req); const type = str(req.query.type) ?? 'trips';
  let rows: Record<string, unknown>[] = [];
  if (type === 'trips') {
    const trips = await prisma.trip.findMany({ where: { scheduledStart: { gte: from, lte: to } }, include: { driver: { include: { user: true } }, vehicle: true, platform: true, client: true }, orderBy: { scheduledStart: 'desc' }, take: 10000 });
    rows = trips.map((t) => ({ 'Trip ID': t.code, Date: dayjs(t.scheduledStart).format('YYYY-MM-DD HH:mm'), Client: t.client?.name ?? '', Driver: t.driver.user.fullName, Vehicle: t.vehicle.number, Platform: t.platform?.name ?? '', From: t.fromLocation, To: t.toLocation, Status: t.status, 'On Time': t.onTime === null ? '' : t.onTime ? 'Yes' : 'No', Amount: t.amount ? Number(t.amount) : '' }));
  } else if (type === 'drivers') {
    const drivers = await prisma.driver.findMany({ include: { user: true, vehicles: true, platforms: true } });
    rows = drivers.map((d) => ({ Code: d.code, Name: d.user.fullName, Mobile: d.user.mobile, Email: d.user.email, Status: d.user.status, Vehicle: d.vehicles[0]?.number ?? '', Platforms: d.platforms.map((p) => p.name).join('; '), Joined: d.joiningDate ? dayjs(d.joiningDate).format('YYYY-MM-DD') : '' }));
  } else if (type === 'vehicles') {
    const vehicles = await prisma.vehicle.findMany({ include: { driver: { include: { user: true } }, platform: true } });
    rows = vehicles.map((v) => ({ Number: v.number, Make: v.make, Model: v.model, Year: v.year, Type: v.type, Status: v.status, Driver: v.driver?.user.fullName ?? '', Platform: v.platform?.name ?? '', 'Permit Valid Till': v.permitValidTill ? dayjs(v.permitValidTill).format('YYYY-MM-DD') : '', 'Insurance Valid Till': v.insuranceValidTill ? dayjs(v.insuranceValidTill).format('YYYY-MM-DD') : '' }));
  } else if (type === 'supervisors') {
    const sups = await prisma.supervisor.findMany({ include: { user: true, locations: true, _count: { select: { adhocRequests: true, bookings: true } } } });
    rows = sups.map((s) => ({ Code: s.code, Name: s.user.fullName, 'Employee ID': s.employeeId ?? '', Company: s.companyName, Mobile: s.user.mobile, Email: s.user.email, Locations: s.locations.map((l) => l.name).join('; '), Requests: s._count.adhocRequests, Bookings: s._count.bookings, Status: s.user.status }));
  } else if (type === 'adhoc') {
    const items = await prisma.adhocRequest.findMany({ where: { scheduledAt: { gte: from, lte: to } }, include: { client: true, assignedVehicle: true, assignedDriver: { include: { user: true } } }, orderBy: { scheduledAt: 'desc' } });
    rows = items.map((a) => ({ 'Request ID': a.code, 'Date & Time': dayjs(a.scheduledAt).format('YYYY-MM-DD HH:mm'), Client: a.client?.name ?? '', From: a.fromLocation, To: a.toLocation, Pax: a.passengers, 'Vehicle Type': a.vehicleType, Status: a.status, 'Assigned Vehicle': a.assignedVehicle?.number ?? '', Driver: a.assignedDriver?.user.fullName ?? '', Amount: a.estimatedAmount ? Number(a.estimatedAmount) : '' }));
  }
  res.setHeader('Content-Type', 'text/csv'); res.setHeader('Content-Disposition', `attachment; filename="${type}-${dayjs().format('YYYYMMDD')}.csv"`);
  res.send(stringify(rows, { header: true }));
}));
