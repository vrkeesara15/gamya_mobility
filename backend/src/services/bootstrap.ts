import bcrypt from 'bcryptjs';
import { prisma } from '../config/prisma.js';
import { env } from '../config/env.js';
import { logger } from '../config/logger.js';

export const DEFAULT_PLATFORMS = [
  { name: 'Routematic', code: 'ROUTEMATIC', color: '#16A34A', deepLinkScheme: 'routematic://', websiteUrl: 'https://www.routematic.com', sortOrder: 1 },
  { name: 'MoveInSync', code: 'MOVEINSYNC', color: '#2563EB', deepLinkScheme: 'moveinsync://', websiteUrl: 'https://www.moveinsync.com', sortOrder: 2 },
  { name: 'WhistleDrive', code: 'WHISTLEDRIVE', color: '#F59E0B', deepLinkScheme: 'whistledrive://', websiteUrl: 'https://www.whistledrive.com', sortOrder: 3 },
  { name: 'Uber for Business', code: 'UBER_BUSINESS', color: '#111111', deepLinkScheme: 'uber://', websiteUrl: 'https://www.uber.com/business', sortOrder: 4 },
  { name: 'Other', code: 'OTHER', color: '#9CA3AF', sortOrder: 99 },
];

export const DEFAULT_TARIFFS = [
  { vehicleType: 'SEDAN', baseAmount: 950, perKm: 14, perHour: 150 },
  { vehicleType: 'SUV', baseAmount: 1450, perKm: 18, perHour: 200 },
  { vehicleType: 'INNOVA', baseAmount: 1850, perKm: 20, perHour: 220 },
  { vehicleType: 'TEMPO_TRAVELLER', baseAmount: 3200, perKm: 28, perHour: 350 },
  { vehicleType: 'TEMPO', baseAmount: 2800, perKm: 26, perHour: 320 },
  { vehicleType: 'OTHER', baseAmount: 1200, perKm: 16, perHour: 180 },
] as const;

/** Idempotent: makes sure a super-admin, platforms and tariffs exist. */
export async function ensureBootstrap() {
  for (const p of DEFAULT_PLATFORMS) await prisma.platform.upsert({ where: { code: p.code }, update: {}, create: p });
  for (const t of DEFAULT_TARIFFS) await prisma.tariff.upsert({ where: { vehicleType: t.vehicleType }, update: {}, create: t });
  const adminCount = await prisma.adminUser.count();
  if (adminCount === 0) {
    await prisma.user.create({
      data: {
        role: 'ADMIN', fullName: 'Admin', email: env.adminBootstrapEmail.toLowerCase(), passwordHash: await bcrypt.hash(env.adminBootstrapPassword, 10), status: 'ACTIVE',
        admin: { create: { adminRole: 'SUPER_ADMIN', designation: 'Super Admin' } },
      },
    });
    logger.info(`Bootstrapped super admin ${env.adminBootstrapEmail}`);
  }
  const settings: Record<string, unknown> = {
    company: { name: 'GAMYA MOBILITY PVT LTD', tagline: 'On Time. Every Time.', email: 'support@gamyamobility.com', phone: '+91 81438 52545', address: 'Hyderabad, Telangana, India', currency: 'INR' },
    documents: { requiredDriverDocs: ['RC', 'PERMIT', 'INSURANCE', 'DRIVING_LICENCE', 'VEHICLE_PHOTO_1', 'VEHICLE_PHOTO_2', 'FACE_VERIFICATION'], requiredVehicleDocs: ['RC', 'PERMIT', 'INSURANCE', 'PUC', 'FITNESS', 'VEHICLE_PHOTO_1', 'VEHICLE_PHOTO_2'], renewalReminderDays: 30, reVerificationMonths: 12 },
    notifications: { pushEnabled: true, emailEnabled: false, smsEnabled: false },
  };
  for (const [key, value] of Object.entries(settings)) await prisma.setting.upsert({ where: { key }, update: {}, create: { key, value: value as object } });
}
