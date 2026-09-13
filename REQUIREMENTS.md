# Gamya Mobility — Requirements Specification

Extracted from the client's requirement screenshots (WhatsApp images, 11 Sep 2026) and the
brief: Trip management, Driver management, Vehicle management, Staff (Supervisor / Admin)
management. Web admin panel + Android app. Stack: Flutter + Node.js. Hosted on Google Cloud.

## 1. Brand

| Item | Value |
|---|---|
| Company | GAMYA MOBILITY PVT LTD |
| Tagline | On Time. Every Time. |
| Secondary taglines | Moving People Forward · Safe Rides, Better Tomorrow · Safe Drivers, Reliable Rides, Better Tomorrow · Reliable Transport Solutions for a Better Tomorrow · Empowering Drivers / Enabling Businesses / Connecting People · Drive Safe, Earn Better, Grow Together · Drive / Earn / Grow with Gamya |
| Logo | Gold "G" formed by a road with a location pin; word-mark "G A M Y A" with "MOBILITY" beneath |
| Primary (gold) | `#B8862B` (buttons, active nav, accents), light gold `#D4AF37`, dark gold `#8C6A1E` |
| Dark | `#111111` sidebar / header, `#1A1A1A` cards on dark |
| Surface | `#F5F5F7` page background, `#FFFFFF` cards, cream footer `#F5F0E6` |
| Text | `#1F2937` primary, `#6B7280` secondary |
| Status | Success `#16A34A`, Danger `#DC2626`, Warning `#F59E0B`, Info `#2563EB`, Neutral `#9CA3AF` |
| Platforms | Routematic (green), MoveInSync (blue), WhistleDrive (yellow), Uber for Business (black), Other (grey) |

## 2. Roles

- **Super Admin / Admin** – web panel, full control.
- **Supervisor** – client-company staff (e.g. TCS, Accenture) who post transport requirements via mobile app. Must register, do facial identification, and be approved by the vendor owner (admin).
- **Driver** – registers via mobile app with selfie + vehicle + documents; approved by admin; receives ad-hoc trip requests; performs trip in a tracking platform (Routematic etc.).

## 3. Admin Web Panel (Flutter Web)

Layout: dark left sidebar with logo, navigation and a "Moving People Forward" promo block; dark top
bar with hamburger, company name + tagline, global search, notification bell with badge, admin
avatar/role menu, gold tagline ribbon; light content area; cream footer with taglines and version.

Sidebar navigation (in order): Dashboard, Supervisor Management, Driver Management, Vehicle
Management, Pending Approvals (badge count), Ad-hoc Requirements, Booking Management, Live Trips,
Completed Trips, Platform Management, Payments & Settlement, Reports & Analytics, Notifications,
Admin Users, Settings.

Common page pattern: breadcrumb, title + subtitle, primary action buttons (top-right), a row of
stat cards (icon, label, value, trend line), filter bar (search + dropdowns + Apply/Reset),
paginated data table with checkboxes and row actions (view / edit / more), a right-hand detail
panel for the selected row with tabs, and a bottom row of charts / lists.

### 3.1 Dashboard
- Date selector (top-right).
- Stat cards: Total Supervisors, Total Drivers, Total Vehicles, Ad-hoc Requirements, Active Trips, Completed Today.
- Bookings Overview: stacked bar chart last 7 days (Scheduled vs Instant/Ad-hoc).
- Platform Wise Bookings donut (Routematic, MoveInSync, WhistleDrive, Uber for Business, Other).
- Trip Status (Today) donut (On Time, Delayed, Yet to Start, Cancelled).
- Recent Ad-hoc Requirements table (Date, Vehicle Type, Pickup → Drop, Platform, Status).
- Live Trips table (Driver, Vehicle No, Platform, Route, Status).
- Pending Approvals (tabs Drivers / Supervisors; Name, Mobile, Vehicle No, Submitted On, Review).
- Recent Registrations (tabs Drivers / Supervisors; Name, Mobile, Type, Registered On, Status).

### 3.2 Supervisor Management
- Stats: Total, Active, Inactive, Total Trip Requests, Total Bookings.
- Tabs All / Active / Inactive; search; Location and Status filters; Export; Add Supervisor.
- Table: Name (avatar), Employee ID, Mobile, Email, Assigned Locations, Total Requests, Total Bookings, Status, Actions.
- Detail panel: avatar, name, SUP id, status; tabs Overview / Access & Locations / Activity; fields (Full name, Employee ID, Mobile, Email, Assigned Locations, Role, Date of Joining, Last Login); counters (Trip Requests, Total Bookings); Edit Details, Reset Password.
- Recent Supervisor Activities list; Quick Actions (Add Supervisor, Assign Locations, View Reports, Manage Access, Send Notification, Export Data).

### 3.3 Driver Management
- Stats: Total, Active, Pending Approval, Inactive, Re-Verification Due, Blacklisted.
- Filters: search, Status, Vehicle Type, Location, Platform; Export; Add Driver.
- Table: Driver Name, Photo, Mobile, Vehicle Number, Vehicle Type, Platform, Status, Documents (x/7), Actions.
- Detail panel: tabs Details / Documents / Trips / Earnings / History; Driver Information (Full name, Mobile, Email, DOB, Address, Joining date, Platform access, Status); Vehicle Information (number, make, model year, type, photos); Documents list (RC, Permit, Insurance, Driving Licence, Vehicle Photo 1, Vehicle Photo 2, Face Verification) each with Verified status; actions Mark Inactive, Blacklist, Send Notification.
- Driver Performance (last 30 days: Total trips, On time %, Delayed, Earnings); Platform-wise trips donut; Recent Activities.

### 3.4 Vehicle Management
- Stats: Total, Active, Inactive, Non-Compliant, Under Verification, Blacklisted.
- Filters: search, Status, Vehicle Type, Compliance, Platform; Export, Bulk Upload, Add Vehicle.
- Table: Vehicle Number, Photo, Make & Model, Year, Type, Assigned Driver, Platform, Compliance (x/7), Status, Actions.
- Detail panel: photo, number, make/model, type/year/colour, platform; tabs Overview / Documents / Trips / Compliance / History; fields (Assigned Driver, Supervisor, Registration Date, Fuel Type, Seating Capacity, Permit / Insurance / PUC / Fitness valid till, Current Location + View on Map); Vehicle Photos (+ Add Photo); Documents (RC, Permit, Insurance, PUC, Fitness) with Verified / View.
- Charts: Vehicle Type Distribution, Compliance Status, Vehicle Age (year-wise).

### 3.5 Pending Approvals
- Stats: Driver Approvals, Vehicle Approvals, Document Renewals, Supervisor Approvals.
- Tabs All / Drivers / Vehicles / Documents / Supervisors; Status filter; sort Oldest First; search.
- Table: Request Type, Name / Vehicle No (thumbnail), Details, Submitted On, Status, View / Approve / Reject.
- Detail panel: tabs Basic Details / Documents / Vehicle Details / Activity; Selfie / Facial Verification (Live Selfie vs Aadhaar Photo, "Face Matched" badge); Admin Remarks; Reject / Approve.
- Approval Trend chart (approved vs rejected), Pending by Type donut, Oldest Pending Requests list.

### 3.6 Ad-hoc Requirements
- Stats: Total Requests, Assigned, Pending, Cancelled, Today's Requests, Est. Revenue (month).
- Filters: date range, Client, Location, Status, Vehicle Type, search; Export; New Ad-hoc Request.
- Table: Request ID (ADH-YYYYMMDD-NNN), Date & Time, Client / Employee, From → To, No. of Pax, Vehicle Type, Status (Assigned / Pending / Completed / Cancelled), Assigned Vehicle, Actions.
- Detail panel: tabs Details / Assignment / Costing / Activity Log; fields (Client, Contact person, From, To, Date & time, Passengers, Vehicle type, Special instructions, Estimated amount); route map preview; Assign Vehicle, Edit Request, Cancel Request.
- Charts: Requests by Client, Request Status donut, Vehicle Type Wise bars, Ad-hoc Trends (14 days).

### 3.7 Booking Management
- Stats: Total Bookings, Confirmed, Pending, Cancelled, Unique Employees, Est. Revenue.
- Tabs All / Regular / Ad-hoc; filters date range, Client, Location, Status, Trip Type, search; Import Bookings, Export, New Booking.
- Table: Booking ID (BK-YYYYMMDD-NNN), Date, Employee Name, Client, Trip Type, From → To, Vehicle No, Driver Name, Status, Actions.
- Detail panel: tabs Details / Trip Details / Employee Details / Vehicle & Driver / History; Confirm Booking, Cancel Booking, Edit Booking, Assign Vehicle/Driver.
- Charts: Bookings Trend (14 days regular vs ad-hoc), Booking Status donut, Top 10 Clients, Trip Type Distribution.

### 3.8 Live Trips / Completed Trips
- Live: trips currently in progress with driver, vehicle, platform, route, start time, status (On Trip / Delayed); detail with timeline.
- Completed: history with filters, on-time flag, amount, export.

### 3.9 Platform Management
- CRUD for tracking platforms (Routematic, MoveInSync, WhistleDrive, Uber for Business, Other): name, colour, active flag, deep-link, usage stats.

### 3.10 Payments & Settlement
- Driver earnings per trip, settlement batches (pending / paid), client invoices summary.

### 3.11 Reports & Analytics
- Date-ranged reports: trips per platform, per client, driver performance, vehicle utilisation, revenue; CSV export.

### 3.12 Notifications
- Admin inbox of system notifications; send notification to drivers / supervisors (push + in-app).

### 3.13 Admin Users & Settings
- Admin user CRUD with roles (Super Admin / Admin / Ops); company profile, tariff defaults per vehicle type, document validity rules, locations master, clients master.

## 4. Supervisor Mobile App (Android, Flutter)

1. **Registration** – Full Name, Company Name, Employee ID, Mobile Number, Email ID, Create Password, agree to T&C, Sign Up, link to Login.
2. **Facial Identification** – camera preview in circular frame, instructions, Capture & Verify.
3. **Vendor Owner Approval** – pending screen showing Supervisor name, Company, Submitted on; notified on approval.
4. **Login** – Mobile/Email + Password, Forgot Password, Login with Face ID, Sign Up link.
5. **Dashboard** – greeting with name, role – company, avatar; tiles Post Your Requirement and My Bookings; counters Today's Bookings / Scheduled / Completed; menu Ongoing Trips, Booking History, Reports, My Profile, Support; promo banner.
6. **Post Your Requirement** – Vehicle type, Model year, Number of vehicles (stepper), Login time, Reporting time, Pickup location, Drop location, Booking type (Instant / Scheduled), Next.
7. **Select Trip Tracking Platform** – Routematic, MoveInSync, WhistleDrive, Uber for Business, Other (specify); Next.
8. **Booking Summary** – Vehicle details, trip details, booking type, platform, estimated amount; Confirm Booking.
9. **Booking Confirmation** – success, Request ID (#GM2026091001), summary; View Details, Go to Dashboard.
10. **Booking Tracking** – tabs Live Status / Details; timeline Requirement Posted → Vendor Assigned → Driver Accepted → Trip Created in <Platform> → Driver Started → Trip Completed; Track in <Platform> button.

## 5. Driver Mobile App (Android, Flutter)

1. **Registration** – Full Name, Mobile, Email, Date of Birth, Address, Create Password, T&C, Sign Up.
2. **Facial Identification** – same as supervisor.
3. **Vehicle & Documents** – 3-step (Vehicle Details, Upload Documents, Submit): Make, Model Year, 2 vehicle photos (required), RC, Permit, Insurance, Driving Licence uploads; Submit for Approval.
4. **Pending Admin Approval** – checklist Driver details / Vehicle details / Documents / Face verification with status.
5. **Approval Status** – Congratulations, Go to Dashboard.
6. **Driver Dashboard** – profile card (name, Driver ID GM2026xxxx, status), Today's Trips, Earnings; menu Available Trips (badge), My Trips, Documents, My Profile, Help & Support; promo banner.
7. **Notifications** – tabs All / Trip Requests / Updates.
8. **Trip Details (before accept)** – vehicle type, model year, date, login/reporting time, pickup, drop, booking type, platform, estimated amount; Decline / Accept.
9. **Accepted Trip** – Trip ID, details, "perform this trip in <Platform> app", View Details.
10. **My Trips** – tabs Ongoing / Completed / Cancelled; trip card with Open in <Platform>; upcoming trips.
11. **Trip Completed** – amount, details, Back to Home.
12. **My Earnings** – total, tabs This Week / This Month / All Time, list of trips with amount.

## 6. Backend (Node.js)

- Express REST API, JWT auth with role-based access, PostgreSQL via Prisma.
- Entities: users, admin_users, supervisors, drivers, vehicles, documents, approvals, clients,
  locations, platforms, adhoc_requests, bookings, trips, trip_events, earnings/settlements,
  notifications, activity_logs, settings.
- File uploads (documents, photos, selfies) to Google Cloud Storage (local disk fallback in dev).
- Face verification service abstraction (pluggable; default heuristic/mock that records a match score).
- Push notifications via Firebase Cloud Messaging (optional, configurable).
- Seed data mirroring the screenshots.

## 7. Hosting (Google Cloud)

- Backend: Docker image → Cloud Run; Cloud SQL (PostgreSQL); secrets via env vars.
- Admin web: `flutter build web` → Cloud Storage bucket static hosting (or Cloud Run nginx).
- Uploads bucket on Cloud Storage.
- `infra/` contains Dockerfile, cloudbuild.yaml, deploy scripts, docker-compose for local dev.
