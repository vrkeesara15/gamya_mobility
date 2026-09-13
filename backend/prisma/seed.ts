/* Seed data mirroring the requirement screenshots. Idempotent-ish: wipes operational tables first. */
import { PrismaClient, VehicleType, AdhocStatus, BookingStatus, TripStatus } from '@prisma/client';
import bcrypt from 'bcryptjs';
import dayjs from 'dayjs';
import { DEFAULT_PLATFORMS, DEFAULT_TARIFFS } from '../src/services/bootstrap.js';

const prisma = new PrismaClient();

// deterministic PRNG
let seed = 20260910;
const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
const pick = <T,>(arr: readonly T[]): T => arr[Math.floor(rnd() * arr.length)];
const int = (a: number, b: number) => a + Math.floor(rnd() * (b - a + 1));
const pad = (n: number, w: number) => String(n).padStart(w, '0');

const AVATAR = (i: number, female = false) => `https://randomuser.me/api/portraits/${female ? 'women' : 'men'}/${(i % 90) + 1}.jpg`;
const CAR = (i: number) => `https://picsum.photos/seed/gamya-car-${i}/640/400`;

const CLIENTS = ['TCS', 'Accenture', 'Microsoft', 'Google', 'Amazon', 'Deloitte', 'Wipro', 'Infosys', 'Capgemini', 'Tech Mahindra', 'ABC Technologies'];
const LOCATIONS = ['Hitech City', 'Gachibowli', 'Financial District', 'Mindspace', 'Madhapur', 'Kondapur', 'Raidurg', 'Nanakramguda', 'ORR', 'Airport (RGIA)', 'Shamshabad', 'Banjara Hills', 'Kukatpally', 'Miyapur', 'Chandanagar', 'Nallagandla', 'Raheja IT Park', 'Hotel Marriott', 'Railway Station', 'Dilsukhnagar'];
const SUPERVISORS = [
  ['Anil Kumar', 'ABC Technologies', 'Hitech City, Gachibowli'], ['Suresh Reddy', 'TCS', 'Financial District'], ['Priya Sharma', 'Microsoft', 'Mindspace, Madhapur'], ['Venkatesh', 'Google', 'Kondapur, Gachibowli'], ['Rohit Verma', 'Accenture', 'Hitech City'],
  ['Swapna R', 'Amazon', 'Raidurg, Nanakramguda'], ['Karthik N', 'Deloitte', ''], ['Deepa S', 'Wipro', 'Gachibowli, ORR'], ['Manoj Kumar', 'Infosys', 'Madhapur, Gachibowli'], ['Neha Patel', 'Capgemini', 'Hitech City, Mindspace'],
  ['Srinivas R', 'TCS', 'Gachibowli'], ['Radhika M', 'Infosys', 'Airport (RGIA)'],
] as const;
const DRIVERS = [
  ['Ramesh Kumar', 'TS07AB1234', 'Toyota', 'Etios', 2022, 'SEDAN', 'ROUTEMATIC'], ['Suresh Babu', 'AP39CD5678', 'Maruti Suzuki', 'Ertiga', 2021, 'SUV', 'MOVEINSYNC'], ['Mohammed Ali', 'TS09EF9012', 'Hyundai', 'Venue', 2023, 'SUV', 'WHISTLEDRIVE'], ['Ravi Teja', 'TG12GH3456', 'Honda', 'City', 2022, 'SEDAN', 'ROUTEMATIC'],
  ['Srinu Reddy', 'TS08IJ7890', 'Kia', 'Carens', 2023, 'SUV', 'MOVEINSYNC'], ['Karthik Nayak', 'AP28IJ7788', 'Tata', 'Innova', 2020, 'INNOVA', 'OTHER'], ['Imran Khan', 'TS11KL5566', 'Mahindra', 'XUV700', 2023, 'SUV', 'WHISTLEDRIVE'], ['Mahesh Yadav', 'TS13MN8899', 'Toyota', 'Innova Crysta', 2021, 'INNOVA', 'MOVEINSYNC'],
  ['Venkatesh', 'AP31OP1122', 'Maruti Suzuki', 'Dzire', 2022, 'SEDAN', 'UBER_BUSINESS'], ['Naresh', 'TS14QR3344', 'Hyundai', 'Aura', 2023, 'SEDAN', 'OTHER'], ['Srinivas Reddy', 'TS08IJ7891', 'Toyota', 'Etios', 2021, 'SEDAN', 'OTHER'], ['Lakshmi Narayana', 'TS09ST4455', 'Force', 'Traveller', 2022, 'TEMPO_TRAVELLER', 'ROUTEMATIC'],
  ['Raju Naik', 'TS07UV6677', 'Toyota', 'Etios', 2020, 'SEDAN', 'ROUTEMATIC'], ['Sateesh', 'TS10WX8899', 'Maruti Suzuki', 'Ertiga', 2022, 'SUV', 'MOVEINSYNC'], ['Anand', 'AP09YZ1010', 'Honda', 'Amaze', 2023, 'SEDAN', 'WHISTLEDRIVE'], ['Deepak', 'TS12AB2020', 'Toyota', 'Innova Crysta', 2022, 'INNOVA', 'ROUTEMATIC'],
  ['Vikram Singh', 'TS05CD3030', 'Hyundai', 'Creta', 2023, 'SUV', 'UBER_BUSINESS'], ['Prasad Rao', 'TS06EF4040', 'Maruti Suzuki', 'Swift Dzire', 2019, 'SEDAN', 'ROUTEMATIC'], ['Kiran Kumar', 'AP16GH5050', 'Tata', 'Nexon', 2024, 'SUV', 'MOVEINSYNC'], ['Bhaskar', 'TS15IJ6060', 'Force', 'Traveller', 2021, 'TEMPO_TRAVELLER', 'OTHER'],
  ['Gopal Reddy', 'TS02KL7070', 'Toyota', 'Etios', 2022, 'SEDAN', 'ROUTEMATIC'], ['Nagaraju', 'TS03MN8080', 'Mahindra', 'Marazzo', 2020, 'SUV', 'WHISTLEDRIVE'], ['Shankar', 'TS04OP9090', 'Honda', 'City', 2024, 'SEDAN', 'MOVEINSYNC'], ['Rahul Dev', 'TS20QR1111', 'Kia', 'Carens', 2024, 'SUV', 'ROUTEMATIC'],
  ['Farooq', 'TS21ST2222', 'Hyundai', 'Xcent', 2019, 'SEDAN', 'OTHER'], ['Yadagiri', 'TS22UV3333', 'Tata', 'Winger', 2022, 'TEMPO', 'ROUTEMATIC'], ['Balaji', 'TS23WX4444', 'Toyota', 'Innova Crysta', 2023, 'INNOVA', 'MOVEINSYNC'], ['Chandra', 'TS24YZ5555', 'Maruti Suzuki', 'Ertiga', 2021, 'SUV', 'WHISTLEDRIVE'],
  ['Hari Krishna', 'TS25AB6666', 'Honda', 'Amaze', 2022, 'SEDAN', 'ROUTEMATIC'], ['Mallesh', 'TS26CD7777', 'Force', 'Traveller', 2020, 'TEMPO_TRAVELLER', 'ROUTEMATIC'], ['Pavan', 'TS27EF8888', 'Hyundai', 'Aura', 2024, 'SEDAN', 'UBER_BUSINESS'], ['Sai Kumar', 'TS28GH9999', 'Toyota', 'Etios', 2021, 'SEDAN', 'MOVEINSYNC'],
] as const;

async function main() {
  console.log('Seeding Gamya Mobility …');
  // wipe operational data
  await prisma.$transaction([
    prisma.tripEvent.deleteMany(), prisma.earning.deleteMany(), prisma.settlement.deleteMany(), prisma.invoice.deleteMany(), prisma.trip.deleteMany(), prisma.booking.deleteMany(), prisma.adhocRequest.deleteMany(),
    prisma.approvalRequest.deleteMany(), prisma.document.deleteMany(), prisma.vehiclePhoto.deleteMany(), prisma.vehicle.deleteMany(), prisma.notification.deleteMany(), prisma.activityLog.deleteMany(), prisma.passwordReset.deleteMany(),
    prisma.user.deleteMany({ where: { role: { in: ['DRIVER', 'SUPERVISOR'] } } }), prisma.location.deleteMany(), prisma.client.deleteMany(),
  ]);

  const pw = await bcrypt.hash('Gamya@123', 10);
  for (const p of DEFAULT_PLATFORMS) await prisma.platform.upsert({ where: { code: p.code }, update: p, create: p });
  for (const t of DEFAULT_TARIFFS) await prisma.tariff.upsert({ where: { vehicleType: t.vehicleType }, update: t, create: t });
  const platforms = await prisma.platform.findMany();
  const P = (code: string) => platforms.find((p) => p.code === code)!;

  // admin users
  const adminPw = await bcrypt.hash(process.env.ADMIN_BOOTSTRAP_PASSWORD ?? 'Admin@123', 10);
  const admin = await prisma.user.upsert({ where: { email: (process.env.ADMIN_BOOTSTRAP_EMAIL ?? 'admin@gamya.com').toLowerCase() }, update: { fullName: 'Admin', avatarUrl: AVATAR(32), status: 'ACTIVE' }, create: { role: 'ADMIN', fullName: 'Admin', email: (process.env.ADMIN_BOOTSTRAP_EMAIL ?? 'admin@gamya.com').toLowerCase(), mobile: '8143852545', passwordHash: adminPw, avatarUrl: AVATAR(32), status: 'ACTIVE', admin: { create: { adminRole: 'SUPER_ADMIN', designation: 'Super Admin' } } }, include: { admin: true } });
  const adminId = admin.admin?.id ?? (await prisma.adminUser.findUniqueOrThrow({ where: { userId: admin.id } })).id;
  await prisma.user.upsert({ where: { email: 'ops@gamya.com' }, update: {}, create: { role: 'ADMIN', fullName: 'Operations Desk', email: 'ops@gamya.com', mobile: '9000000001', passwordHash: adminPw, avatarUrl: AVATAR(45), status: 'ACTIVE', admin: { create: { adminRole: 'OPS', designation: 'Operations' } } } });

  const clients = await Promise.all(CLIENTS.map((name, i) => prisma.client.create({ data: { name, code: `CL${pad(i + 1, 3)}`, contactName: pick(['Ramesh K', 'Sunita', 'Arjun', 'Meera']), contactMobile: `98${pad(int(10000000, 99999999), 8)}`, email: `transport@${name.toLowerCase().replace(/\s+/g, '')}.com` } })));
  const C = (name: string) => clients.find((c) => c.name === name)!;
  const locations = await Promise.all(LOCATIONS.map((name) => prisma.location.create({ data: { name, city: 'Hyderabad', latitude: 17.38 + rnd() * 0.15, longitude: 78.3 + rnd() * 0.25 } })));
  const L = (name: string) => locations.find((l) => l.name === name);

  // supervisors
  const supervisors = [] as { id: string; userId: string; clientId: string | null; name: string; companyName: string }[];
  for (const [i, [name, company, locs]] of SUPERVISORS.entries()) {
    const female = ['Priya Sharma', 'Swapna R', 'Deepa S', 'Neha Patel', 'Radhika M'].includes(name);
    const status = i === 5 || i === 8 ? 'INACTIVE' : i >= 10 ? 'PENDING' : 'ACTIVE';
    const s = await prisma.supervisor.create({ data: { code: `SUP${pad(i + 1, 3)}`, employeeId: `EMP${pad(1000 + i * 37, 4)}`, companyName: company, client: { connect: { id: C(company).id } }, dateOfJoining: dayjs('2025-01-05').add(i * 23, 'day').toDate(), selfieUrl: AVATAR(i + 3, female), faceVerified: true, faceMatchScore: 0.9 + rnd() * 0.08, approvedAt: status === 'PENDING' ? null : dayjs('2025-01-06').add(i * 23, 'day').toDate(), approvedById: status === 'PENDING' ? null : adminId,
      user: { create: { role: 'SUPERVISOR', fullName: name, email: `${name.toLowerCase().replace(/\s+/g, '.')}@gamya.com`, mobile: `98${pad(48169234 + i * 1111, 8)}`, passwordHash: pw, avatarUrl: AVATAR(i + 3, female), status, lastLoginAt: dayjs().subtract(int(0, 72), 'hour').toDate() } },
      locations: { connect: locs.split(',').map((x) => x.trim()).filter(Boolean).map((n) => ({ id: L(n)!.id })) } } });
    supervisors.push({ id: s.id, userId: s.userId, clientId: s.clientId, name, companyName: company });
    if (status === 'PENDING') await prisma.approvalRequest.create({ data: { type: 'SUPERVISOR_REGISTRATION', supervisorId: s.id, details: 'New supervisor registration', submittedAt: dayjs().subtract(int(1, 4), 'day').toDate() } });
  }

  // drivers + vehicles + documents
  const drivers = [] as { id: string; userId: string; vehicleId: string; name: string; vehicleType: VehicleType; platformId: string; status: string }[];
  for (const [i, [name, number, make, model, year, type, platformCode]] of DRIVERS.entries()) {
    const status = [4, 8].includes(i) ? 'INACTIVE' : [6, 9, 12, 13, 14, 15].includes(i) ? 'PENDING' : i === 24 ? 'BLACKLISTED' : 'ACTIVE';
    const platform = P(platformCode);
    const female = ['Lakshmi Narayana'].includes(name);
    const d = await prisma.driver.create({ data: { code: `DRV${pad(i + 1, 3)}`, dateOfBirth: dayjs('1988-03-12').add(i * 97, 'day').toDate(), address: `${pick(['Miyapur', 'Kukatpally', 'Dilsukhnagar', 'Chandanagar', 'LB Nagar', 'Uppal'])}, Hyderabad`, licenceNumber: `TS${pad(int(10, 99), 2)}${pad(int(2010, 2022), 4)}${pad(int(1000000, 9999999), 7)}`, joiningDate: dayjs('2024-01-15').add(i * 19, 'day').toDate(), selfieUrl: AVATAR(i + 10, female), idPhotoUrl: AVATAR(i + 10, female), faceVerified: true, faceMatchScore: 0.88 + rnd() * 0.1, reVerificationDue: dayjs().add(i < 14 ? int(-5, 25) : int(60, 300), 'day').toDate(), approvedAt: status === 'PENDING' ? null : dayjs('2024-01-16').add(i * 19, 'day').toDate(), approvedById: status === 'PENDING' ? null : adminId, rating: Number((4.2 + rnd() * 0.8).toFixed(1)), blacklistReason: status === 'BLACKLISTED' ? 'Repeated no-shows' : null,
      user: { create: { role: 'DRIVER', fullName: name, email: `${name.toLowerCase().replace(/\s+/g, '.')}${i}@gmail.com`, mobile: `9${pad(700123456 + i * 7919, 9)}`, passwordHash: pw, avatarUrl: AVATAR(i + 10, female), status, lastLoginAt: dayjs().subtract(int(0, 48), 'hour').toDate() } },
      platforms: { connect: [{ id: platform.id }, ...(i % 3 === 0 ? [{ id: P('MOVEINSYNC').id }] : [])].filter((x, idx, arr) => arr.findIndex((y) => y.id === x.id) === idx) } } });
    const vStatus = status === 'BLACKLISTED' ? 'BLACKLISTED' : status === 'INACTIVE' ? 'INACTIVE' : status === 'PENDING' ? 'UNDER_REVIEW' : 'ACTIVE';
    const v = await prisma.vehicle.create({ data: { number, make, model, year, type: type as VehicleType, color: pick(['White', 'Silver', 'Grey', 'Black']), fuelType: pick(['PETROL', 'DIESEL', 'CNG']), seatingCapacity: type === 'TEMPO_TRAVELLER' ? '12 + 1' : type === 'INNOVA' || type === 'SUV' ? '6 + 1' : '4 + 1', status: vStatus, driverId: d.id, supervisorId: supervisors[i % supervisors.length].id, platformId: platform.id, registrationDate: dayjs(`${year}-01-12`).add(i * 11, 'day').toDate(), permitValidTill: dayjs().add(i === 1 || i === 5 ? 20 : i === 7 ? -10 : int(200, 700), 'day').toDate(), insuranceValidTill: dayjs().add(i === 2 ? 15 : int(100, 500), 'day').toDate(), pucValidTill: dayjs().add(i === 9 ? -3 : int(30, 180), 'day').toDate(), fitnessValidTill: dayjs().add(int(200, 900), 'day').toDate(), currentLocation: pick(LOCATIONS) + ', Hyderabad', latitude: 17.38 + rnd() * 0.15, longitude: 78.3 + rnd() * 0.25,
      photos: { create: [{ url: CAR(i * 2), caption: 'Front' }, { url: CAR(i * 2 + 1), caption: 'Side' }] } } });
    const docStatus = (k: number) => (status === 'PENDING' ? 'PENDING' : k === 7 && (i === 2 || i === 4) ? 'PENDING' : k === 4 && i === 8 ? 'EXPIRED' : 'VERIFIED');
    const verifiedAt = status === 'PENDING' ? null : dayjs('2024-01-16').add(i * 19, 'day').toDate();
    await prisma.document.createMany({ data: [
      { vehicleId: v.id, type: 'RC', fileUrl: `https://picsum.photos/seed/rc-${i}/800/1100`, status: docStatus(1), verifiedAt, verifiedById: verifiedAt ? adminId : null },
      { vehicleId: v.id, type: 'PERMIT', fileUrl: `https://picsum.photos/seed/permit-${i}/800/1100`, status: docStatus(2), validTill: dayjs().add(int(30, 400), 'day').toDate(), verifiedAt, verifiedById: verifiedAt ? adminId : null },
      { vehicleId: v.id, type: 'INSURANCE', fileUrl: `https://picsum.photos/seed/ins-${i}/800/1100`, status: docStatus(3), validTill: dayjs().add(int(30, 400), 'day').toDate(), verifiedAt, verifiedById: verifiedAt ? adminId : null },
      { vehicleId: v.id, type: 'PUC', fileUrl: `https://picsum.photos/seed/puc-${i}/800/1100`, status: docStatus(4), validTill: dayjs().add(int(-5, 180), 'day').toDate(), verifiedAt, verifiedById: verifiedAt ? adminId : null },
      { vehicleId: v.id, type: 'FITNESS', fileUrl: `https://picsum.photos/seed/fit-${i}/800/1100`, status: i % 6 === 5 ? 'PENDING' : docStatus(5), verifiedAt, verifiedById: verifiedAt ? adminId : null },
      { vehicleId: v.id, type: 'VEHICLE_PHOTO_1', fileUrl: CAR(i * 2), status: docStatus(6), verifiedAt, verifiedById: verifiedAt ? adminId : null },
      { vehicleId: v.id, type: 'VEHICLE_PHOTO_2', fileUrl: CAR(i * 2 + 1), status: docStatus(6), verifiedAt, verifiedById: verifiedAt ? adminId : null },
      { driverId: d.id, type: 'DRIVING_LICENCE', fileUrl: `https://picsum.photos/seed/dl-${i}/800/500`, status: docStatus(7), validTill: dayjs().add(int(200, 2000), 'day').toDate(), verifiedAt, verifiedById: verifiedAt ? adminId : null },
      { driverId: d.id, type: 'FACE_VERIFICATION', fileUrl: AVATAR(i + 10, female), status: status === 'PENDING' ? 'PENDING' : 'VERIFIED', verifiedAt },
      { driverId: d.id, type: 'AADHAAR', fileUrl: AVATAR(i + 10, female), status: status === 'PENDING' ? 'PENDING' : 'VERIFIED', verifiedAt },
    ] });
    if (status === 'PENDING') {
      await prisma.approvalRequest.create({ data: { type: 'DRIVER_REGISTRATION', driverId: d.id, vehicleId: v.id, details: 'New driver registration', submittedAt: dayjs().subtract(int(1, 5), 'day').subtract(int(0, 600), 'minute').toDate() } });
      await prisma.approvalRequest.create({ data: { type: 'VEHICLE_REGISTRATION', vehicleId: v.id, driverId: d.id, details: 'New vehicle registration', submittedAt: dayjs().subtract(int(1, 5), 'day').toDate() } });
    }
    if (i === 2) { const doc = await prisma.document.findFirst({ where: { vehicleId: v.id, type: 'INSURANCE' } }); await prisma.document.update({ where: { id: doc!.id }, data: { status: 'PENDING' } }); await prisma.approvalRequest.create({ data: { type: 'DOCUMENT_UPLOAD', driverId: d.id, vehicleId: v.id, documentId: doc!.id, details: 'Insurance document', submittedAt: dayjs().subtract(4, 'day').toDate() } }); }
    if (i === 4) { const doc = await prisma.document.findFirst({ where: { vehicleId: v.id, type: 'PERMIT' } }); await prisma.approvalRequest.create({ data: { type: 'DOCUMENT_RENEWAL', driverId: d.id, vehicleId: v.id, documentId: doc!.id, details: 'Permit renewal', submittedAt: dayjs().subtract(3, 'day').toDate() } }); }
    if (i === 13) { const doc = await prisma.document.findFirst({ where: { driverId: d.id, type: 'DRIVING_LICENCE' } }); await prisma.approvalRequest.create({ data: { type: 'DOCUMENT_UPLOAD', driverId: d.id, documentId: doc!.id, details: 'Driving license document', submittedAt: dayjs().subtract(3, 'day').toDate() } }); }
    drivers.push({ id: d.id, userId: d.userId, vehicleId: v.id, name, vehicleType: type as VehicleType, platformId: platform.id, status });
  }
  // a few extra unassigned vehicles
  for (let i = 0; i < 6; i++) await prisma.vehicle.create({ data: { number: `TS30ZZ${pad(1000 + i, 4)}`, make: pick(['Toyota', 'Maruti Suzuki', 'Hyundai']), model: pick(['Etios', 'Ertiga', 'Aura', 'Innova Crysta']), year: int(2019, 2024), type: pick(['SEDAN', 'SUV', 'INNOVA']) as VehicleType, status: i < 3 ? 'UNDER_REVIEW' : 'ACTIVE', platformId: pick(platforms).id, registrationDate: dayjs().subtract(int(100, 1500), 'day').toDate(), permitValidTill: dayjs().add(int(100, 600), 'day').toDate(), insuranceValidTill: dayjs().add(int(100, 400), 'day').toDate(), pucValidTill: dayjs().add(int(10, 150), 'day').toDate(), fitnessValidTill: dayjs().add(int(100, 900), 'day').toDate(), photos: { create: [{ url: CAR(100 + i) }] } } });

  const activeDrivers = drivers.filter((d) => d.status === 'ACTIVE');
  const activeSups = supervisors.slice(0, 10);
  const EMPLOYEES = ['Srinivas R', 'Neha Patel', 'Priya Sharma', 'Karthik N', 'Deepa S', 'Manoj Kumar', 'Venkatesh', 'Radhika M', 'Sateesh', 'Anil Kumar', 'Pooja R', 'Arun Kumar', 'Sneha', 'Vijay', 'Divya'];
  const today = dayjs().startOf('day');

  // ad-hoc requests over last 21 days + next 3 days
  let adhocCount = 0; const adhocIds: { id: string; code: string; scheduledAt: Date; status: AdhocStatus; driver?: typeof drivers[number]; supId: string; clientId: string | null; from: string; to: string; platformId: string | null; amount: number; loginTime: string; reportingTime: string; createdAt: Date }[] = [];
  const dayCounters: Record<string, number> = {};
  for (let dOff = -21; dOff <= 3; dOff++) {
    const n = dOff > 0 ? int(3, 6) : int(4, 10);
    for (let k = 0; k < n; k++) {
      const day = today.add(dOff, 'day'); const key = day.format('YYYYMMDD'); dayCounters[key] = (dayCounters[key] ?? 0) + 1;
      const hour = int(6, 21); const scheduledAt = day.hour(hour).minute(pick([0, 15, 30, 45])).toDate();
      const sup = pick(activeSups); const vt = pick(['SEDAN', 'SEDAN', 'SUV', 'SUV', 'INNOVA', 'TEMPO_TRAVELLER']) as VehicleType;
      const from = pick(LOCATIONS); let to = pick(LOCATIONS); while (to === from) to = pick(LOCATIONS);
      const platform = pick([P('ROUTEMATIC'), P('ROUTEMATIC'), P('MOVEINSYNC'), P('WHISTLEDRIVE'), P('UBER_BUSINESS'), P('OTHER')]);
      const amount = DEFAULT_TARIFFS.find((t) => t.vehicleType === vt)!.baseAmount + pick([0, 0, 150, 250, 400]);
      const isPast = dOff < 0 || (dOff === 0 && hour < dayjs().hour());
      const status: AdhocStatus = isPast ? pick(['COMPLETED', 'COMPLETED', 'COMPLETED', 'COMPLETED', 'CANCELLED', 'COMPLETED', 'ASSIGNED']) : dOff === 0 ? pick(['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'PENDING']) : pick(['PENDING', 'ASSIGNED', 'ASSIGNED', 'PENDING']);
      const candidates = activeDrivers.filter((d) => d.vehicleType === vt); const driver = status === 'PENDING' || status === 'CANCELLED' ? undefined : pick(candidates.length ? candidates : activeDrivers);
      const createdAt = dayjs(scheduledAt).subtract(int(2, 48), 'hour').toDate();
      const a = await prisma.adhocRequest.create({ data: { code: `ADH-${key}-${pad(dayCounters[key], 3)}`, clientId: sup.clientId, supervisorId: sup.id, contactName: sup.name, contactMobile: `98${pad(int(10000000, 99999999), 8)}`, fromLocation: from, toLocation: to, fromLatitude: L(from)?.latitude, fromLongitude: L(from)?.longitude, toLatitude: L(to)?.latitude, toLongitude: L(to)?.longitude, scheduledAt, loginTime: `${pad(hour, 2)}:00`, reportingTime: `${pad(hour - 1 < 0 ? 0 : hour - 1, 2)}:30`, passengers: vt === 'TEMPO_TRAVELLER' ? int(8, 12) : int(1, 6), vehicleType: vt, modelYearMin: pick([2020, 2021, 2022]), numberOfVehicles: 1, bookingType: pick(['INSTANT', 'SCHEDULED']), platformId: platform.id, otherPlatformName: platform.code === 'OTHER' ? pick(['Company shuttle', 'Client app']) : null, specialInstructions: pick([null, 'Need before 9:30 AM sharp', 'Carry ID card', 'AC vehicle required', null]), estimatedAmount: amount, status, assignedVehicleId: driver?.vehicleId, assignedDriverId: driver?.id, assignedAt: driver ? dayjs(createdAt).add(int(10, 90), 'minute').toDate() : null, cancelReason: status === 'CANCELLED' ? pick(['Client cancelled', 'Duplicate request', 'Employee not available']) : null, createdAt } });
      adhocIds.push({ id: a.id, code: a.code, scheduledAt, status, driver, supId: sup.id, clientId: sup.clientId, from, to, platformId: platform.id, amount, loginTime: a.loginTime!, reportingTime: a.reportingTime!, createdAt });
      adhocCount++;
    }
  }

  // trips from ad-hoc requests
  const tripCounters: Record<string, number> = {};
  for (const a of adhocIds) {
    if (!a.driver) continue;
    const key = dayjs(a.scheduledAt).format('YYYYMMDD'); tripCounters[key] = (tripCounters[key] ?? 0) + 1;
    const late = rnd() < 0.13;
    const status: TripStatus = a.status === 'COMPLETED' ? 'COMPLETED' : a.status === 'CANCELLED' ? 'CANCELLED' : a.status === 'IN_PROGRESS' ? (late ? 'DELAYED' : 'ON_TRIP') : a.status === 'ACCEPTED' ? 'ACCEPTED' : dayjs(a.scheduledAt).isBefore(dayjs()) && a.status === 'ASSIGNED' ? 'YET_TO_START' : 'ASSIGNED';
    const startedAt = ['COMPLETED', 'ON_TRIP', 'DELAYED'].includes(status) ? dayjs(a.scheduledAt).add(late ? int(16, 45) : int(-5, 10), 'minute').toDate() : null;
    const completedAt = status === 'COMPLETED' ? dayjs(startedAt!).add(int(35, 120), 'minute').toDate() : null;
    const events = [{ type: 'REQUIREMENT_POSTED' as const, at: a.createdAt, note: `Requirement ${a.code} posted` }, { type: 'VENDOR_ASSIGNED' as const, at: dayjs(a.createdAt).add(int(5, 60), 'minute').toDate(), note: `${a.driver.name} assigned` }];
    if (['ACCEPTED', 'YET_TO_START', 'ON_TRIP', 'DELAYED', 'COMPLETED'].includes(status)) { events.push({ type: 'DRIVER_ACCEPTED' as any, at: dayjs(a.createdAt).add(int(61, 120), 'minute').toDate(), note: `Accepted by ${a.driver.name}` }); events.push({ type: 'TRIP_CREATED_IN_PLATFORM' as any, at: dayjs(a.createdAt).add(int(121, 150), 'minute').toDate(), note: 'Trip created in tracking platform' }); }
    if (startedAt) events.push({ type: 'DRIVER_STARTED' as any, at: startedAt, note: late ? 'Started late' : 'Driver started' });
    if (late && startedAt) events.push({ type: 'TRIP_DELAYED' as any, at: startedAt, note: 'Delayed start' });
    if (completedAt) events.push({ type: 'TRIP_COMPLETED' as any, at: completedAt, note: 'Trip completed' });
    if (status === 'CANCELLED') events.push({ type: 'TRIP_CANCELLED' as any, at: dayjs(a.scheduledAt).subtract(1, 'hour').toDate(), note: 'Cancelled' });
    const t = await prisma.trip.create({ data: { code: `GM${key}${pad(tripCounters[key], 2)}`, adhocRequestId: a.id, driverId: a.driver.id, vehicleId: a.driver.vehicleId, platformId: a.platformId, supervisorId: a.supId, clientId: a.clientId, fromLocation: a.from, toLocation: a.to, scheduledStart: a.scheduledAt, loginTime: a.loginTime, reportingTime: a.reportingTime, startedAt, completedAt, status, amount: a.amount, distanceKm: status === 'COMPLETED' ? int(8, 45) : null, onTime: status === 'COMPLETED' ? !late : null, externalTripId: ['ACCEPTED', 'ON_TRIP', 'DELAYED', 'COMPLETED'].includes(status) ? `RM-${int(100000, 999999)}` : null, createdAt: a.createdAt, events: { create: events } } });
    if (status === 'COMPLETED') await prisma.earning.create({ data: { driverId: a.driver.id, tripId: t.id, amount: a.amount, date: completedAt!, status: dayjs(completedAt!).isBefore(dayjs().subtract(10, 'day')) ? 'SETTLED' : 'PENDING' } });
  }

  // regular bookings (last 21 days + next 5)
  const bkCounters: Record<string, number> = {};
  for (let dOff = -21; dOff <= 5; dOff++) {
    const n = dOff > 0 ? int(6, 10) : int(10, 18);
    for (let k = 0; k < n; k++) {
      const day = today.add(dOff, 'day'); const key = day.format('YYYYMMDD'); bkCounters[key] = (bkCounters[key] ?? 0) + 1;
      const date = day.hour(int(6, 21)).minute(pick([0, 30])).toDate(); const sup = pick(activeSups); const isAdhoc = rnd() < 0.18;
      const from = pick(LOCATIONS); let to = pick(LOCATIONS); while (to === from) to = pick(LOCATIONS);
      const vt = pick(['SEDAN', 'SEDAN', 'SUV', 'INNOVA']) as VehicleType; const driver = rnd() < 0.85 ? pick(activeDrivers) : undefined;
      const status: BookingStatus = dOff < 0 ? pick(['COMPLETED', 'COMPLETED', 'COMPLETED', 'CONFIRMED', 'CANCELLED', 'COMPLETED']) : dOff === 0 ? pick(['CONFIRMED', 'CONFIRMED', 'PENDING', 'COMPLETED']) : pick(['CONFIRMED', 'PENDING', 'CONFIRMED', 'RESCHEDULED']);
      await prisma.booking.create({ data: { code: `BK-${key}-${pad(bkCounters[key], 3)}`, date, employeeName: pick(EMPLOYEES), employeeMobile: `9${pad(int(100000000, 999999999), 9)}`, clientId: sup.clientId, supervisorId: sup.id, tripType: isAdhoc ? 'ADHOC' : 'REGULAR', fromLocation: from, toLocation: to, passengers: int(1, 4), vehicleType: vt, vehicleId: driver?.vehicleId, driverId: driver?.id, platformId: driver?.platformId ?? pick(platforms).id, status, estimatedAmount: DEFAULT_TARIFFS.find((t) => t.vehicleType === vt)!.baseAmount + pick([0, 100, 200, 350, 900]), cancelReason: status === 'CANCELLED' ? 'Employee cancelled' : null, createdAt: dayjs(date).subtract(int(1, 3), 'day').toDate() } });
    }
  }

  // settlements for settled earnings
  for (const d of activeDrivers.slice(0, 6)) {
    const settled = await prisma.earning.findMany({ where: { driverId: d.id, status: 'SETTLED' } });
    if (!settled.length) continue;
    const total = settled.reduce((s, e) => s + Number(e.amount), 0);
    await prisma.settlement.create({ data: { code: `STL-${dayjs().subtract(1, 'month').format('YYYYMM')}-${pad(int(1, 999), 4)}`, driverId: d.id, periodStart: dayjs().subtract(30, 'day').toDate(), periodEnd: dayjs().subtract(10, 'day').toDate(), totalAmount: total, status: 'PAID', paidAt: dayjs().subtract(8, 'day').toDate(), reference: `UTR${int(100000000, 999999999)}`, earnings: { connect: settled.map((e) => ({ id: e.id })) } } });
  }
  for (const c of clients.slice(0, 5)) await prisma.invoice.create({ data: { code: `INV-${dayjs().subtract(1, 'month').format('YYYYMM')}-${pad(int(1, 999), 4)}`, clientId: c.id, periodStart: dayjs().subtract(1, 'month').startOf('month').toDate(), periodEnd: dayjs().subtract(1, 'month').endOf('month').toDate(), tripCount: int(20, 120), amount: int(50000, 400000), status: pick(['PAID', 'SENT', 'OVERDUE']), dueDate: dayjs().add(int(-5, 20), 'day').toDate() } });

  // notifications & activity
  const notes = [
    { title: 'New ad-hoc requirement', body: 'Sedan • 10 Sep 2026 • Mindspace, Hitech City', type: 'TRIP_REQUEST' }, { title: 'Trip accepted', body: 'Ramesh Kumar accepted GM2026091001.', type: 'TRIP_UPDATE' }, { title: 'New driver registration', body: 'Raju Naik submitted registration for approval.', type: 'APPROVAL' },
    { title: 'Document renewal', body: 'Permit renewal uploaded for TS08IJ7890.', type: 'APPROVAL' }, { title: 'Payment settled', body: 'Settlement STL paid to Suresh Babu.', type: 'PAYMENT' }, { title: 'System', body: 'Weekly report is ready.', type: 'SYSTEM' },
  ] as const;
  for (let i = 0; i < 12; i++) { const n = notes[i % notes.length]; await prisma.notification.create({ data: { userId: admin.id, type: n.type, title: n.title, body: n.body, read: i > 8, createdAt: dayjs().subtract(i * 3, 'hour').toDate() } }); }
  for (const d of activeDrivers.slice(0, 8)) { await prisma.notification.create({ data: { userId: d.userId, type: 'TRIP_REQUEST', title: 'New Ad-hoc Requirement', body: 'Sedan • 10 Sep 2026 • Mindspace, Hitech City', createdAt: dayjs().subtract(2, 'minute').toDate() } }); await prisma.notification.create({ data: { userId: d.userId, type: 'TRIP_UPDATE', title: 'Trip Update', body: 'Your trip has been confirmed', createdAt: dayjs().subtract(1, 'hour').toDate() } }); await prisma.notification.create({ data: { userId: d.userId, type: 'ACCOUNT', title: 'Account Update', body: 'Your documents have been approved', read: true, createdAt: dayjs().subtract(2, 'hour').toDate() } }); }
  for (const s of activeSups) await prisma.notification.create({ data: { userId: s.userId, type: 'TRIP_UPDATE', title: 'Driver accepted', body: 'Your latest requirement has been accepted by the driver.', createdAt: dayjs().subtract(int(1, 30), 'hour').toDate() } });
  const acts = [
    ['Anil Kumar', 'SUPERVISOR', 'Posted Requirement', 'Sedan | Mindspace → Gachibowli | Platform: Routematic'], ['Priya Sharma', 'SUPERVISOR', 'Accepted Driver', 'Driver Ramesh Kumar accepted the trip'], ['Venkatesh', 'SUPERVISOR', 'Completed Booking', 'Trip ID #GM2026090901 marked as completed'],
    ['Suresh Reddy', 'SUPERVISOR', 'Updated Requirement', 'Modified time and location for tomorrow\'s trip'], ['Deepa S', 'SUPERVISOR', 'Cancelled Requirement', 'Requirement cancelled due to client request'],
    ['Ramesh Kumar', 'DRIVER', 'Completed trip (Routematic)', 'Trip GM2026091001 completed'], ['Ramesh Kumar', 'DRIVER', 'Accepted ad-hoc request', 'ADH-20260910-001'], ['Admin', 'DRIVER', 'Documents verified', 'All 7 documents verified'], ['Ramesh Kumar', 'DRIVER', 'Login to app', ''], ['Ramesh Kumar', 'DRIVER', 'Profile updated', 'Address changed'],
  ];
  for (const [i, [actor, entity, action, details]] of acts.entries()) { const s = supervisors.find((x) => x.name === actor); const d = drivers.find((x) => x.name === actor); await prisma.activityLog.create({ data: { actorId: s?.userId ?? d?.userId ?? admin.id, actorName: actor, entityType: entity, entityId: s?.id ?? d?.id ?? drivers[0].id, action, details, createdAt: dayjs().subtract(i * 5 + 1, 'hour').toDate() } }); }

  const counts = { supervisors: await prisma.supervisor.count(), drivers: await prisma.driver.count(), vehicles: await prisma.vehicle.count(), adhoc: adhocCount, bookings: await prisma.booking.count(), trips: await prisma.trip.count(), approvals: await prisma.approvalRequest.count({ where: { status: 'PENDING' } }) };
  console.log('Seed complete', counts);
  console.log('Logins → admin@gamya.com / Admin@123 · supervisor anil.kumar@gamya.com / Gamya@123 · driver ramesh.kumar0@gmail.com / Gamya@123');
}

main().catch((e) => { console.error(e); process.exit(1); }).finally(() => prisma.$disconnect());
