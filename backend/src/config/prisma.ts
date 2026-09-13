import { Prisma, PrismaClient } from '@prisma/client';

// Serialise Decimal columns as plain numbers in JSON responses.
(Prisma.Decimal.prototype as any).toJSON = function toJSON() { return Number(this.toString()); };
import { env } from './env.js';

export const prisma = new PrismaClient({
  log: env.isProd ? ['error'] : ['warn', 'error'],
});
