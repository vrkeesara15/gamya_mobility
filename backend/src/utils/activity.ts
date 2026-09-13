import { prisma } from '../config/prisma.js';

export async function logActivity(p: {
  actorId?: string | null; actorName?: string | null; entityType: string; entityId?: string | null; action: string; details?: string | null;
}) {
  try {
    await prisma.activityLog.create({ data: { actorId: p.actorId ?? null, actorName: p.actorName ?? null, entityType: p.entityType, entityId: p.entityId ?? null, action: p.action, details: p.details ?? null } });
  } catch { /* never fail the request because of audit logging */ }
}
