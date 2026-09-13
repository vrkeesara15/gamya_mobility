# Gamya Mobility – notes for AI agents

Monorepo: `backend/` (Express + Prisma + Postgres, TypeScript ESM), `packages/gamya_core/` (shared Flutter
package), `apps/admin_web/` (Flutter web), `apps/mobile/` (Flutter Android, driver + supervisor in one app),
`infra/` (GCP). Requirements live in `REQUIREMENTS.md`; the task board is `TASKS.md`.

## Conventions
- API responses are `{ success, data }`; list endpoints return `{ items, total, page, pageSize, totalPages }`.
  Query filters use `q`, `status`, `page`, `pageSize`; `str()` in `utils/pagination.ts` treats `all` as unset.
- Prisma `Decimal` values are serialised as numbers (see `config/prisma.ts`). Money is INR.
- Roles: `ADMIN` (admin panel; `adminRole` SUPER_ADMIN/ADMIN/OPS), `SUPERVISOR`, `DRIVER`. Guards in
  `middleware/auth.ts`. Supervisor/driver routes are scoped to the caller's own records.
- Every mutation writes an `ActivityLog` row (`utils/activity.ts`) and, where a person is affected, a
  `Notification` (`services/notifications.ts`; FCM push is optional).
- Trip lifecycle: `ASSIGNED → ACCEPTED → (YET_TO_START) → ON_TRIP | DELAYED → COMPLETED`, plus `CANCELLED`.
  `TripEvent`s drive the 6-step tracking timeline (`TrackingTimeline.fromTrip` in gamya_core).
- Ad-hoc request lifecycle: `PENDING → ASSIGNED → ACCEPTED → IN_PROGRESS → COMPLETED`, plus `CANCELLED`.
- Flutter: models in `gamya_core` are thin JSON wrappers (`raw` map + typed getters). Brand colours in
  `GamyaColors`; status colours via `GamyaColors.status()`. Use `Fmt` for dates / currency.
- Admin pages follow one pattern: `PageHeader` → `StatGrid` → `FilterBar` → `GTable` + `PaginationBar` →
  charts; a right-hand `DetailPanel` with tabs. Don't put `LayoutBuilder` inside `IntrinsicHeight`.
- Mobile pages use `PageScaffold` / `AuthScaffold`; navigation with go_router (`/sup/...`, `/drv/...`).

## Commands
- Backend: `npm run dev`, `npm test` (needs the docker Postgres from `docker-compose.yml`, port 5433),
  `npm run db:seed`, `npx prisma migrate dev`.
- Flutter: `flutter analyze` in each app/package; `flutter build web --release` (admin);
  `flutter build apk --release --dart-define=API_BASE_URL=...` (mobile).
- Keep `flutter analyze` and `tsc --noEmit` clean before committing.
