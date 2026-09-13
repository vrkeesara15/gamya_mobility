import { Router } from 'express';
import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';
import dayjs from 'dayjs';
import { z } from 'zod';
import { prisma } from '../config/prisma.js';
import { asyncHandler } from '../utils/async.js';
import { parse } from '../utils/validate.js';
import { badRequest, conflict, forbidden, notFound, unauthorized } from '../utils/errors.js';
import { authenticate, loadUser, signToken } from '../middleware/auth.js';
import { nextDriverCode, nextSupervisorCode } from '../utils/codes.js';
import { upload, storeFile } from '../services/storage.js';
import { verifyFace } from '../services/face.js';
import { notifyAdmins } from '../services/notifications.js';
import { logActivity } from '../utils/activity.js';

export const authRouter = Router();

const mobileRx = /^[6-9]\d{9}$/;

const loginSchema = z.object({
  identifier: z.string().min(3), // email or mobile
  password: z.string().min(1),
  role: z.enum(['ADMIN', 'SUPERVISOR', 'DRIVER']).optional(),
  fcmToken: z.string().optional(),
});

authRouter.post('/login', asyncHandler(async (req, res) => {
  const body = parse(loginSchema, req.body);
  const id = body.identifier.trim().toLowerCase();
  const user = await prisma.user.findFirst({
    where: { OR: [{ email: id }, { mobile: body.identifier.trim() }], ...(body.role ? { role: body.role } : {}) },
    include: { admin: true, supervisor: { include: { client: true, locations: true } }, driver: true },
  });
  if (!user || !(await bcrypt.compare(body.password, user.passwordHash))) throw unauthorized('Invalid credentials');
  if (user.status === 'BLACKLISTED' || user.status === 'REJECTED') throw forbidden(`Account ${user.status.toLowerCase()}`);
  if (user.status === 'INACTIVE') throw forbidden('Account inactive. Contact Gamya Mobility admin.');
  await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date(), ...(body.fcmToken ? { fcmToken: body.fcmToken } : {}) } });
  await logActivity({ actorId: user.id, actorName: user.fullName, entityType: user.role, entityId: user.id, action: 'LOGIN', details: 'Login to app' });
  res.json({ success: true, data: { token: signToken(user), user: publicUser(user) } });
}));

export function publicUser(u: any) {
  return {
    id: u.id, role: u.role, fullName: u.fullName, email: u.email, mobile: u.mobile, avatarUrl: u.avatarUrl, status: u.status, lastLoginAt: u.lastLoginAt,
    admin: u.admin ? { id: u.admin.id, adminRole: u.admin.adminRole, designation: u.admin.designation } : undefined,
    supervisor: u.supervisor ? {
      id: u.supervisor.id, code: u.supervisor.code, employeeId: u.supervisor.employeeId, companyName: u.supervisor.companyName,
      clientId: u.supervisor.clientId, faceVerified: u.supervisor.faceVerified, approvedAt: u.supervisor.approvedAt,
      locations: u.supervisor.locations?.map((l: any) => l.name) ?? [],
    } : undefined,
    driver: u.driver ? {
      id: u.driver.id, code: u.driver.code, faceVerified: u.driver.faceVerified, approvedAt: u.driver.approvedAt, selfieUrl: u.driver.selfieUrl,
      dateOfBirth: u.driver.dateOfBirth, address: u.driver.address, rating: u.driver.rating,
    } : undefined,
  };
}

const registerSupervisor = z.object({
  fullName: z.string().min(2),
  companyName: z.string().min(2),
  employeeId: z.string().min(1),
  mobile: z.string().regex(mobileRx, 'Invalid Indian mobile number'),
  email: z.string().email(),
  password: z.string().min(6),
  acceptTerms: z.literal(true).or(z.boolean()).optional(),
  fcmToken: z.string().optional(),
});

authRouter.post('/register/supervisor', asyncHandler(async (req, res) => {
  const b = parse(registerSupervisor, req.body);
  const email = b.email.toLowerCase();
  if (await prisma.user.findFirst({ where: { OR: [{ email }, { mobile: b.mobile }] } })) throw conflict('Email or mobile already registered');
  const client = await prisma.client.upsert({ where: { name: b.companyName }, update: {}, create: { name: b.companyName } });
  const user = await prisma.user.create({
    data: {
      role: 'SUPERVISOR', fullName: b.fullName, email, mobile: b.mobile, passwordHash: await bcrypt.hash(b.password, 10), status: 'PENDING', fcmToken: b.fcmToken,
      supervisor: { create: { code: await nextSupervisorCode(), employeeId: b.employeeId, companyName: b.companyName, clientId: client.id } },
    },
    include: { supervisor: true },
  });
  await prisma.approvalRequest.create({ data: { type: 'SUPERVISOR_REGISTRATION', supervisorId: user.supervisor!.id, details: 'New supervisor registration' } });
  await notifyAdmins({ type: 'APPROVAL', title: 'New supervisor registration', body: `${b.fullName} (${b.companyName}) registered and awaits approval.`, data: { supervisorId: user.supervisor!.id } });
  await logActivity({ actorId: user.id, actorName: user.fullName, entityType: 'SUPERVISOR', entityId: user.supervisor!.id, action: 'REGISTERED', details: `Supervisor registration – ${b.companyName}` });
  res.status(201).json({ success: true, data: { token: signToken(user), user: publicUser(user) } });
}));

const registerDriver = z.object({
  fullName: z.string().min(2),
  mobile: z.string().regex(mobileRx, 'Invalid Indian mobile number'),
  email: z.string().email(),
  dateOfBirth: z.string().optional(),
  address: z.string().optional(),
  password: z.string().min(6),
  acceptTerms: z.boolean().optional(),
  fcmToken: z.string().optional(),
});

authRouter.post('/register/driver', asyncHandler(async (req, res) => {
  const b = parse(registerDriver, req.body);
  const email = b.email.toLowerCase();
  if (await prisma.user.findFirst({ where: { OR: [{ email }, { mobile: b.mobile }] } })) throw conflict('Email or mobile already registered');
  const user = await prisma.user.create({
    data: {
      role: 'DRIVER', fullName: b.fullName, email, mobile: b.mobile, passwordHash: await bcrypt.hash(b.password, 10), status: 'PENDING', fcmToken: b.fcmToken,
      driver: { create: { code: await nextDriverCode(), dateOfBirth: b.dateOfBirth ? new Date(b.dateOfBirth) : undefined, address: b.address } },
    },
    include: { driver: true },
  });
  await logActivity({ actorId: user.id, actorName: user.fullName, entityType: 'DRIVER', entityId: user.driver!.id, action: 'REGISTERED', details: 'Driver registration started' });
  res.status(201).json({ success: true, data: { token: signToken(user), user: publicUser(user) } });
}));

authRouter.get('/me', authenticate, asyncHandler(async (req, res) => {
  const u = await prisma.user.findUnique({ where: { id: req.user!.id }, include: { admin: true, supervisor: { include: { client: true, locations: true } }, driver: { include: { vehicles: true, documents: true, platforms: true } } } });
  if (!u) throw notFound();
  res.json({ success: true, data: { user: publicUser(u), driverDetail: u.driver, supervisorDetail: u.supervisor } });
}));

authRouter.put('/me', authenticate, asyncHandler(async (req, res) => {
  const b = parse(z.object({ fullName: z.string().min(2).optional(), email: z.string().email().optional(), fcmToken: z.string().optional(), address: z.string().optional(), dateOfBirth: z.string().optional() }), req.body);
  const u = await prisma.user.update({ where: { id: req.user!.id }, data: { fullName: b.fullName, email: b.email?.toLowerCase(), fcmToken: b.fcmToken }, include: { admin: true, supervisor: true, driver: true } });
  if (u.driver && (b.address || b.dateOfBirth)) await prisma.driver.update({ where: { id: u.driver.id }, data: { address: b.address, dateOfBirth: b.dateOfBirth ? new Date(b.dateOfBirth) : undefined } });
  res.json({ success: true, data: publicUser(u) });
}));

authRouter.post('/change-password', authenticate, asyncHandler(async (req, res) => {
  const b = parse(z.object({ currentPassword: z.string(), newPassword: z.string().min(6) }), req.body);
  const u = await prisma.user.findUniqueOrThrow({ where: { id: req.user!.id } });
  if (!(await bcrypt.compare(b.currentPassword, u.passwordHash))) throw badRequest('Current password is incorrect');
  await prisma.user.update({ where: { id: u.id }, data: { passwordHash: await bcrypt.hash(b.newPassword, 10) } });
  res.json({ success: true });
}));

authRouter.post('/forgot-password', asyncHandler(async (req, res) => {
  const b = parse(z.object({ identifier: z.string().min(3) }), req.body);
  const u = await prisma.user.findFirst({ where: { OR: [{ email: b.identifier.toLowerCase() }, { mobile: b.identifier }] } });
  // Always respond OK to avoid account enumeration. In production, deliver the token via SMS/email.
  let token: string | undefined;
  if (u) {
    token = crypto.randomInt(100000, 999999).toString();
    await prisma.passwordReset.create({ data: { userId: u.id, token, expiresAt: dayjs().add(15, 'minute').toDate() } });
  }
  res.json({ success: true, message: 'If the account exists, a reset code has been sent.', ...(process.env.NODE_ENV !== 'production' && token ? { devToken: token } : {}) });
}));

authRouter.post('/reset-password', asyncHandler(async (req, res) => {
  const b = parse(z.object({ token: z.string().min(4), newPassword: z.string().min(6) }), req.body);
  const r = await prisma.passwordReset.findUnique({ where: { token: b.token } });
  if (!r || r.usedAt || r.expiresAt < new Date()) throw badRequest('Invalid or expired reset code');
  await prisma.$transaction([
    prisma.user.update({ where: { id: r.userId }, data: { passwordHash: await bcrypt.hash(b.newPassword, 10) } }),
    prisma.passwordReset.update({ where: { id: r.id }, data: { usedAt: new Date() } }),
  ]);
  res.json({ success: true });
}));

/** Facial identification – selfie (+ optional ID photo). Used by driver & supervisor onboarding. */
authRouter.post('/face-verify', authenticate, upload.fields([{ name: 'selfie', maxCount: 1 }, { name: 'idPhoto', maxCount: 1 }]), asyncHandler(async (req, res) => {
  const files = req.files as Record<string, Express.Multer.File[]> | undefined;
  const selfie = files?.selfie?.[0];
  if (!selfie) throw badRequest('selfie file is required');
  const idPhoto = files?.idPhoto?.[0];
  const result = await verifyFace(selfie.buffer, idPhoto?.buffer);
  const stored = await storeFile(`faces/${req.user!.id}`, selfie);
  const storedId = idPhoto ? await storeFile(`faces/${req.user!.id}`, idPhoto) : null;
  if (req.user!.role === 'DRIVER' && req.user!.driverId) {
    await prisma.driver.update({ where: { id: req.user!.driverId }, data: { selfieUrl: stored.url, idPhotoUrl: storedId?.url, faceVerified: result.matched, faceMatchScore: result.score } });
    await prisma.document.upsert({
      where: { id: (await prisma.document.findFirst({ where: { driverId: req.user!.driverId, type: 'FACE_VERIFICATION' } }))?.id ?? '__none__' },
      update: { fileUrl: stored.url, status: result.matched ? 'VERIFIED' : 'PENDING', verifiedAt: result.matched ? new Date() : null },
      create: { driverId: req.user!.driverId, type: 'FACE_VERIFICATION', fileUrl: stored.url, fileName: selfie.originalname, mimeType: selfie.mimetype, status: result.matched ? 'VERIFIED' : 'PENDING', verifiedAt: result.matched ? new Date() : null },
    });
  } else if (req.user!.role === 'SUPERVISOR' && req.user!.supervisorId) {
    await prisma.supervisor.update({ where: { id: req.user!.supervisorId }, data: { selfieUrl: stored.url, faceVerified: result.matched, faceMatchScore: result.score } });
  }
  await prisma.user.update({ where: { id: req.user!.id }, data: { avatarUrl: stored.url } });
  await logActivity({ actorId: req.user!.id, actorName: req.user!.fullName, entityType: req.user!.role, entityId: req.user!.id, action: 'FACE_VERIFIED', details: `${result.message} (${Math.round(result.score * 100)}%)` });
  res.json({ success: true, data: { ...result, selfieUrl: stored.url, idPhotoUrl: storedId?.url } });
}));

authRouter.post('/logout', authenticate, asyncHandler(async (req, res) => {
  await prisma.user.update({ where: { id: req.user!.id }, data: { fcmToken: null } });
  res.json({ success: true });
}));

authRouter.get('/session', authenticate, asyncHandler(async (req, res) => {
  res.json({ success: true, data: await loadUser(req.user!.id) });
}));
