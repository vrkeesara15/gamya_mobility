# Gamya Mobility

**GAMYA MOBILITY PVT LTD — On Time. Every Time.**

Fleet & trip operations platform for corporate employee transport: a web admin panel, an Android app for
drivers and client supervisors, and a Node.js API — built with Flutter and Node.js and hosted on Google Cloud.

| App | Path | Stack |
|---|---|---|
| REST API | `backend/` | Node.js 22 · Express · Prisma · PostgreSQL · JWT · Cloud Storage |
| Admin web panel | `apps/admin_web/` | Flutter web · Riverpod · go_router |
| Driver + Supervisor Android app | `apps/mobile/` | Flutter · camera · image_picker · url_launcher |
| Shared Flutter package | `packages/gamya_core/` | theme, logo, API client, models, charts, widgets |
| Cloud deployment | `infra/` | Cloud Run · Cloud SQL · Cloud Storage · Cloud Build |

Full feature list: [REQUIREMENTS.md](REQUIREMENTS.md) · Work log: [TASKS.md](TASKS.md)

## Features

**Admin panel** – Dashboard, Supervisor Management, Driver Management, Vehicle Management, Pending Approvals
(with selfie / facial-verification review), Ad-hoc Requirements, Booking Management, Live Trips, Completed Trips,
Platform Management (Routematic, MoveInSync, WhistleDrive, Uber for Business, Other), Payments & Settlement,
Reports & Analytics (CSV export), Notifications (broadcast), Admin Users, Settings (company, tariffs, document
rules, locations, clients).

**Supervisor app** – Registration → facial identification → vendor-owner approval → login; dashboard; post
requirement (vehicle, timings, pickup/drop, instant/scheduled) → choose trip-tracking platform → summary → confirm;
live tracking timeline (Requirement Posted → Vendor Assigned → Driver Accepted → Trip Created in platform →
Driver Started → Trip Completed); my bookings, history, reports, profile, support.

**Driver app** – Registration → facial identification → vehicle & documents (RC, Permit, Insurance, Driving
Licence, 2 vehicle photos) → admin approval; dashboard; notifications; trip requests with accept / decline;
accepted trip with "Open in <platform>"; start / complete trip; my trips; earnings (week / month / all time);
documents & renewals; profile; help & support.

## Run locally

Prerequisites: Node 20+, Docker (for PostgreSQL), Flutter 3.27+ (web + Android toolchain).

```bash
# 1. Database + API
cd backend
cp .env.example .env                 # defaults point at the docker Postgres on port 5433
docker compose up -d db
npm install
npx prisma migrate deploy
npm run db:seed                      # demo data mirroring the design screenshots
npm run dev                          # http://localhost:8080/api/v1/health

# 2. Admin web
cd apps/admin_web
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api/v1
#   or: flutter build web --release && python3 -m http.server 5000 -d build/web

# 3. Android app (emulator reaches the host API on 10.0.2.2)
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Demo logins after seeding:

| Role | Login | Password |
|---|---|---|
| Super Admin | `admin@gamya.com` | `Admin@123` |
| Supervisor | `anil.kumar@gamya.com` | `Gamya@123` |
| Driver | `ramesh.kumar0@gmail.com` | `Gamya@123` |

## Tests

```bash
cd backend && npm test          # end-to-end API suite (registration → approval → trip → settlement)
cd apps/admin_web && flutter analyze
cd apps/mobile && flutter analyze
```

## Deploy to Google Cloud

See [infra/README.md](infra/README.md). In short: `./infra/setup-gcp.sh` once, then
`gcloud builds submit --config infra/cloudbuild.yaml ...` for each release (API → Cloud Run, admin web → Cloud
Storage), and `./infra/build-android.sh` for the Play Store build.

## API overview

All routes are under `/api/v1` and return `{ success, data }`.

| Area | Routes |
|---|---|
| Auth | `POST /auth/login`, `/auth/register/driver`, `/auth/register/supervisor`, `/auth/face-verify`, `/auth/forgot-password`, `/auth/reset-password`, `GET /auth/me` |
| Admin | `/dashboard`, `/supervisors`, `/drivers`, `/vehicles`, `/approvals`, `/adhoc`, `/bookings`, `/trips`, `/payments`, `/reports`, `/notifications`, `/platforms`, `/clients`, `/locations`, `/settings`, `/admin-users`, `/activity` |
| Driver app | `/driver/profile`, `/driver/vehicle`, `/driver/vehicle/photos`, `/driver/documents`, `/driver/submit`, `/driver/status`, `/driver/dashboard`, `/driver/earnings`, `/trips/available`, `/trips/:id/accept|decline|start|complete`, `/trips/adhoc/:id/accept` |
| Supervisor app | `/supervisor/profile`, `/supervisor/dashboard`, `/supervisor/reports`, `/adhoc` (own requests), `/adhoc/estimate`, `/adhoc/:id/cancel` |

Configuration is via environment variables — see `backend/.env.example` (storage driver, face-verification
driver, FCM push, CORS, JWT).
