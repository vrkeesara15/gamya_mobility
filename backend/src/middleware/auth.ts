import type { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { prisma } from '../config/prisma.js';
import { forbidden, unauthorized } from '../utils/errors.js';
import type { Role, AdminRole } from '@prisma/client';

export interface AuthUser {
  id: string;
  role: Role;
  fullName: string;
  email?: string | null;
  mobile?: string | null;
  adminId?: string;
  adminRole?: AdminRole;
  supervisorId?: string;
  driverId?: string;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express { interface Request { user?: AuthUser } }
}

export interface JwtPayload { sub: string; role: Role }

export function signToken(user: { id: string; role: Role }) {
  return jwt.sign({ sub: user.id, role: user.role } satisfies JwtPayload, env.jwtSecret, { expiresIn: env.jwtExpiresIn } as jwt.SignOptions);
}

export async function loadUser(userId: string): Promise<AuthUser | null> {
  const u = await prisma.user.findUnique({ where: { id: userId }, include: { admin: true, supervisor: true, driver: true } });
  if (!u) return null;
  return {
    id: u.id, role: u.role, fullName: u.fullName, email: u.email, mobile: u.mobile,
    adminId: u.admin?.id, adminRole: u.admin?.adminRole, supervisorId: u.supervisor?.id, driverId: u.driver?.id,
  };
}

export async function authenticate(req: Request, _res: Response, next: NextFunction) {
  try {
    const h = req.headers.authorization;
    if (!h?.startsWith('Bearer ')) throw unauthorized('Missing token');
    const payload = jwt.verify(h.slice(7), env.jwtSecret) as JwtPayload;
    const user = await loadUser(payload.sub);
    if (!user) throw unauthorized('User no longer exists');
    req.user = user;
    next();
  } catch (e) {
    next(e instanceof Error && e.name === 'JsonWebTokenError' ? unauthorized('Invalid token') : e instanceof Error && e.name === 'TokenExpiredError' ? unauthorized('Token expired') : e);
  }
}

export const requireRole = (...roles: Role[]) => (req: Request, _res: Response, next: NextFunction) => {
  if (!req.user) return next(unauthorized());
  if (!roles.includes(req.user.role)) return next(forbidden('Insufficient role'));
  next();
};

export const requireAdmin = requireRole('ADMIN');
export const requireSuperAdmin = (req: Request, _res: Response, next: NextFunction) => {
  if (req.user?.role !== 'ADMIN' || req.user.adminRole !== 'SUPER_ADMIN') return next(forbidden('Super admin only'));
  next();
};
