import { Router } from 'express';
import dayjs from 'dayjs';
import { z } from 'zod';
import { parse as parseCsv } from 'csv-parse/sync';
import type { Prisma } from '@prisma/client';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { parse } from '../utils/validate.js';
import { badRequest, notFound } from '../utils/errors.js';
import { pageParams, paged, str } from '../utils/pagination.js';
import { logActivity } from '../utils/activity.js';
import { requireAdmin } from '../middleware/auth.js';
import { upload, storeFile } from '../services/storage.js';

export const vehiclesRouter = Router();
vehiclesRouter.use(requireAdmin);

export const REQUIRED_VEHICLE_DOCS = ['RC', 'PERMIT', 'INSURANCE', 'PUC', 'FITNESS', 'VEHICLE_PHOTO_1', 'VEHICLE_PHOTO_2'] as const;
const VEHICLE_TYPES = ['SEDAN', 'SUV', 'INNOVA', 'TEMPO_TRAVELLER', 'TEMPO', 'OTHER'] as const;

const include = { driver: { include: { user: true } }, supervisor: { include: { user: true } }, platform: true, photos: true, documents: true, _count: { select: { trips: true } } } satisfies Prisma.VehicleInclude;

export function compliance(v: { documents: { type: string; status: string; validTill: Date | null }[]; permitValidTill: Date | null; insuranceValidTill: Date | null; pucValidTill: Date | null; fitnessValidTill: Date | null }) {
  const verified = REQUIRED_VEHICLE_DOCS.filter((t) => v.documents.some((d) => d.type === t && d.status === 'VERIFIED')).length;
  const soon = dayjs().add(30, 'day');
  const dates = [v.permitValidTill, v.insuranceValidTill, v.pucValidTill, v.fitnessValidTill].filter(Boolean) as Date[];
  const expired = dates.some((d) => dayjs(d).isBefore(dayjs()));
  const dueForRenewal = !expired && dates.some((d) => dayjs(d).isBefore(soon));
  const level = expired || verified < 5 ? 'NON_COMPLIANT' : dueForRenewal ? 'DUE_FOR_RENEWAL' : verified < REQUIRED_VEHICLE_DOCS.length ? 'UNDER_VERIFICATION' : 'FULLY_COMPLIANT';
  return { verified, required: REQUIRED_VEHICLE_DOCS.length, label: `${verified}/${REQUIRED_VEHICLE_DOCS.length}`, level, expired, dueForRenewal };
}

export function shapeVehicle(v: Prisma.VehicleGetPayload<{ include: typeof include }>) {
  return {
    id: v.id, number: v.number, make: v.make, model: v.model, makeModel: `${v.make} ${v.model}`, year: v.year, type: v.type, color: v.color, fuelType: v.fuelType, seatingCapacity: v.seatingCapacity,
    status: v.status, registrationDate: v.registrationDate, permitValidTill: v.permitValidTill, insuranceValidTill: v.insuranceValidTill, pucValidTill: v.pucValidTill, fitnessValidTill: v.fitnessValidTill,
    currentLocation: v.currentLocation, latitude: v.latitude, longitude: v.longitude, blacklistReason: v.blacklistReason,
    driver: v.driver ? { id: v.driver.id, code: v.driver.code, fullName: v.driver.user.fullName, mobile: v.driver.user.mobile, avatarUrl: v.driver.user.avatarUrl ?? v.driver.selfieUrl } : null,
    supervisor: v.supervisor ? { id: v.supervisor.id, fullName: v.supervisor.user.fullName } : null,
    platform: v.platform ? { id: v.platform.id, name: v.platform.name, code: v.platform.code, color: v.platform.color } : null,
    photos: v.photos.map((p) => ({ id: p.id, url: p.url, caption: p.caption })), photoUrl: v.photos[0]?.url ?? null,
    documents: v.documents.map((d) => ({ id: d.id, type: d.type, status: d.status, fileUrl: d.fileUrl, validTill: d.validTill, verifiedAt: d.verifiedAt, remarks: d.remarks })),
    compliance: compliance(v), totalTrips: v._count.trips, createdAt: v.createdAt,
  };
}

vehiclesRouter.get('/stats', asyncHandler(async (_req, res) => {
  const monthAgo = dayjs().subtract(30, 'day').toDate();
  const all = await prisma.vehicle.findMany({ select: { status: true, createdAt: true, updatedAt: true, permitValidTill: true, insuranceValidTill: true, pucValidTill: true, fitnessValidTill: true, documents: { select: { type: true, status: true, validTill: true } } } });
  const levels = all.map((v) => compliance(v).level);
  res.json({ success: true, data: {
    total: all.length, active: all.filter((v) => v.status === 'ACTIVE').length, inactive: all.filter((v) => v.status === 'INACTIVE').length,
    underVerification: all.filter((v) => v.status === 'UNDER_REVIEW').length, blacklisted: all.filter((v) => v.status === 'BLACKLISTED').length,
    nonCompliant: levels.filter((l) => l === 'NON_COMPLIANT').length, dueForRenewal: levels.filter((l) => l === 'DUE_FOR_RENEWAL').length, fullyCompliant: levels.filter((l) => l === 'FULLY_COMPLIANT').length,
    newThisMonth: all.filter((v) => v.createdAt >= monthAgo).length, activeThisMonth: all.filter((v) => v.status === 'ACTIVE' && v.updatedAt >= monthAgo).length,
  } });
}));

vehiclesRouter.get('/analytics', asyncHandler(async (_req, res) => {
  const all = await prisma.vehicle.findMany({ select: { type: true, year: true, status: true, permitValidTill: true, insuranceValidTill: true, pucValidTill: true, fitnessValidTill: true, documents: { select: { type: true, status: true, validTill: true } } } });
  const byType: Record<string, number> = {}; const byYear: Record<string, number> = {}; const byCompliance: Record<string, number> = {};
  for (const v of all) { byType[v.type] = (byType[v.type] ?? 0) + 1; byYear[v.year] = (byYear[v.year] ?? 0) + 1; const l = compliance(v).level; byCompliance[l] = (byCompliance[l] ?? 0) + 1; }
  res.json({ success: true, data: { total: all.length, byType, byYear, byCompliance } });
}));

vehiclesRouter.get('/', asyncHandler(async (req, res) => {
  const p = pageParams(req);
  const q = str(req.query.q); const status = str(req.query.status); const type = str(req.query.type); const platform = str(req.query.platform); const complianceF = str(req.query.compliance); const driverId = str(req.query.driverId);
  const where: Prisma.VehicleWhereInput = {
    ...(q ? { OR: [{ number: { contains: q, mode: 'insensitive' } }, { make: { contains: q, mode: 'insensitive' } }, { model: { contains: q, mode: 'insensitive' } }, { driver: { user: { fullName: { contains: q, mode: 'insensitive' } } } }] } : {}),
    ...(status ? { status: status.toUpperCase() as any } : {}), ...(type ? { type: type.toUpperCase() as any } : {}), ...(driverId ? { driverId } : {}),
    ...(platform ? { platform: { OR: [{ id: platform }, { code: platform.toUpperCase() }, { name: { equals: platform, mode: 'insensitive' } }] } } : {}),
  };
  if (complianceF) {
    const all = await prisma.vehicle.findMany({ where, include, orderBy: { number: 'asc' } });
    const filtered = all.map(shapeVehicle).filter((v) => v.compliance.level === complianceF.toUpperCase());
    return res.json({ success: true, data: paged(filtered.slice(p.skip, p.skip + p.take), filtered.length, p) });
  }
  const [items, total] = await Promise.all([prisma.vehicle.findMany({ where, include, orderBy: { number: 'asc' }, skip: p.skip, take: p.take }), prisma.vehicle.count({ where })]);
  res.json({ success: true, data: paged(items.map(shapeVehicle), total, p) });
}));

const vehicleSchema = z.object({
  number: z.string().min(4), make: z.string().min(1), model: z.string().min(1), year: z.coerce.number().int().min(1990).max(2100), type: z.enum(VEHICLE_TYPES),
  color: z.string().optional(), fuelType: z.enum(['PETROL', 'DIESEL', 'CNG', 'ELECTRIC', 'HYBRID']).optional(), seatingCapacity: z.string().optional(),
  status: z.enum(['ACTIVE', 'INACTIVE', 'UNDER_REVIEW', 'BLACKLISTED']).optional(), driverId: z.string().nullable().optional(), supervisorId: z.string().nullable().optional(), platformId: z.string().nullable().optional(),
  registrationDate: z.string().optional(), permitValidTill: z.string().optional(), insuranceValidTill: z.string().optional(), pucValidTill: z.string().optional(), fitnessValidTill: z.string().optional(),
  currentLocation: z.string().optional(), latitude: z.number().optional(), longitude: z.number().optional(),
});
const toDate = (s?: string) => (s ? new Date(s) : undefined);

vehiclesRouter.post('/', asyncHandler(async (req, res) => {
  const b = parse(vehicleSchema, req.body);
  const v = await prisma.vehicle.create({ data: { ...b, number: b.number.toUpperCase().replace(/\s+/g, ''), status: b.status ?? 'ACTIVE', registrationDate: toDate(b.registrationDate), permitValidTill: toDate(b.permitValidTill), insuranceValidTill: toDate(b.insuranceValidTill), pucValidTill: toDate(b.pucValidTill), fitnessValidTill: toDate(b.fitnessValidTill) }, include });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'VEHICLE', entityId: v.id, action: 'CREATED', details: `Added vehicle ${v.number}` });
  res.status(201).json({ success: true, data: shapeVehicle(v) });
}));

vehiclesRouter.post('/bulk', upload.single('file'), asyncHandler(async (req, res) => {
  let rows: Record<string, string>[] = [];
  if (req.file) rows = parseCsv(req.file.buffer.toString('utf8'), { columns: true, skip_empty_lines: true, trim: true });
  else if (Array.isArray(req.body?.rows)) rows = req.body.rows;
  else throw badRequest('Provide a CSV file (field "file") or JSON { rows: [...] }');
  const results: { number: string; ok: boolean; error?: string }[] = [];
  for (const r of rows) {
    try {
      const b = parse(vehicleSchema, { ...r, year: Number(r.year), type: String(r.type ?? 'SEDAN').toUpperCase().replace(' ', '_') });
      await prisma.vehicle.upsert({ where: { number: b.number.toUpperCase() }, update: { make: b.make, model: b.model, year: b.year, type: b.type, color: b.color, fuelType: b.fuelType }, create: { ...b, number: b.number.toUpperCase(), status: b.status ?? 'UNDER_REVIEW', registrationDate: toDate(b.registrationDate), permitValidTill: toDate(b.permitValidTill), insuranceValidTill: toDate(b.insuranceValidTill), pucValidTill: toDate(b.pucValidTill), fitnessValidTill: toDate(b.fitnessValidTill) } });
      results.push({ number: b.number, ok: true });
    } catch (e) { results.push({ number: String(r.number ?? '?'), ok: false, error: e instanceof Error ? e.message : 'invalid row' }); }
  }
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'VEHICLE', action: 'BULK_UPLOAD', details: `${results.filter((r) => r.ok).length}/${results.length} vehicles imported` });
  res.json({ success: true, data: { imported: results.filter((r) => r.ok).length, failed: results.filter((r) => !r.ok).length, results } });
}));

vehiclesRouter.get('/:id', asyncHandler(async (req, res) => {
  const v = await prisma.vehicle.findFirst({ where: { OR: [{ id: req.params.id }, { number: req.params.id.toUpperCase() }] }, include });
  if (!v) throw notFound('Vehicle not found');
  const [trips, activities] = await Promise.all([
    prisma.trip.findMany({ where: { vehicleId: v.id }, orderBy: { scheduledStart: 'desc' }, take: 20, include: { driver: { include: { user: true } }, platform: true, client: true } }),
    prisma.activityLog.findMany({ where: { entityType: 'VEHICLE', entityId: v.id }, orderBy: { createdAt: 'desc' }, take: 20 }),
  ]);
  res.json({ success: true, data: { ...shapeVehicle(v), trips: trips.map((t) => ({ ...t, driverName: t.driver.user.fullName })), activities } });
}));

vehiclesRouter.put('/:id', asyncHandler(async (req, res) => {
  const b = parse(vehicleSchema.partial(), req.body);
  const v = await prisma.vehicle.update({ where: { id: req.params.id }, data: { ...b, number: b.number?.toUpperCase(), registrationDate: toDate(b.registrationDate), permitValidTill: toDate(b.permitValidTill), insuranceValidTill: toDate(b.insuranceValidTill), pucValidTill: toDate(b.pucValidTill), fitnessValidTill: toDate(b.fitnessValidTill) }, include });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'VEHICLE', entityId: v.id, action: 'UPDATED', details: `Vehicle ${v.number} updated` });
  res.json({ success: true, data: shapeVehicle(v) });
}));

vehiclesRouter.patch('/:id/status', asyncHandler(async (req, res) => {
  const b = parse(z.object({ status: z.enum(['ACTIVE', 'INACTIVE', 'UNDER_REVIEW', 'BLACKLISTED']), reason: z.string().optional() }), req.body);
  const v = await prisma.vehicle.update({ where: { id: req.params.id }, data: { status: b.status, blacklistReason: b.status === 'BLACKLISTED' ? b.reason ?? 'Blacklisted by admin' : null }, include });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'VEHICLE', entityId: v.id, action: 'STATUS_CHANGED', details: `Status set to ${b.status}` });
  res.json({ success: true, data: shapeVehicle(v) });
}));

vehiclesRouter.post('/:id/photos', upload.array('photos', 6), asyncHandler(async (req, res) => {
  const files = (req.files as Express.Multer.File[]) ?? [];
  if (!files.length) throw badRequest('No photos uploaded');
  const v = await prisma.vehicle.findUnique({ where: { id: req.params.id } });
  if (!v) throw notFound('Vehicle not found');
  for (const f of files) { const s = await storeFile(`vehicles/${v.id}`, f); await prisma.vehiclePhoto.create({ data: { vehicleId: v.id, url: s.url, caption: f.originalname } }); }
  const out = await prisma.vehicle.findUniqueOrThrow({ where: { id: v.id }, include });
  res.status(201).json({ success: true, data: shapeVehicle(out) });
}));

vehiclesRouter.post('/:id/documents', upload.single('file'), asyncHandler(async (req, res) => {
  const b = parse(z.object({ type: z.enum(['RC', 'PERMIT', 'INSURANCE', 'PUC', 'FITNESS', 'VEHICLE_PHOTO_1', 'VEHICLE_PHOTO_2', 'OTHER']), validTill: z.string().optional(), status: z.enum(['PENDING', 'VERIFIED']).optional() }), req.body);
  if (!req.file) throw badRequest('file is required');
  const v = await prisma.vehicle.findUnique({ where: { id: req.params.id } });
  if (!v) throw notFound('Vehicle not found');
  const s = await storeFile(`vehicles/${v.id}/docs`, req.file);
  const existing = await prisma.document.findFirst({ where: { vehicleId: v.id, type: b.type } });
  const data = { fileUrl: s.url, fileName: s.fileName, mimeType: s.mimeType, validTill: toDate(b.validTill), status: b.status ?? 'VERIFIED', verifiedAt: (b.status ?? 'VERIFIED') === 'VERIFIED' ? new Date() : null, verifiedById: req.user!.adminId };
  const doc = existing ? await prisma.document.update({ where: { id: existing.id }, data }) : await prisma.document.create({ data: { ...data, vehicleId: v.id, type: b.type } });
  res.status(201).json({ success: true, data: doc });
}));

vehiclesRouter.patch('/:id/documents/:docId', asyncHandler(async (req, res) => {
  const b = parse(z.object({ status: z.enum(['PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED']), remarks: z.string().optional(), validTill: z.string().optional() }), req.body);
  const doc = await prisma.document.update({ where: { id: req.params.docId }, data: { status: b.status, remarks: b.remarks, validTill: toDate(b.validTill), verifiedAt: b.status === 'VERIFIED' ? new Date() : null, verifiedById: b.status === 'VERIFIED' ? req.user!.adminId : null } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'VEHICLE', entityId: req.params.id, action: 'DOCUMENT_' + b.status, details: `${doc.type} marked ${b.status}` });
  res.json({ success: true, data: doc });
}));

vehiclesRouter.delete('/:id/photos/:photoId', asyncHandler(async (req, res) => {
  await prisma.vehiclePhoto.delete({ where: { id: req.params.photoId } });
  res.json({ success: true });
}));

vehiclesRouter.delete('/:id', asyncHandler(async (req, res) => {
  await prisma.vehicle.delete({ where: { id: req.params.id } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'VEHICLE', entityId: req.params.id, action: 'DELETED' });
  res.json({ success: true });
}));
