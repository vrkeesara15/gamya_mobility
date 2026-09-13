import { Router } from 'express';
import dayjs from 'dayjs';
import { z } from 'zod';
import type { Prisma, ApprovalType } from '@prisma/client';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { parse } from '../utils/validate.js';
import { badRequest, notFound } from '../utils/errors.js';
import { pageParams, paged, str } from '../utils/pagination.js';
import { logActivity } from '../utils/activity.js';
import { notifyUser } from '../services/notifications.js';
import { requireAdmin } from '../middleware/auth.js';

export const approvalsRouter = Router();
approvalsRouter.use(requireAdmin);

const include = {
  driver: { include: { user: true, documents: true, vehicles: { include: { photos: true, documents: true } } } },
  vehicle: { include: { photos: true, documents: true, driver: { include: { user: true } } } },
  supervisor: { include: { user: true, client: true, locations: true } },
  document: true, reviewedBy: { include: { user: true } },
} satisfies Prisma.ApprovalRequestInclude;

const TYPE_LABEL: Record<string, string> = { DRIVER_REGISTRATION: 'Driver Registration', VEHICLE_REGISTRATION: 'Vehicle Registration', DOCUMENT_UPLOAD: 'Document Upload', DOCUMENT_RENEWAL: 'Document Renewal', SUPERVISOR_REGISTRATION: 'Supervisor Registration' };

export function shapeApproval(a: Prisma.ApprovalRequestGetPayload<{ include: typeof include }>) {
  const subjectName = a.driver?.user.fullName ?? a.supervisor?.user.fullName ?? a.vehicle?.driver?.user.fullName ?? null;
  const vehicle = a.vehicle ?? a.driver?.vehicles[0] ?? null;
  return {
    id: a.id, type: a.type, typeLabel: TYPE_LABEL[a.type], status: a.status, details: a.details, submittedAt: a.submittedAt, reviewedAt: a.reviewedAt, remarks: a.remarks,
    reviewedBy: a.reviewedBy?.user.fullName ?? null, ageDays: dayjs().diff(a.submittedAt, 'day'),
    subjectName, subjectMobile: a.driver?.user.mobile ?? a.supervisor?.user.mobile ?? a.vehicle?.driver?.user.mobile ?? null,
    subjectPhoto: a.driver?.user.avatarUrl ?? a.driver?.selfieUrl ?? a.supervisor?.user.avatarUrl ?? a.supervisor?.selfieUrl ?? vehicle?.photos[0]?.url ?? null,
    vehicleNumber: vehicle?.number ?? null, vehicleLabel: vehicle ? `${vehicle.make} ${vehicle.model}` : null,
    driver: a.driver ? { id: a.driver.id, code: a.driver.code, fullName: a.driver.user.fullName, mobile: a.driver.user.mobile, email: a.driver.user.email, dateOfBirth: a.driver.dateOfBirth, address: a.driver.address, selfieUrl: a.driver.selfieUrl, idPhotoUrl: a.driver.idPhotoUrl, faceVerified: a.driver.faceVerified, faceMatchScore: a.driver.faceMatchScore, registeredAt: a.driver.createdAt, documents: [...a.driver.documents, ...(a.driver.vehicles[0]?.documents ?? [])], vehicle: a.driver.vehicles[0] ? { id: a.driver.vehicles[0].id, number: a.driver.vehicles[0].number, make: a.driver.vehicles[0].make, model: a.driver.vehicles[0].model, year: a.driver.vehicles[0].year, type: a.driver.vehicles[0].type, photos: a.driver.vehicles[0].photos.map((p) => p.url) } : null } : null,
    supervisor: a.supervisor ? { id: a.supervisor.id, code: a.supervisor.code, fullName: a.supervisor.user.fullName, mobile: a.supervisor.user.mobile, email: a.supervisor.user.email, companyName: a.supervisor.companyName, employeeId: a.supervisor.employeeId, selfieUrl: a.supervisor.selfieUrl, faceVerified: a.supervisor.faceVerified, faceMatchScore: a.supervisor.faceMatchScore, registeredAt: a.supervisor.createdAt } : null,
    vehicle: a.vehicle ? { id: a.vehicle.id, number: a.vehicle.number, make: a.vehicle.make, model: a.vehicle.model, year: a.vehicle.year, type: a.vehicle.type, photos: a.vehicle.photos.map((p) => p.url), documents: a.vehicle.documents, driverName: a.vehicle.driver?.user.fullName ?? null } : null,
    document: a.document,
  };
}

approvalsRouter.get('/stats', asyncHandler(async (_req, res) => {
  const pending = (type: ApprovalType[]) => prisma.approvalRequest.count({ where: { status: 'PENDING', type: { in: type } } });
  const [drivers, vehicles, documents, supervisors, total] = await Promise.all([
    pending(['DRIVER_REGISTRATION']), pending(['VEHICLE_REGISTRATION']), pending(['DOCUMENT_UPLOAD', 'DOCUMENT_RENEWAL']), pending(['SUPERVISOR_REGISTRATION']), prisma.approvalRequest.count({ where: { status: 'PENDING' } }),
  ]);
  const byType = await prisma.approvalRequest.groupBy({ by: ['type'], _count: { _all: true }, where: { status: 'PENDING' } });
  res.json({ success: true, data: { drivers, vehicles, documents, supervisors, total, byType: byType.map((g) => ({ type: g.type, label: TYPE_LABEL[g.type], count: g._count._all })) } });
}));

approvalsRouter.get('/trend', asyncHandler(async (req, res) => {
  const days = Math.min(90, Number(req.query.days ?? 30) || 30);
  const since = dayjs().subtract(days, 'day').startOf('day').toDate();
  const rows = await prisma.approvalRequest.findMany({ where: { reviewedAt: { gte: since } }, select: { reviewedAt: true, status: true } });
  const buckets: Record<string, { date: string; approved: number; rejected: number }> = {};
  for (let i = 0; i <= days; i++) { const d = dayjs(since).add(i, 'day').format('YYYY-MM-DD'); buckets[d] = { date: d, approved: 0, rejected: 0 }; }
  for (const r of rows) { const d = dayjs(r.reviewedAt!).format('YYYY-MM-DD'); if (!buckets[d]) continue; if (r.status === 'APPROVED') buckets[d].approved++; else if (r.status === 'REJECTED') buckets[d].rejected++; }
  res.json({ success: true, data: Object.values(buckets) });
}));

approvalsRouter.get('/oldest', asyncHandler(async (_req, res) => {
  const items = await prisma.approvalRequest.findMany({ where: { status: 'PENDING' }, include, orderBy: { submittedAt: 'asc' }, take: 5 });
  res.json({ success: true, data: items.map(shapeApproval) });
}));

approvalsRouter.get('/', asyncHandler(async (req, res) => {
  const p = pageParams(req);
  const q = str(req.query.q); const status = str(req.query.status); const type = str(req.query.type); const category = str(req.query.category); const sort = str(req.query.sort) ?? 'oldest';
  const categoryTypes: Record<string, ApprovalType[]> = { drivers: ['DRIVER_REGISTRATION'], vehicles: ['VEHICLE_REGISTRATION'], documents: ['DOCUMENT_UPLOAD', 'DOCUMENT_RENEWAL'], supervisors: ['SUPERVISOR_REGISTRATION'] };
  const where: Prisma.ApprovalRequestWhereInput = {
    ...(status ? { status: status.toUpperCase() as any } : {}),
    ...(type ? { type: type.toUpperCase() as any } : category && categoryTypes[category.toLowerCase()] ? { type: { in: categoryTypes[category.toLowerCase()] } } : {}),
    ...(q ? { OR: [{ driver: { user: { fullName: { contains: q, mode: 'insensitive' } } } }, { driver: { user: { mobile: { contains: q } } } }, { supervisor: { user: { fullName: { contains: q, mode: 'insensitive' } } } }, { vehicle: { number: { contains: q, mode: 'insensitive' } } }, { details: { contains: q, mode: 'insensitive' } }] } : {}),
  };
  const [items, total] = await Promise.all([
    prisma.approvalRequest.findMany({ where, include, orderBy: { submittedAt: sort === 'newest' ? 'desc' : 'asc' }, skip: p.skip, take: p.take }),
    prisma.approvalRequest.count({ where }),
  ]);
  res.json({ success: true, data: paged(items.map(shapeApproval), total, p) });
}));

approvalsRouter.get('/:id', asyncHandler(async (req, res) => {
  const a = await prisma.approvalRequest.findUnique({ where: { id: req.params.id }, include });
  if (!a) throw notFound('Approval request not found');
  const entityId = a.driverId ?? a.supervisorId ?? a.vehicleId ?? a.id;
  const activities = await prisma.activityLog.findMany({ where: { entityId }, orderBy: { createdAt: 'desc' }, take: 20 });
  res.json({ success: true, data: { ...shapeApproval(a), activities } });
}));

async function decide(id: string, decision: 'APPROVED' | 'REJECTED', remarks: string | undefined, actor: { id: string; fullName: string; adminId?: string }) {
  const a = await prisma.approvalRequest.findUnique({ where: { id }, include });
  if (!a) throw notFound('Approval request not found');
  if (a.status !== 'PENDING') throw badRequest(`Request already ${a.status.toLowerCase()}`);
  const now = new Date();
  await prisma.approvalRequest.update({ where: { id }, data: { status: decision, reviewedAt: now, reviewedById: actor.adminId, remarks } });
  const approved = decision === 'APPROVED';
  let notifyUserId: string | null = null; let title = ''; let body = '';
  if (a.type === 'DRIVER_REGISTRATION' && a.driver) {
    await prisma.driver.update({ where: { id: a.driver.id }, data: { approvedAt: approved ? now : null, approvedById: actor.adminId, joiningDate: approved ? a.driver.joiningDate ?? now : undefined, reVerificationDue: approved ? dayjs().add(12, 'month').toDate() : undefined, user: { update: { status: approved ? 'ACTIVE' : 'REJECTED' } } } });
    if (approved) {
      await prisma.document.updateMany({ where: { OR: [{ driverId: a.driver.id }, { vehicleId: { in: a.driver.vehicles.map((v) => v.id) } }], status: 'PENDING' }, data: { status: 'VERIFIED', verifiedAt: now, verifiedById: actor.adminId } });
      await prisma.vehicle.updateMany({ where: { driverId: a.driver.id, status: 'UNDER_REVIEW' }, data: { status: 'ACTIVE' } });
    }
    notifyUserId = a.driver.userId; title = approved ? 'Congratulations! Account approved' : 'Registration rejected';
    body = approved ? 'Your account has been approved. You can now receive and accept ad-hoc trip requests.' : `Your registration was rejected.${remarks ? ` Reason: ${remarks}` : ''}`;
  } else if (a.type === 'SUPERVISOR_REGISTRATION' && a.supervisor) {
    await prisma.supervisor.update({ where: { id: a.supervisor.id }, data: { approvedAt: approved ? now : null, approvedById: actor.adminId, dateOfJoining: approved ? a.supervisor.dateOfJoining ?? now : undefined, user: { update: { status: approved ? 'ACTIVE' : 'REJECTED' } } } });
    notifyUserId = a.supervisor.userId; title = approved ? 'Account approved' : 'Registration rejected';
    body = approved ? 'Your supervisor account has been approved by the vendor owner. You can now post requirements.' : `Your registration was rejected.${remarks ? ` Reason: ${remarks}` : ''}`;
  } else if (a.type === 'VEHICLE_REGISTRATION' && a.vehicle) {
    await prisma.vehicle.update({ where: { id: a.vehicle.id }, data: { status: approved ? 'ACTIVE' : 'INACTIVE' } });
    if (approved) await prisma.document.updateMany({ where: { vehicleId: a.vehicle.id, status: 'PENDING' }, data: { status: 'VERIFIED', verifiedAt: now, verifiedById: actor.adminId } });
    notifyUserId = a.vehicle.driver?.userId ?? null; title = approved ? 'Vehicle approved' : 'Vehicle rejected'; body = `Vehicle ${a.vehicle.number} was ${approved ? 'approved' : 'rejected'}.${remarks ? ` ${remarks}` : ''}`;
  } else if ((a.type === 'DOCUMENT_UPLOAD' || a.type === 'DOCUMENT_RENEWAL') && a.document) {
    await prisma.document.update({ where: { id: a.document.id }, data: { status: approved ? 'VERIFIED' : 'REJECTED', verifiedAt: approved ? now : null, verifiedById: actor.adminId, remarks } });
    const drv = a.document.driverId ? await prisma.driver.findUnique({ where: { id: a.document.driverId } }) : a.document.vehicleId ? (await prisma.vehicle.findUnique({ where: { id: a.document.vehicleId }, include: { driver: true } }))?.driver : null;
    notifyUserId = drv?.userId ?? null; title = approved ? 'Document verified' : 'Document rejected'; body = `${a.document.type.replace(/_/g, ' ')} was ${approved ? 'verified' : 'rejected'}.${remarks ? ` ${remarks}` : ''}`;
  }
  if (notifyUserId) await notifyUser(notifyUserId, { type: 'APPROVAL', title, body, data: { approvalId: a.id, decision } });
  await logActivity({ actorId: actor.id, actorName: actor.fullName, entityType: a.type.startsWith('DRIVER') ? 'DRIVER' : a.type.startsWith('SUPERVISOR') ? 'SUPERVISOR' : a.type.startsWith('VEHICLE') ? 'VEHICLE' : 'DOCUMENT', entityId: a.driverId ?? a.supervisorId ?? a.vehicleId ?? a.documentId, action: decision, details: `${TYPE_LABEL[a.type]} ${decision.toLowerCase()}${remarks ? ` – ${remarks}` : ''}` });
  return prisma.approvalRequest.findUniqueOrThrow({ where: { id }, include });
}

const decideSchema = z.object({ remarks: z.string().optional() });
approvalsRouter.post('/:id/approve', asyncHandler(async (req, res) => { const b = parse(decideSchema, req.body ?? {}); res.json({ success: true, data: shapeApproval(await decide(req.params.id, 'APPROVED', b.remarks, req.user!)) }); }));
approvalsRouter.post('/:id/reject', asyncHandler(async (req, res) => { const b = parse(decideSchema, req.body ?? {}); res.json({ success: true, data: shapeApproval(await decide(req.params.id, 'REJECTED', b.remarks, req.user!)) }); }));
approvalsRouter.post('/bulk', asyncHandler(async (req, res) => {
  const b = parse(z.object({ ids: z.array(z.string()).min(1), decision: z.enum(['APPROVED', 'REJECTED']), remarks: z.string().optional() }), req.body);
  const out: { id: string; ok: boolean; error?: string }[] = [];
  for (const id of b.ids) { try { await decide(id, b.decision, b.remarks, req.user!); out.push({ id, ok: true }); } catch (e) { out.push({ id, ok: false, error: e instanceof Error ? e.message : 'failed' }); } }
  res.json({ success: true, data: out });
}));
