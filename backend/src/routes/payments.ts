import { Router } from 'express';
import dayjs from 'dayjs';
import { z } from 'zod';
import type { Prisma } from '@prisma/client';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { parse } from '../utils/validate.js';
import { badRequest, notFound } from '../utils/errors.js';
import { pageParams, paged, str } from '../utils/pagination.js';
import { nextInvoiceCode, nextSettlementCode } from '../utils/codes.js';
import { logActivity } from '../utils/activity.js';
import { notifyUser } from '../services/notifications.js';
import { requireAdmin } from '../middleware/auth.js';

export const paymentsRouter = Router();
paymentsRouter.use(requireAdmin);

paymentsRouter.get('/stats', asyncHandler(async (_req, res) => {
  const monthStart = dayjs().startOf('month').toDate();
  const [pendingEarn, settledEarn, pendingSettle, paidSettle, monthEarn, invoicesDue, invoicesPaid] = await Promise.all([
    prisma.earning.aggregate({ _sum: { amount: true }, _count: { _all: true }, where: { status: 'PENDING' } }), prisma.earning.aggregate({ _sum: { amount: true }, _count: { _all: true }, where: { status: 'SETTLED' } }),
    prisma.settlement.aggregate({ _sum: { totalAmount: true }, _count: { _all: true }, where: { status: 'PENDING' } }), prisma.settlement.aggregate({ _sum: { totalAmount: true }, _count: { _all: true }, where: { status: 'PAID' } }),
    prisma.earning.aggregate({ _sum: { amount: true }, where: { date: { gte: monthStart } } }),
    prisma.invoice.aggregate({ _sum: { amount: true }, _count: { _all: true }, where: { status: { in: ['SENT', 'OVERDUE'] } } }), prisma.invoice.aggregate({ _sum: { amount: true }, _count: { _all: true }, where: { status: 'PAID' } }),
  ]);
  res.json({ success: true, data: {
    pendingEarnings: Number(pendingEarn._sum.amount ?? 0), pendingEarningsCount: pendingEarn._count._all, settledEarnings: Number(settledEarn._sum.amount ?? 0), settledEarningsCount: settledEarn._count._all,
    pendingSettlements: Number(pendingSettle._sum.totalAmount ?? 0), pendingSettlementsCount: pendingSettle._count._all, paidSettlements: Number(paidSettle._sum.totalAmount ?? 0), paidSettlementsCount: paidSettle._count._all,
    monthEarnings: Number(monthEarn._sum.amount ?? 0), invoicesDue: Number(invoicesDue._sum.amount ?? 0), invoicesDueCount: invoicesDue._count._all, invoicesPaid: Number(invoicesPaid._sum.amount ?? 0), invoicesPaidCount: invoicesPaid._count._all,
  } });
}));

paymentsRouter.get('/earnings', asyncHandler(async (req, res) => {
  const p = pageParams(req, 20); const driverId = str(req.query.driverId); const status = str(req.query.status); const from = str(req.query.from); const to = str(req.query.to);
  const where: Prisma.EarningWhereInput = { ...(driverId ? { driverId } : {}), ...(status ? { status: status.toUpperCase() as any } : {}), ...(from || to ? { date: { ...(from ? { gte: dayjs(from).startOf('day').toDate() } : {}), ...(to ? { lte: dayjs(to).endOf('day').toDate() } : {}) } } : {}) };
  const [items, total] = await Promise.all([prisma.earning.findMany({ where, include: { driver: { include: { user: true } }, trip: { include: { platform: true, vehicle: true } }, settlement: true }, orderBy: { date: 'desc' }, skip: p.skip, take: p.take }), prisma.earning.count({ where })]);
  res.json({ success: true, data: paged(items.map((e) => ({ id: e.id, amount: Number(e.amount), date: e.date, status: e.status, driver: { id: e.driver.id, code: e.driver.code, fullName: e.driver.user.fullName }, trip: e.trip ? { id: e.trip.id, code: e.trip.code, fromLocation: e.trip.fromLocation, toLocation: e.trip.toLocation, platform: e.trip.platform?.name ?? null, vehicleNumber: e.trip.vehicle.number } : null, settlementCode: e.settlement?.code ?? null })), total, p) });
}));

/** Per-driver summary of unsettled earnings (for the settlement screen). */
paymentsRouter.get('/driver-summary', asyncHandler(async (_req, res) => {
  const groups = await prisma.earning.groupBy({ by: ['driverId'], _sum: { amount: true }, _count: { _all: true }, where: { status: 'PENDING' } });
  const drivers = await prisma.driver.findMany({ where: { id: { in: groups.map((g) => g.driverId) } }, include: { user: true } });
  res.json({ success: true, data: groups.map((g) => { const d = drivers.find((x) => x.id === g.driverId); return { driverId: g.driverId, code: d?.code, fullName: d?.user.fullName, mobile: d?.user.mobile, avatarUrl: d?.user.avatarUrl, trips: g._count._all, pendingAmount: Number(g._sum.amount ?? 0) }; }).sort((a, b) => b.pendingAmount - a.pendingAmount) });
}));

paymentsRouter.get('/settlements', asyncHandler(async (req, res) => {
  const p = pageParams(req, 20); const status = str(req.query.status); const driverId = str(req.query.driverId);
  const where: Prisma.SettlementWhereInput = { ...(status ? { status: status.toUpperCase() as any } : {}), ...(driverId ? { driverId } : {}) };
  const [items, total] = await Promise.all([prisma.settlement.findMany({ where, include: { driver: { include: { user: true } }, _count: { select: { earnings: true } } }, orderBy: { createdAt: 'desc' }, skip: p.skip, take: p.take }), prisma.settlement.count({ where })]);
  res.json({ success: true, data: paged(items.map((s) => ({ id: s.id, code: s.code, status: s.status, totalAmount: Number(s.totalAmount), periodStart: s.periodStart, periodEnd: s.periodEnd, paidAt: s.paidAt, reference: s.reference, trips: s._count.earnings, driver: { id: s.driver.id, code: s.driver.code, fullName: s.driver.user.fullName, mobile: s.driver.user.mobile }, createdAt: s.createdAt })), total, p) });
}));

paymentsRouter.post('/settlements', asyncHandler(async (req, res) => {
  const b = parse(z.object({ driverId: z.string(), periodStart: z.string().optional(), periodEnd: z.string().optional() }), req.body);
  const start = b.periodStart ? dayjs(b.periodStart).startOf('day').toDate() : dayjs(0).toDate(); const end = b.periodEnd ? dayjs(b.periodEnd).endOf('day').toDate() : new Date();
  const earnings = await prisma.earning.findMany({ where: { driverId: b.driverId, status: 'PENDING', date: { gte: start, lte: end } } });
  if (!earnings.length) throw badRequest('No pending earnings for this driver in the period');
  const total = earnings.reduce((s, e) => s + Number(e.amount), 0);
  const s = await prisma.settlement.create({ data: { code: await nextSettlementCode(), driverId: b.driverId, periodStart: earnings.reduce((m, e) => (e.date < m ? e.date : m), earnings[0].date), periodEnd: end, totalAmount: total, earnings: { connect: earnings.map((e) => ({ id: e.id })) } } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'SETTLEMENT', entityId: s.id, action: 'CREATED', details: `${s.code} ₹${total} (${earnings.length} trips)` });
  res.status(201).json({ success: true, data: s });
}));

paymentsRouter.post('/settlements/:id/pay', asyncHandler(async (req, res) => {
  const b = parse(z.object({ reference: z.string().optional() }), req.body ?? {});
  const s = await prisma.settlement.findUnique({ where: { id: req.params.id }, include: { driver: true } });
  if (!s) throw notFound('Settlement not found');
  if (s.status === 'PAID') throw badRequest('Already paid');
  await prisma.$transaction([
    prisma.settlement.update({ where: { id: s.id }, data: { status: 'PAID', paidAt: new Date(), reference: b.reference } }),
    prisma.earning.updateMany({ where: { settlementId: s.id }, data: { status: 'SETTLED' } }),
  ]);
  await notifyUser(s.driver.userId, { type: 'PAYMENT', title: 'Payment settled', body: `₹${Number(s.totalAmount)} has been paid for settlement ${s.code}.${b.reference ? ` Ref: ${b.reference}` : ''}` });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: 'SETTLEMENT', entityId: s.id, action: 'PAID', details: `${s.code} paid` });
  res.json({ success: true });
}));

paymentsRouter.get('/invoices', asyncHandler(async (req, res) => {
  const p = pageParams(req, 20); const status = str(req.query.status);
  const where: Prisma.InvoiceWhereInput = status ? { status: status.toUpperCase() as any } : {};
  const [items, total] = await Promise.all([prisma.invoice.findMany({ where, include: { client: true }, orderBy: { createdAt: 'desc' }, skip: p.skip, take: p.take }), prisma.invoice.count({ where })]);
  res.json({ success: true, data: paged(items.map((i) => ({ ...i, amount: Number(i.amount), clientName: i.client.name })), total, p) });
}));

paymentsRouter.post('/invoices', asyncHandler(async (req, res) => {
  const b = parse(z.object({ clientId: z.string(), periodStart: z.string(), periodEnd: z.string(), dueDate: z.string().optional() }), req.body);
  const start = dayjs(b.periodStart).startOf('day').toDate(); const end = dayjs(b.periodEnd).endOf('day').toDate();
  const trips = await prisma.trip.findMany({ where: { clientId: b.clientId, status: 'COMPLETED', completedAt: { gte: start, lte: end } } });
  const amount = trips.reduce((s, t) => s + Number(t.amount ?? 0), 0);
  const inv = await prisma.invoice.create({ data: { code: await nextInvoiceCode(), clientId: b.clientId, periodStart: start, periodEnd: end, tripCount: trips.length, amount, status: 'DRAFT', dueDate: b.dueDate ? new Date(b.dueDate) : dayjs(end).add(15, 'day').toDate() }, include: { client: true } });
  res.status(201).json({ success: true, data: { ...inv, amount: Number(inv.amount), clientName: inv.client.name } });
}));

paymentsRouter.patch('/invoices/:id', asyncHandler(async (req, res) => {
  const b = parse(z.object({ status: z.enum(['DRAFT', 'SENT', 'PAID', 'OVERDUE']) }), req.body);
  const inv = await prisma.invoice.update({ where: { id: req.params.id }, data: { status: b.status, paidAt: b.status === 'PAID' ? new Date() : null } });
  res.json({ success: true, data: { ...inv, amount: Number(inv.amount) } });
}));
