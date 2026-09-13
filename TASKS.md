# Gamya Mobility — Task Board

Status legend: [ ] todo · [~] in progress · [x] done (verified & committed)

## Phase 0 — Foundation
- [x] T00 Repo skeleton, README, .gitignore, REQUIREMENTS.md, TASKS.md
- [x] T01 Backend scaffold: Express + Prisma + PostgreSQL, config, logging, error handling, docker-compose
- [x] T02 Prisma schema for all entities + migrations + seed data mirroring screenshots
- [x] T03 Auth: register (driver/supervisor), login (admin/driver/supervisor), JWT, RBAC middleware, password reset
- [x] T04 File upload service (GCS with local fallback), face-verification service abstraction

## Phase 1 — Backend APIs
- [x] T10 Supervisors API (CRUD, locations, stats, activities, reset password)
- [x] T11 Drivers API (CRUD, documents, vehicle link, stats, performance, status changes, blacklist)
- [x] T12 Vehicles API (CRUD, documents, compliance, photos, stats, bulk upload)
- [x] T13 Approvals API (list by type, approve/reject with remarks, stats, trends)
- [x] T14 Ad-hoc Requirements API (CRUD, assign vehicle/driver, costing, activity log, stats, trends)
- [x] T15 Bookings API (CRUD, confirm/cancel/assign, import/export CSV, stats, trends)
- [x] T16 Trips API (live, completed, timeline events, driver accept/decline/start/complete, earnings)
- [x] T17 Platforms, Clients, Locations, Settings, Admin Users APIs
- [x] T18 Payments & Settlement API, Reports & Analytics API, Notifications API (in-app + FCM hook)
- [x] T19 Dashboard aggregate API; backend test suite (supertest) green

## Phase 2 — Shared Flutter package
- [x] T20 `packages/gamya_core`: theme (colours, typography), logo widget, API client (dio), auth storage, models, common widgets (stat card, status chip, platform chip, donut/bar charts)

## Phase 3 — Admin Web (Flutter Web)
- [x] T30 App shell: sidebar, top bar, footer, routing (go_router), login page
- [x] T31 Dashboard page
- [x] T32 Supervisor Management page (+ detail panel, add/edit dialog)
- [x] T33 Driver Management page (+ detail panel, add/edit dialog)
- [x] T34 Vehicle Management page (+ detail panel, add/edit, bulk upload)
- [x] T35 Pending Approvals page (+ face verification panel, approve/reject)
- [x] T36 Ad-hoc Requirements page (+ detail, assign, new request)
- [x] T37 Booking Management page (+ detail, new booking, import/export)
- [x] T38 Live Trips & Completed Trips pages
- [x] T39 Platform Mgmt, Payments & Settlement, Reports & Analytics, Notifications, Admin Users, Settings pages
- [x] T3A Admin web builds (`flutter build web`) and passes `flutter analyze`

## Phase 4 — Mobile App (Flutter Android; Driver + Supervisor)
- [x] T40 App shell: splash, role selection, auth flow, routing, Android config (package id, icons, permissions)
- [x] T41 Supervisor: registration, facial identification, pending approval, login
- [x] T42 Supervisor: dashboard, post requirement (3-step), summary, confirmation, tracking timeline, my bookings, history, profile, support
- [x] T43 Driver: registration, facial identification, vehicle & documents upload (3-step), pending approval, approved
- [x] T44 Driver: dashboard, notifications, trip details accept/decline, accepted trip, my trips, trip completed, earnings, documents, profile, help
- [ ] T45 Mobile app passes `flutter analyze`; Android build config verified

## Phase 5 — Infra & Delivery
- [ ] T50 Backend Dockerfile, cloudbuild.yaml, Cloud Run + Cloud SQL deploy script, GCS static hosting script for admin web, env templates
- [ ] T51 README with setup, run, test and deploy instructions; CLAUDE.md for future agents
- [ ] T52 End-to-end smoke: seed DB, run backend, hit APIs from admin web build and mobile flows
