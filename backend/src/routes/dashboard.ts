import { Router } from 'express';
import dayjs from 'dayjs';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { str } from '../utils/pagination.js';
import { requireAdmin } from '../middleware/auth.js';

export const dashboardRouter = Router();
dashboardRouter.use(requireAdmin);

dashboardRouter.get('/', asyncHandler(async (req, res) => {
  const date = str(req.query.date) ? dayjs(str(req.query.date)) : dayjs();
  const dayStart = date.startOf('day').toDate(); const dayEnd = date.endOf('day').toDate(); const weekAgo = date.subtract(7, 'day').toDate(); const prevWeek = date.subtract(14, 'day').toDate(); const yesterdayStart = date.subtract(1, 'day').startOf('day').toDate();
  const LIVE = ['ACCEPTED', 'YET_TO_START', 'ON_TRIP', 'DELAYED'] as const;
  const [supervisors, supWeek, drivers, drvWeek, vehicles, vehWeek, adhoc, adhocWeek, adhocPrevWeek, activeTrips, completedToday, completedYesterday,
    platformBookings, todayTrips, recentAdhoc, liveTrips, pendingDrivers, pendingSupervisors, recentDrivers, recentSupervisors, pendingApprovalsCount, unreadNotifications, bookingsWeek] = await Promise.all([
    prisma.supervisor.count(), prisma.supervisor.count({ where: { createdAt: { gte: weekAgo } } }), prisma.driver.count(), prisma.driver.count({ where: { createdAt: { gte: weekAgo } } }), prisma.vehicle.count(), prisma.vehicle.count({ where: { createdAt: { gte: weekAgo } } }),
    prisma.adhocRequest.count({ where: { status: { notIn: ['COMPLETED', 'CANCELLED'] } } }), prisma.adhocRequest.count({ where: { createdAt: { gte: weekAgo } } }), prisma.adhocRequest.count({ where: { createdAt: { gte: prevWeek, lt: weekAgo } } }),
    prisma.trip.count({ where: { status: { in: [...LIVE] } } }), prisma.trip.count({ where: { status: 'COMPLETED', completedAt: { gte: dayStart, lte: dayEnd } } }), prisma.trip.count({ where: { status: 'COMPLETED', completedAt: { gte: yesterdayStart, lt: dayStart } } }),
    prisma.trip.groupBy({ by: ['platformId'], _count: { _all: true }, where: { scheduledStart: { gte: weekAgo } } }),
    prisma.trip.findMany({ where: { scheduledStart: { gte: dayStart, lte: dayEnd } }, select: { status: true, onTime: true } }),
    prisma.adhocRequest.findMany({ orderBy: { createdAt: 'desc' }, take: 5, include: { platform: true } }),
    prisma.trip.findMany({ where: { status: { in: [...LIVE] } }, orderBy: { startedAt: 'desc' }, take: 5, include: { driver: { include: { user: true } }, vehicle: true, platform: true } }),
    prisma.approvalRequest.findMany({ where: { status: 'PENDING', type: 'DRIVER_REGISTRATION' }, orderBy: { submittedAt: 'asc' }, take: 5, include: { driver: { include: { user: true, vehicles: true } } } }),
    prisma.approvalRequest.findMany({ where: { status: 'PENDING', type: 'SUPERVISOR_REGISTRATION' }, orderBy: { submittedAt: 'asc' }, take: 5, include: { supervisor: { include: { user: true } } } }),
    prisma.driver.findMany({ orderBy: { createdAt: 'desc' }, take: 5, include: { user: true } }), prisma.supervisor.findMany({ orderBy: { createdAt: 'desc' }, take: 5, include: { user: true } }),
    prisma.approvalRequest.count({ where: { status: 'PENDING' } }), prisma.notification.count({ where: { userId: req.user!.id, read: false } }),
    prisma.booking.findMany({ where: { date: { gte: date.subtract(6, 'day').startOf('day').toDate(), lte: dayEnd } }, select: { date: true, tripType: true } }),
  ]);
  const platforms = await prisma.platform.findMany({ orderBy: { sortOrder: 'asc' } });
  const other = platforms.find((p) => p.code === 'OTHER');
  const platformWise = platforms.map((p) => ({ id: p.id, name: p.name, color: p.color, count: platformBookings.filter((g) => g.platformId === p.id || (p.id === other?.id && g.platformId === null)).reduce((s, g) => s + g._count._all, 0) }));
  const bookingsOverview = Array.from({ length: 7 }, (_, i) => { const d = date.subtract(6 - i, 'day'); const rows = bookingsWeek.filter((b) => dayjs(b.date).isSame(d, 'day')); return { date: d.format('YYYY-MM-DD'), label: d.format('D MMM'), scheduled: rows.filter((b) => b.tripType === 'REGULAR').length, instant: rows.filter((b) => b.tripType === 'ADHOC').length }; });
  const tripStatus = { onTime: todayTrips.filter((t) => t.status === 'COMPLETED' && t.onTime !== false).length + todayTrips.filter((t) => t.status === 'ON_TRIP').length, delayed: todayTrips.filter((t) => t.status === 'DELAYED' || (t.status === 'COMPLETED' && t.onTime === false)).length, yetToStart: todayTrips.filter((t) => ['ASSIGNED', 'ACCEPTED', 'YET_TO_START'].includes(t.status)).length, cancelled: todayTrips.filter((t) => t.status === 'CANCELLED').length, total: todayTrips.length };
  res.json({ success: true, data: {
    date: date.format('YYYY-MM-DD'), badges: { pendingApprovals: pendingApprovalsCount, unreadNotifications },
    stats: { totalSupervisors: supervisors, supervisorsThisWeek: supWeek, totalDrivers: drivers, driversThisWeek: drvWeek, totalVehicles: vehicles, vehiclesThisWeek: vehWeek, adhocRequirements: adhoc, adhocGrowthPct: adhocPrevWeek ? Math.round(((adhocWeek - adhocPrevWeek) / adhocPrevWeek) * 100) : adhocWeek ? 100 : 0, activeTrips, completedToday, completedGrowthPct: completedYesterday ? Math.round(((completedToday - completedYesterday) / completedYesterday) * 100) : completedToday ? 100 : 0 },
    bookingsOverview, platformWise: { total: platformWise.reduce((s, p) => s + p.count, 0), items: platformWise }, tripStatus,
    recentAdhoc: recentAdhoc.map((a) => ({ id: a.id, code: a.code, date: a.scheduledAt, vehicleType: a.vehicleType, fromLocation: a.fromLocation, toLocation: a.toLocation, platform: a.platform?.name ?? a.otherPlatformName ?? 'Other', platformColor: a.platform?.color ?? '#9CA3AF', status: a.status, bookingType: a.bookingType })),
    liveTrips: liveTrips.map((t) => ({ id: t.id, code: t.code, driverName: t.driver.user.fullName, vehicleNumber: t.vehicle.number, platform: t.platform?.name ?? 'Other', platformColor: t.platform?.color ?? '#9CA3AF', fromLocation: t.fromLocation, toLocation: t.toLocation, status: t.status })),
    pendingApprovals: { drivers: pendingDrivers.map((a) => ({ approvalId: a.id, id: a.driver?.id, name: a.driver?.user.fullName, mobile: a.driver?.user.mobile, vehicleNumber: a.driver?.vehicles[0]?.number ?? null, submittedOn: a.submittedAt })), supervisors: pendingSupervisors.map((a) => ({ approvalId: a.id, id: a.supervisor?.id, name: a.supervisor?.user.fullName, mobile: a.supervisor?.user.mobile, company: a.supervisor?.companyName, submittedOn: a.submittedAt })), driversCount: await prisma.approvalRequest.count({ where: { status: 'PENDING', type: 'DRIVER_REGISTRATION' } }), supervisorsCount: await prisma.approvalRequest.count({ where: { status: 'PENDING', type: 'SUPERVISOR_REGISTRATION' } }) },
    recentRegistrations: { drivers: recentDrivers.map((d) => ({ id: d.id, name: d.user.fullName, mobile: d.user.mobile, type: 'Driver', registeredOn: d.createdAt, status: d.user.status })), supervisors: recentSupervisors.map((s) => ({ id: s.id, name: s.user.fullName, mobile: s.user.mobile, type: 'Supervisor', registeredOn: s.createdAt, status: s.user.status })) },
  } });
}));

dashboardRouter.get('/search', asyncHandler(async (req, res) => {
  const q = str(req.query.q);
  if (!q) return res.json({ success: true, data: { drivers: [], supervisors: [], vehicles: [], bookings: [], adhoc: [] } });
  const [drivers, supervisors, vehicles, bookings, adhoc] = await Promise.all([
    prisma.driver.findMany({ where: { OR: [{ user: { fullName: { contains: q, mode: 'insensitive' } } }, { user: { mobile: { contains: q } } }, { code: { contains: q, mode: 'insensitive' } }] }, include: { user: true }, take: 5 }),
    prisma.supervisor.findMany({ where: { OR: [{ user: { fullName: { contains: q, mode: 'insensitive' } } }, { user: { mobile: { contains: q } } }, { code: { contains: q, mode: 'insensitive' } }] }, include: { user: true }, take: 5 }),
    prisma.vehicle.findMany({ where: { OR: [{ number: { contains: q, mode: 'insensitive' } }, { make: { contains: q, mode: 'insensitive' } }, { model: { contains: q, mode: 'insensitive' } }] }, take: 5 }),
    prisma.booking.findMany({ where: { OR: [{ code: { contains: q, mode: 'insensitive' } }, { employeeName: { contains: q, mode: 'insensitive' } }] }, take: 5 }),
    prisma.adhocRequest.findMany({ where: { OR: [{ code: { contains: q, mode: 'insensitive' } }, { fromLocation: { contains: q, mode: 'insensitive' } }, { toLocation: { contains: q, mode: 'insensitive' } }] }, take: 5 }),
  ]);
  res.json({ success: true, data: {
    drivers: drivers.map((d) => ({ id: d.id, code: d.code, name: d.user.fullName, mobile: d.user.mobile, route: '/drivers' })), supervisors: supervisors.map((s) => ({ id: s.id, code: s.code, name: s.user.fullName, mobile: s.user.mobile, route: '/supervisors' })),
    vehicles: vehicles.map((v) => ({ id: v.id, number: v.number, name: `${v.make} ${v.model}`, route: '/vehicles' })), bookings: bookings.map((b) => ({ id: b.id, code: b.code, name: b.employeeName, route: '/bookings' })), adhoc: adhoc.map((a) => ({ id: a.id, code: a.code, name: `${a.fromLocation} → ${a.toLocation}`, route: '/adhoc' })),
  } });
}));
