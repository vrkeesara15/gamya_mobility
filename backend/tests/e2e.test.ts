import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { ensureBootstrap } from '../src/services/bootstrap.js';
import { prisma } from '../src/config/prisma.js';

const app = createApp();
const api = '/api/v1';
const run = Date.now().toString().slice(-7);
const mobile = (n: number) => `9${run}${n}${'0'.repeat(10 - 1 - run.length - String(n).length)}`.slice(0, 10);

let admin = ''; let sup = ''; let drv = ''; let supervisorId = ''; let driverId = ''; let adhocId = ''; let tripId = '';

// 1x1 JPEG > 1KB so the mock face service accepts it
const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(2048, 1), Buffer.from([0xff, 0xd9])]);

beforeAll(async () => { await ensureBootstrap(); });

describe('Gamya Mobility API', () => {
  it('health', async () => { const r = await request(app).get(`${api}/health`); expect(r.status).toBe(200); expect(r.body.status).toBe('ok'); });

  it('admin login', async () => {
    const r = await request(app).post(`${api}/auth/login`).send({ identifier: 'admin@gamya.com', password: process.env.ADMIN_BOOTSTRAP_PASSWORD ?? 'Admin@123' });
    expect(r.status).toBe(200); admin = r.body.data.token; expect(r.body.data.user.role).toBe('ADMIN');
  });

  it('rejects bad credentials and missing token', async () => {
    expect((await request(app).post(`${api}/auth/login`).send({ identifier: 'admin@gamya.com', password: 'nope' })).status).toBe(401);
    expect((await request(app).get(`${api}/dashboard`)).status).toBe(401);
  });

  it('supervisor registers, verifies face, is pending, then approved by admin', async () => {
    const r = await request(app).post(`${api}/auth/register/supervisor`).send({ fullName: 'Test Supervisor', companyName: 'Test Corp', employeeId: 'E1', mobile: mobile(1), email: `sup${run}@test.com`, password: 'secret1', acceptTerms: true });
    expect(r.status).toBe(201); sup = r.body.data.token; supervisorId = r.body.data.user.supervisor.id; expect(r.body.data.user.status).toBe('PENDING');
    const f = await request(app).post(`${api}/auth/face-verify`).set('authorization', `Bearer ${sup}`).attach('selfie', jpeg, 'selfie.jpg');
    expect(f.status).toBe(200); expect(f.body.data.matched).toBe(true);
    // cannot post requirement while pending
    expect((await request(app).post(`${api}/adhoc`).set('authorization', `Bearer ${sup}`).send({ fromLocation: 'Alpha', toLocation: 'Beta', scheduledAt: new Date().toISOString(), vehicleType: 'SEDAN' })).status).toBe(403);
    const list = await request(app).get(`${api}/approvals?category=supervisors&status=PENDING&q=Test%20Supervisor`).set('authorization', `Bearer ${admin}`);
    const req = list.body.data.items.find((x: any) => x.supervisor?.id === supervisorId); expect(req).toBeTruthy();
    const ok = await request(app).post(`${api}/approvals/${req.id}/approve`).set('authorization', `Bearer ${admin}`).send({ remarks: 'ok' });
    expect(ok.status).toBe(200); expect(ok.body.data.status).toBe('APPROVED');
    const me = await request(app).get(`${api}/supervisor/profile`).set('authorization', `Bearer ${sup}`); expect(me.body.data.status).toBe('ACTIVE');
  });

  it('driver registers, uploads vehicle + docs, submits, gets approved', async () => {
    const r = await request(app).post(`${api}/auth/register/driver`).send({ fullName: 'Test Driver', mobile: mobile(2), email: `drv${run}@test.com`, password: 'secret1', dateOfBirth: '1990-01-01', address: 'Hyd' });
    expect(r.status).toBe(201); drv = r.body.data.token; driverId = r.body.data.user.driver.id;
    expect((await request(app).post(`${api}/auth/face-verify`).set('authorization', `Bearer ${drv}`).attach('selfie', jpeg, 's.jpg')).body.data.matched).toBe(true);
    expect((await request(app).post(`${api}/driver/submit`).set('authorization', `Bearer ${drv}`)).status).toBe(400); // vehicle missing
    const v = await request(app).post(`${api}/driver/vehicle`).set('authorization', `Bearer ${drv}`).send({ number: `TS99T${run.slice(-4)}`, make: 'Toyota', model: 'Etios', year: 2022, type: 'SEDAN' });
    expect(v.status).toBe(201);
    const ph = await request(app).post(`${api}/driver/vehicle/photos`).set('authorization', `Bearer ${drv}`).attach('photos', jpeg, 'a.jpg').attach('photos', jpeg, 'b.jpg');
    expect(ph.status).toBe(201); expect(ph.body.data.length).toBe(2);
    for (const type of ['RC', 'PERMIT', 'INSURANCE', 'DRIVING_LICENCE']) expect((await request(app).post(`${api}/driver/documents`).set('authorization', `Bearer ${drv}`).field('type', type).attach('file', jpeg, `${type}.jpg`)).status).toBe(201);
    const st = await request(app).get(`${api}/driver/status`).set('authorization', `Bearer ${drv}`); expect(st.body.data.documents).toBe('SUBMITTED'); expect(st.body.data.faceVerification).toBe('COMPLETED');
    expect((await request(app).post(`${api}/driver/submit`).set('authorization', `Bearer ${drv}`)).status).toBe(200);
    const list = await request(app).get(`${api}/approvals?category=drivers&status=PENDING`).set('authorization', `Bearer ${admin}`);
    const req = list.body.data.items.find((x: any) => x.driver?.id === driverId); expect(req).toBeTruthy(); expect(req.driver.faceVerified).toBe(true);
    expect((await request(app).post(`${api}/approvals/${req.id}/approve`).set('authorization', `Bearer ${admin}`).send({})).status).toBe(200);
    const d = await request(app).get(`${api}/drivers/${driverId}`).set('authorization', `Bearer ${admin}`);
    expect(d.body.data.status).toBe('ACTIVE'); expect(d.body.data.docs.verified).toBe(7); expect(d.body.data.vehicle.status).toBe('ACTIVE');
  });

  it('supervisor posts requirement → admin assigns → driver accepts, starts, completes → earnings', async () => {
    const est = await request(app).post(`${api}/adhoc/estimate`).set('authorization', `Bearer ${sup}`).send({ vehicleType: 'SEDAN' }); expect(est.body.data.estimatedAmount).toBe(950);
    const a = await request(app).post(`${api}/adhoc`).set('authorization', `Bearer ${sup}`).send({ fromLocation: 'Mindspace, Hitech City', toLocation: 'Raheja IT Park, Gachibowli', scheduledAt: new Date(Date.now() + 3600e3).toISOString(), loginTime: '09:00', reportingTime: '08:30', vehicleType: 'SEDAN', modelYearMin: 2022, bookingType: 'INSTANT', platformCode: 'ROUTEMATIC' });
    expect(a.status).toBe(201); adhocId = a.body.data.id; expect(a.body.data.code).toMatch(/^ADH-\d{8}-\d{3}$/); expect(a.body.data.platform.name).toBe('Routematic');
    // driver sees it as open
    const avail = await request(app).get(`${api}/trips/available`).set('authorization', `Bearer ${drv}`); expect(avail.body.data.open.some((x: any) => x.id === adhocId)).toBe(true);
    const vehicleId = (await request(app).get(`${api}/driver/profile`).set('authorization', `Bearer ${drv}`)).body.data.vehicles[0].id;
    const asg = await request(app).post(`${api}/adhoc/${adhocId}/assign`).set('authorization', `Bearer ${admin}`).send({ vehicleId });
    expect(asg.status).toBe(200); expect(asg.body.data.status).toBe('ASSIGNED'); tripId = asg.body.data.trip.id;
    expect((await request(app).get(`${api}/trips/available`).set('authorization', `Bearer ${drv}`)).body.data.assigned.some((x: any) => x.id === tripId)).toBe(true);
    const acc = await request(app).post(`${api}/trips/${tripId}/accept`).set('authorization', `Bearer ${drv}`); expect(acc.status).toBe(200); expect(acc.body.data.status).toBe('ACCEPTED');
    expect(acc.body.data.events.map((e: any) => e.type)).toEqual(['REQUIREMENT_POSTED', 'VENDOR_ASSIGNED', 'DRIVER_ACCEPTED', 'TRIP_CREATED_IN_PLATFORM']);
    // supervisor tracking view
    const track = await request(app).get(`${api}/adhoc/${adhocId}`).set('authorization', `Bearer ${sup}`); expect(track.body.data.trip.status).toBe('ACCEPTED');
    expect((await request(app).post(`${api}/trips/${tripId}/start`).set('authorization', `Bearer ${drv}`).send({ externalTripId: 'RM-1' })).body.data.status).toBe('ON_TRIP');
    const done = await request(app).post(`${api}/trips/${tripId}/complete`).set('authorization', `Bearer ${drv}`).send({ distanceKm: 12 }); expect(done.body.data.status).toBe('COMPLETED'); expect(done.body.data.amount).toBe(950);
    const earn = await request(app).get(`${api}/driver/earnings`).set('authorization', `Bearer ${drv}`); expect(earn.body.data.allTime).toBe(950);
    expect((await request(app).get(`${api}/adhoc/${adhocId}`).set('authorization', `Bearer ${admin}`)).body.data.status).toBe('COMPLETED');
    // driver cannot access admin routes
    expect((await request(app).get(`${api}/drivers`).set('authorization', `Bearer ${drv}`)).status).toBe(403);
  });

  it('bookings: create, confirm (creates trip), export csv', async () => {
    const vehicle = await prisma.vehicle.findFirstOrThrow({ where: { driverId } });
    const b = await request(app).post(`${api}/bookings`).set('authorization', `Bearer ${admin}`).send({ date: new Date().toISOString(), employeeName: 'Emp One', clientName: 'Test Corp', fromLocation: 'A', toLocation: 'B', vehicleType: 'SEDAN', vehicleId: vehicle.id, driverId });
    expect(b.status).toBe(201); expect(b.body.data.code).toMatch(/^BK-/);
    const c = await request(app).post(`${api}/bookings/${b.body.data.id}/confirm`).set('authorization', `Bearer ${admin}`); expect(c.body.data.status).toBe('CONFIRMED'); expect(c.body.data.trip).toBeTruthy();
    const csv = await request(app).get(`${api}/bookings/export`).set('authorization', `Bearer ${admin}`); expect(csv.headers['content-type']).toContain('text/csv'); expect(csv.text).toContain('Booking ID');
  });

  it('payments: settlement for driver and pay', async () => {
    const s = await request(app).post(`${api}/payments/settlements`).set('authorization', `Bearer ${admin}`).send({ driverId }); expect(s.status).toBe(201); expect(Number(s.body.data.totalAmount)).toBe(950);
    expect((await request(app).post(`${api}/payments/settlements/${s.body.data.id}/pay`).set('authorization', `Bearer ${admin}`).send({ reference: 'UTR1' })).status).toBe(200);
    const e = await request(app).get(`${api}/driver/earnings`).set('authorization', `Bearer ${drv}`); expect(e.body.data.pending).toBe(0);
  });

  it('notifications & reports', async () => {
    const n = await request(app).get(`${api}/notifications`).set('authorization', `Bearer ${drv}`); expect(n.body.data.items.length).toBeGreaterThan(0);
    expect((await request(app).post(`${api}/notifications/read-all`).set('authorization', `Bearer ${drv}`)).status).toBe(200);
    const rep = await request(app).get(`${api}/reports/summary`).set('authorization', `Bearer ${admin}`); expect(rep.body.data.trips).toBeGreaterThan(0);
    const csv = await request(app).get(`${api}/reports/export?type=drivers`).set('authorization', `Bearer ${admin}`); expect(csv.text).toContain('Test Driver');
  });
});
