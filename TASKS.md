# Gamya Mobility — Task Board

Status legend: [ ] todo · [~] in progress · [x] done (verified & committed)

## Phase 0 — Foundation
- [ ] T00 Repo skeleton, README, .gitignore, REQUIREMENTS.md, TASKS.md
- [ ] T01 Backend scaffold: Express + Prisma + PostgreSQL, config, logging, error handling, docker-compose
- [ ] T02 Prisma schema for all entities + migrations + seed data mirroring screenshots
- [ ] T03 Auth: register (driver/supervisor), login (admin/driver/supervisor), JWT, RBAC middleware, password reset
- [ ] T04 File upload service (GCS with local fallback), face-verification service abstraction

## Phase 1 — Backend APIs
- [ ] T10 Supervisors API (CRUD, locations, stats, activities, reset password)
- [ ] T11 Drivers API (CRUD, documents, vehicle link, stats, performance, status changes, blacklist)
- [ ] T12 Vehicles API (CRUD, documents, compliance, photos, stats, bulk upload)
- [ ] T13 Approvals API (list by type, approve/reject with remarks, stats, trends)
- [ ] T14 Ad-hoc Requirements API (CRUD, assign vehicle/driver, costing, activity log, stats, trends)
- [ ] T15 Bookings API (CRUD, confirm/cancel/assign, import/export CSV, stats, trends)
- [ ] T16 Trips API (live, completed, timeline events, driver accept/decline/start/complete, earnings)
- [ ] T17 Platforms, Clients, Locations, Settings, Admin Users APIs
- [ ] T18 Payments & Settlement API, Reports & Analytics API, Notifications API (in-app + FCM hook)
- [ ] T19 Dashboard aggregate API; backend test suite (supertest) green

## Phase 2 — Shared Flutter package
- [ ] T20 `packages/gamya_core`: theme (colours, typography), logo widget, API client (dio), auth storage, models, common widgets (stat card, status chip, platform chip, donut/bar charts)

## Phase 3 — Admin Web (Flutter Web)
- [ ] T30 App shell: sidebar, top bar, footer, routing (go_router), login page
- [ ] T31 Dashboard page
- [ ] T32 Supervisor Management page (+ detail panel, add/edit dialog)
- [ ] T33 Driver Management page (+ detail panel, add/edit dialog)
- [ ] T34 Vehicle Management page (+ detail panel, add/edit, bulk upload)
- [ ] T35 Pending Approvals page (+ face verification panel, approve/reject)
- [ ] T36 Ad-hoc Requirements page (+ detail, assign, new request)
- [ ] T37 Booking Management page (+ detail, new booking, import/export)
- [ ] T38 Live Trips & Completed Trips pages
- [ ] T39 Platform Mgmt, Payments & Settlement, Reports & Analytics, Notifications, Admin Users, Settings pages
- [ ] T3A Admin web builds (`flutter build web`) and passes `flutter analyze`

## Phase 4 — Mobile App (Flutter Android; Driver + Supervisor)
- [ ] T40 App shell: splash, role selection, auth flow, routing, Android config (package id, icons, permissions)
- [ ] T41 Supervisor: registration, facial identification, pending approval, login
- [ ] T42 Supervisor: dashboard, post requirement (3-step), summary, confirmation, tracking timeline, my bookings, history, profile, support
- [ ] T43 Driver: registration, facial identification, vehicle & documents upload (3-step), pending approval, approved
- [ ] T44 Driver: dashboard, notifications, trip details accept/decline, accepted trip, my trips, trip completed, earnings, documents, profile, help
- [ ] T45 Mobile app passes `flutter analyze`; Android build config verified

## Phase 5 — Infra & Delivery
- [ ] T50 Backend Dockerfile, cloudbuild.yaml, Cloud Run + Cloud SQL deploy script, GCS static hosting script for admin web, env templates
- [ ] T51 README with setup, run, test and deploy instructions; CLAUDE.md for future agents
- [ ] T52 End-to-end smoke: seed DB, run backend, hit APIs from admin web build and mobile flows
