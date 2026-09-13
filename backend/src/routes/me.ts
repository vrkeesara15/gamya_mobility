import { Router } from 'express';
import dayjs from 'dayjs';
import { z } from 'zod';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { parse } from '../utils/validate.js';
import { badRequest, notFound } from '../utils/errors.js';
import { pageParams, paged, str } from '../utils/pagination.js';
import { logActivity } from '../utils/activity.js';
import { notifyAdmins } from '../services/notifications.js';
import { upload, storeFile } from '../services/storage.js';
import { requireRole } from '../middleware/auth.js';
import { docSummary, REQUIRED_DRIVER_DOCS } from './drivers.js';

// ───────────────────────── Driver self-service ─────────────────────────
export const driverMeRouter = Router();
driverMeRouter.use(requireRole('DRIVER'));

const VEHICLE_TYPES = ['SEDAN', 'SUV', 'INNOVA', 'TEMPO_TRAVELLER', 'TEMPO', 'OTHER'] as const;
const driverInclude = { user: true, platforms: true, documents: true, vehicles: { include: { photos: true, documents: true, platform: true }, orderBy: { createdAt: 'desc' as const } } };

async function me(req: import('express').Request) {
  const d = await prisma.driver.findUnique({ where: { id: req.user!.driverId! }, include: driverInclude });
  if (!d) throw notFound('Driver profile not found');
  return d;
}

function onboarding(d: Awaited<ReturnType<typeof me>>) {
  const v = d.vehicles[0];
  const docs = [...d.documents, ...(v?.documents ?? [])];
  const uploaded = (t: string) => docs.some((x) => x.type === t);
  const vehiclePhotos = (v?.photos.length ?? 0) >= 2 || (uploaded('VEHICLE_PHOTO_1') && uploaded('VEHICLE_PHOTO_2'));
  return {
    driverDetails: 'SUBMITTED', vehicleDetails: v ? 'SUBMITTED' : 'PENDING', documents: ['RC', 'PERMIT', 'INSURANCE', 'DRIVING_LICENCE'].every(uploaded) && vehiclePhotos ? 'SUBMITTED' : 'PENDING',
    faceVerification: d.faceVerified ? 'COMPLETED' : 'PENDING', accountStatus: d.user.status, approvedAt: d.approvedAt, docs: docSummary(docs),
  };
}

driverMeRouter.get('/profile', asyncHandler(async (req, res) => {
  const d = await me(req);
  res.json({ success: true, data: { id: d.id, code: d.code, fullName: d.user.fullName, email: d.user.email, mobile: d.user.mobile, avatarUrl: d.user.avatarUrl ?? d.selfieUrl, status: d.user.status, dateOfBirth: d.dateOfBirth, address: d.address, licenceNumber: d.licenceNumber, faceVerified: d.faceVerified, faceMatchScore: d.faceMatchScore, selfieUrl: d.selfieUrl, approvedAt: d.approvedAt, rating: d.rating, joiningDate: d.joiningDate, platforms: d.platforms.map((p) => ({ id: p.id, name: p.name, code: p.code, color: p.color })), vehicles: d.vehicles.map((v) => ({ id: v.id, number: v.number, make: v.make, model: v.model, year: v.year, type: v.type, status: v.status, photos: v.photos.map((p) => p.url), documents: v.documents })), documents: d.documents, onboarding: onboarding(d) } });
}));

driverMeRouter.put('/profile', asyncHandler(async (req, res) => {
  const b = parse(z.object({ fullName: z.string().min(2).optional(), email: z.string().email().optional(), dateOfBirth: z.string().optional(), address: z.string().optional(), licenceNumber: z.string().optional(), platformIds: z.array(z.string()).optional(), fcmToken: z.string().optional() }), req.body);
  await prisma.driver.update({ where: { id: req.user!.driverId! }, data: { dateOfBirth: b.dateOfBirth ? new Date(b.dateOfBirth) : undefined, address: b.address, licenceNumber: b.licenceNumber, platforms: b.platformIds ? { set: b.platformIds.map((id) => ({ id })) } : undefined, user: { update: { fullName: b.fullName, email: b.email?.toLowerCase(), fcmToken: b.fcmToken } } } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'DRIVER', entityId: req.user!.driverId, action: 'PROFILE_UPDATED', details: 'Profile updated' });
  res.json({ success: true });
}));

/** Step 1 of onboarding: vehicle details (creates or updates the driver's primary vehicle). */
driverMeRouter.post('/vehicle', asyncHandler(async (req, res) => {
  const b = parse(z.object({ number: z.string().min(4).optional(), make: z.string().min(1), model: z.string().min(1).optional(), year: z.coerce.number().int().min(1990).max(2100), type: z.enum(VEHICLE_TYPES).optional(), color: z.string().optional(), fuelType: z.enum(['PETROL', 'DIESEL', 'CNG', 'ELECTRIC', 'HYBRID']).optional(), seatingCapacity: z.string().optional(), platformIds: z.array(z.string()).optional() }), req.body);
  const d = await me(req);
  const existing = d.vehicles[0];
  const number = (b.number ?? existing?.number ?? `TEMP-${d.code}`).toUpperCase().replace(/\s+/g, '');
  const data = { number, make: b.make, model: b.model ?? existing?.model ?? b.make, year: b.year, type: b.type ?? existing?.type ?? 'SEDAN', color: b.color, fuelType: b.fuelType, seatingCapacity: b.seatingCapacity, driverId: d.id, platformId: b.platformIds?.[0] ?? existing?.platformId ?? undefined } as const;
  const v = existing ? await prisma.vehicle.update({ where: { id: existing.id }, data }) : await prisma.vehicle.create({ data: { ...data, status: 'UNDER_REVIEW' } });
  if (b.platformIds) await prisma.driver.update({ where: { id: d.id }, data: { platforms: { set: b.platformIds.map((id) => ({ id })) } } });
  res.status(existing ? 200 : 201).json({ success: true, data: v });
}));

/** Step 2: vehicle photos (2 required). */
driverMeRouter.post('/vehicle/photos', upload.array('photos', 6), asyncHandler(async (req, res) => {
  const files = (req.files as Express.Multer.File[]) ?? [];
  if (!files.length) throw badRequest('No photos uploaded');
  const d = await me(req);
  const v = d.vehicles[0];
  if (!v) throw badRequest('Add vehicle details first');
  const existingCount = v.photos.length;
  for (const [i, f] of files.entries()) {
    const s = await storeFile(`vehicles/${v.id}`, f);
    await prisma.vehiclePhoto.create({ data: { vehicleId: v.id, url: s.url, caption: f.originalname } });
    const slot = existingCount + i + 1;
    if (slot <= 2) {
      const type = slot === 1 ? 'VEHICLE_PHOTO_1' : 'VEHICLE_PHOTO_2';
      const ex = await prisma.document.findFirst({ where: { vehicleId: v.id, type } });
      if (ex) await prisma.document.update({ where: { id: ex.id }, data: { fileUrl: s.url, fileName: s.fileName, mimeType: s.mimeType, status: 'PENDING' } });
      else await prisma.document.create({ data: { vehicleId: v.id, type, fileUrl: s.url, fileName: s.fileName, mimeType: s.mimeType } });
    }
  }
  const photos = await prisma.vehiclePhoto.findMany({ where: { vehicleId: v.id } });
  res.status(201).json({ success: true, data: photos.map((p) => p.url) });
}));

/** Step 2: documents (RC / Permit / Insurance / Driving Licence …). */
driverMeRouter.post('/documents', upload.single('file'), asyncHandler(async (req, res) => {
  const b = parse(z.object({ type: z.enum(['RC', 'PERMIT', 'INSURANCE', 'DRIVING_LICENCE', 'PUC', 'FITNESS', 'AADHAAR', 'OTHER']), validTill: z.string().optional() }), req.body);
  if (!req.file) throw badRequest('file is required');
  const d = await me(req);
  const v = d.vehicles[0];
  const vehicleDoc = ['RC', 'PERMIT', 'INSURANCE', 'PUC', 'FITNESS'].includes(b.type);
  if (vehicleDoc && !v) throw badRequest('Add vehicle details before uploading vehicle documents');
  const s = await storeFile(`documents/${d.id}`, req.file);
  const where = vehicleDoc ? { vehicleId: v!.id, type: b.type } : { driverId: d.id, type: b.type };
  const existing = await prisma.document.findFirst({ where });
  const isRenewal = !!existing && existing.status === 'VERIFIED';
  const data = { fileUrl: s.url, fileName: s.fileName, mimeType: s.mimeType, validTill: b.validTill ? new Date(b.validTill) : undefined, status: 'PENDING' as const, verifiedAt: null, verifiedById: null, remarks: null };
  const doc = existing ? await prisma.document.update({ where: { id: existing.id }, data }) : await prisma.document.create({ data: { ...data, ...where } });
  if (b.type === 'AADHAAR') await prisma.driver.update({ where: { id: d.id }, data: { idPhotoUrl: s.url } });
  if (d.user.status === 'ACTIVE') {
    await prisma.approvalRequest.create({ data: { type: isRenewal ? 'DOCUMENT_RENEWAL' : 'DOCUMENT_UPLOAD', driverId: d.id, vehicleId: vehicleDoc ? v!.id : undefined, documentId: doc.id, details: `${b.type.replace(/_/g, ' ').toLowerCase()} document` } });
    await notifyAdmins({ type: 'APPROVAL', title: isRenewal ? 'Document renewal' : 'Document uploaded', body: `${d.user.fullName} uploaded ${b.type.replace(/_/g, ' ').toLowerCase()}.`, data: { driverId: d.id, documentId: doc.id } });
  }
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'DRIVER', entityId: d.id, action: 'DOCUMENT_UPLOADED', details: b.type });
  res.status(201).json({ success: true, data: doc });
}));

/** Step 3: submit for approval. */
driverMeRouter.post('/submit', asyncHandler(async (req, res) => {
  const d = await me(req);
  const ob = onboarding(d);
  if (ob.vehicleDetails !== 'SUBMITTED') throw badRequest('Vehicle details are required');
  if (ob.documents !== 'SUBMITTED') throw badRequest('Upload RC, Permit, Insurance, Driving Licence and two vehicle photos');
  if (d.user.status === 'ACTIVE') throw badRequest('Account already approved');
  const existing = await prisma.approvalRequest.findFirst({ where: { driverId: d.id, type: 'DRIVER_REGISTRATION', status: 'PENDING' } });
  if (!existing) {
    await prisma.approvalRequest.create({ data: { type: 'DRIVER_REGISTRATION', driverId: d.id, vehicleId: d.vehicles[0]?.id, details: 'New driver registration' } });
    if (d.vehicles[0]) await prisma.approvalRequest.create({ data: { type: 'VEHICLE_REGISTRATION', vehicleId: d.vehicles[0].id, driverId: d.id, details: 'New vehicle registration' } });
    await notifyAdmins({ type: 'APPROVAL', title: 'New driver registration', body: `${d.user.fullName} submitted registration for approval.`, data: { driverId: d.id } });
    await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'DRIVER', entityId: d.id, action: 'SUBMITTED', details: 'Submitted for approval' });
  }
  res.json({ success: true, data: { ...ob, submitted: true } });
}));

driverMeRouter.get('/status', asyncHandler(async (req, res) => { res.json({ success: true, data: onboarding(await me(req)) }); }));

driverMeRouter.get('/dashboard', asyncHandler(async (req, res) => {
  const d = await me(req); const today = dayjs().startOf('day').toDate(); const tomorrow = dayjs(today).add(1, 'day').toDate();
  const [todaysTrips, availableAssigned, openCount, earningsToday, earningsTotal, unread] = await Promise.all([
    prisma.trip.count({ where: { driverId: d.id, scheduledStart: { gte: today, lt: tomorrow }, status: { not: 'CANCELLED' } } }),
    prisma.trip.count({ where: { driverId: d.id, status: 'ASSIGNED' } }),
    prisma.adhocRequest.count({ where: { status: 'PENDING', vehicleType: { in: d.vehicles.map((v) => v.type) }, scheduledAt: { gte: dayjs().subtract(2, 'hour').toDate() } } }),
    prisma.earning.aggregate({ _sum: { amount: true }, where: { driverId: d.id, date: { gte: today } } }), prisma.earning.aggregate({ _sum: { amount: true }, where: { driverId: d.id } }),
    prisma.notification.count({ where: { userId: d.userId, read: false } }),
  ]);
  res.json({ success: true, data: { fullName: d.user.fullName, code: d.code, status: d.user.status, avatarUrl: d.user.avatarUrl ?? d.selfieUrl, todaysTrips, availableTrips: availableAssigned + openCount, earningsToday: Number(earningsToday._sum.amount ?? 0), earningsTotal: Number(earningsTotal._sum.amount ?? 0), unreadNotifications: unread, onboarding: onboarding(d) } });
}));

driverMeRouter.get('/earnings', asyncHandler(async (req, res) => {
  const p = pageParams(req, 20); const period = str(req.query.period) ?? 'all';
  const since = period === 'week' ? dayjs().startOf('week').toDate() : period === 'month' ? dayjs().startOf('month').toDate() : undefined;
  const where = { driverId: req.user!.driverId!, ...(since ? { date: { gte: since } } : {}) };
  const [items, total, sum, weekSum, monthSum, allSum, pendingSum] = await Promise.all([
    prisma.earning.findMany({ where, include: { trip: { include: { platform: true, vehicle: true } } }, orderBy: { date: 'desc' }, skip: p.skip, take: p.take }), prisma.earning.count({ where }), prisma.earning.aggregate({ _sum: { amount: true }, where }),
    prisma.earning.aggregate({ _sum: { amount: true }, where: { driverId: req.user!.driverId!, date: { gte: dayjs().startOf('week').toDate() } } }), prisma.earning.aggregate({ _sum: { amount: true }, where: { driverId: req.user!.driverId!, date: { gte: dayjs().startOf('month').toDate() } } }),
    prisma.earning.aggregate({ _sum: { amount: true }, where: { driverId: req.user!.driverId! } }), prisma.earning.aggregate({ _sum: { amount: true }, where: { driverId: req.user!.driverId!, status: 'PENDING' } }),
  ]);
  res.json({ success: true, data: { ...paged(items.map((e) => ({ id: e.id, amount: Number(e.amount), date: e.date, status: e.status, tripCode: e.trip?.code ?? null, vehicleType: e.trip?.vehicle.type ?? null, platform: e.trip?.platform?.name ?? 'Other', platformColor: e.trip?.platform?.color ?? '#9CA3AF', fromLocation: e.trip?.fromLocation, toLocation: e.trip?.toLocation })), total, p), periodTotal: Number(sum._sum.amount ?? 0), thisWeek: Number(weekSum._sum.amount ?? 0), thisMonth: Number(monthSum._sum.amount ?? 0), allTime: Number(allSum._sum.amount ?? 0), pending: Number(pendingSum._sum.amount ?? 0) } });
}));

driverMeRouter.get('/documents', asyncHandler(async (req, res) => {
  const d = await me(req); const v = d.vehicles[0];
  const docs = [...d.documents, ...(v?.documents ?? [])];
  res.json({ success: true, data: { required: REQUIRED_DRIVER_DOCS.map((t) => { const doc = docs.find((x) => x.type === t); return { type: t, label: t.replace(/_/g, ' '), status: doc?.status ?? 'MISSING', fileUrl: doc?.fileUrl ?? null, validTill: doc?.validTill ?? null, remarks: doc?.remarks ?? null, id: doc?.id ?? null }; }), summary: docSummary(docs), vehiclePhotos: v?.photos.map((p) => p.url) ?? [] } });
}));

// ───────────────────────── Supervisor self-service ─────────────────────────
export const supervisorMeRouter = Router();
supervisorMeRouter.use(requireRole('SUPERVISOR'));

supervisorMeRouter.get('/profile', asyncHandler(async (req, res) => {
  const s = await prisma.supervisor.findUnique({ where: { id: req.user!.supervisorId! }, include: { user: true, client: true, locations: true, _count: { select: { adhocRequests: true, bookings: true } } } });
  if (!s) throw notFound('Supervisor profile not found');
  res.json({ success: true, data: { id: s.id, code: s.code, fullName: s.user.fullName, email: s.user.email, mobile: s.user.mobile, avatarUrl: s.user.avatarUrl ?? s.selfieUrl, status: s.user.status, employeeId: s.employeeId, companyName: s.companyName, designation: s.designation, dateOfJoining: s.dateOfJoining, faceVerified: s.faceVerified, faceMatchScore: s.faceMatchScore, approvedAt: s.approvedAt, submittedAt: s.createdAt, locations: s.locations.map((l) => l.name), totalRequests: s._count.adhocRequests, totalBookings: s._count.bookings } });
}));

supervisorMeRouter.put('/profile', asyncHandler(async (req, res) => {
  const b = parse(z.object({ fullName: z.string().min(2).optional(), email: z.string().email().optional(), employeeId: z.string().optional(), designation: z.string().optional(), fcmToken: z.string().optional() }), req.body);
  await prisma.supervisor.update({ where: { id: req.user!.supervisorId! }, data: { employeeId: b.employeeId, designation: b.designation, user: { update: { fullName: b.fullName, email: b.email?.toLowerCase(), fcmToken: b.fcmToken } } } });
  res.json({ success: true });
}));

supervisorMeRouter.get('/dashboard', asyncHandler(async (req, res) => {
  const sid = req.user!.supervisorId!; const today = dayjs().startOf('day').toDate(); const tomorrow = dayjs(today).add(1, 'day').toDate();
  const s = await prisma.supervisor.findUniqueOrThrow({ where: { id: sid }, include: { user: true } });
  const [todays, scheduled, completed, ongoing, unread, totalRequests, recent] = await Promise.all([
    prisma.adhocRequest.count({ where: { supervisorId: sid, scheduledAt: { gte: today, lt: tomorrow }, status: { not: 'CANCELLED' } } }),
    prisma.adhocRequest.count({ where: { supervisorId: sid, status: { in: ['PENDING', 'ASSIGNED', 'ACCEPTED'] }, scheduledAt: { gte: new Date() } } }),
    prisma.adhocRequest.count({ where: { supervisorId: sid, status: 'COMPLETED' } }),
    prisma.adhocRequest.count({ where: { supervisorId: sid, status: { in: ['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS'] } } }),
    prisma.notification.count({ where: { userId: s.userId, read: false } }), prisma.adhocRequest.count({ where: { supervisorId: sid } }),
    prisma.adhocRequest.findMany({ where: { supervisorId: sid }, orderBy: { createdAt: 'desc' }, take: 5, include: { platform: true, assignedDriver: { include: { user: true } }, assignedVehicle: true } }),
  ]);
  res.json({ success: true, data: { fullName: s.user.fullName, companyName: s.companyName, designation: s.designation ?? 'Supervisor', avatarUrl: s.user.avatarUrl ?? s.selfieUrl, status: s.user.status, todaysBookings: todays, scheduled, completed, ongoing, totalRequests, unreadNotifications: unread, recent: recent.map((a) => ({ id: a.id, code: a.code, status: a.status, scheduledAt: a.scheduledAt, vehicleType: a.vehicleType, fromLocation: a.fromLocation, toLocation: a.toLocation, platform: a.platform?.name ?? a.otherPlatformName ?? 'Other', driverName: a.assignedDriver?.user.fullName ?? null, vehicleNumber: a.assignedVehicle?.number ?? null, estimatedAmount: a.estimatedAmount ? Number(a.estimatedAmount) : null })) } });
}));

supervisorMeRouter.get('/reports', asyncHandler(async (req, res) => {
  const sid = req.user!.supervisorId!; const from = str(req.query.from) ? dayjs(str(req.query.from)).startOf('day') : dayjs().subtract(30, 'day').startOf('day'); const to = str(req.query.to) ? dayjs(str(req.query.to)).endOf('day') : dayjs().endOf('day');
  const [total, completed, cancelled, amount, byType, byPlatform] = await Promise.all([
    prisma.adhocRequest.count({ where: { supervisorId: sid, scheduledAt: { gte: from.toDate(), lte: to.toDate() } } }), prisma.adhocRequest.count({ where: { supervisorId: sid, status: 'COMPLETED', scheduledAt: { gte: from.toDate(), lte: to.toDate() } } }), prisma.adhocRequest.count({ where: { supervisorId: sid, status: 'CANCELLED', scheduledAt: { gte: from.toDate(), lte: to.toDate() } } }),
    prisma.adhocRequest.aggregate({ _sum: { estimatedAmount: true }, where: { supervisorId: sid, status: { not: 'CANCELLED' }, scheduledAt: { gte: from.toDate(), lte: to.toDate() } } }),
    prisma.adhocRequest.groupBy({ by: ['vehicleType'], _count: { _all: true }, where: { supervisorId: sid, scheduledAt: { gte: from.toDate(), lte: to.toDate() } } }), prisma.adhocRequest.groupBy({ by: ['platformId'], _count: { _all: true }, where: { supervisorId: sid, scheduledAt: { gte: from.toDate(), lte: to.toDate() } } }),
  ]);
  const platforms = await prisma.platform.findMany();
  res.json({ success: true, data: { from: from.toDate(), to: to.toDate(), total, completed, cancelled, estimatedSpend: Number(amount._sum.estimatedAmount ?? 0), byVehicleType: byType.map((x) => ({ vehicleType: x.vehicleType, count: x._count._all })), byPlatform: byPlatform.map((x) => ({ name: platforms.find((p) => p.id === x.platformId)?.name ?? 'Other', color: platforms.find((p) => p.id === x.platformId)?.color ?? '#9CA3AF', count: x._count._all })) } });
}));
