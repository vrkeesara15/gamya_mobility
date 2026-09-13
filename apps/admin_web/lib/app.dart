import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import 'core/providers.dart';
import 'shell/app_shell.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/supervisors/supervisors_page.dart';
import 'features/drivers/drivers_page.dart';
import 'features/vehicles/vehicles_page.dart';
import 'features/approvals/approvals_page.dart';
import 'features/adhoc/adhoc_page.dart';
import 'features/bookings/bookings_page.dart';
import 'features/trips/trips_page.dart';
import 'features/platforms/platforms_page.dart';
import 'features/payments/payments_page.dart';
import 'features/reports/reports_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/admin_users/admin_users_page.dart';
import 'features/settings/settings_page.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon, {this.badge = false});
  final String path; final String label; final IconData icon; final bool badge;
}

const navItems = [
  NavItem('/dashboard', 'Dashboard', Icons.dashboard_outlined),
  NavItem('/supervisors', 'Supervisor Management', Icons.supervisor_account_outlined),
  NavItem('/drivers', 'Driver Management', Icons.person_outline),
  NavItem('/vehicles', 'Vehicle Management', Icons.directions_car_outlined),
  NavItem('/approvals', 'Pending Approvals', Icons.verified_user_outlined, badge: true),
  NavItem('/adhoc', 'Ad-hoc Requirements', Icons.add_box_outlined),
  NavItem('/bookings', 'Booking Management', Icons.event_note_outlined),
  NavItem('/live-trips', 'Live Trips', Icons.navigation_outlined),
  NavItem('/completed-trips', 'Completed Trips', Icons.check_box_outlined),
  NavItem('/platforms', 'Platform Management', Icons.hub_outlined),
  NavItem('/payments', 'Payments & Settlement', Icons.account_balance_wallet_outlined),
  NavItem('/reports', 'Reports & Analytics', Icons.bar_chart_outlined),
  NavItem('/notifications', 'Notifications', Icons.notifications_outlined),
  NavItem('/admin-users', 'Admin Users', Icons.manage_accounts_outlined),
  NavItem('/settings', 'Settings', Icons.settings_outlined),
];

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<AuthUser?>(ref.read(sessionProvider));
  ref.listen(sessionProvider, (_, next) => session.value = next);
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: session,
    redirect: (ctx, state) {
      final loggedIn = session.value != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn && !atLogin) return '/login?next=${Uri.encodeComponent(state.uri.toString())}';
      if (loggedIn && atLogin) return state.uri.queryParameters['next'] ?? '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/supervisors', builder: (_, s) => SupervisorsPage(selectId: s.uri.queryParameters['id'])),
          GoRoute(path: '/drivers', builder: (_, s) => DriversPage(selectId: s.uri.queryParameters['id'])),
          GoRoute(path: '/vehicles', builder: (_, s) => VehiclesPage(selectId: s.uri.queryParameters['id'])),
          GoRoute(path: '/approvals', builder: (_, s) => ApprovalsPage(selectId: s.uri.queryParameters['id'], category: s.uri.queryParameters['tab'])),
          GoRoute(path: '/adhoc', builder: (_, s) => AdhocPage(selectId: s.uri.queryParameters['id'])),
          GoRoute(path: '/bookings', builder: (_, s) => BookingsPage(selectId: s.uri.queryParameters['id'])),
          GoRoute(path: '/live-trips', builder: (_, s) => TripsPage(view: 'live', selectId: s.uri.queryParameters['id'])),
          GoRoute(path: '/completed-trips', builder: (_, s) => TripsPage(view: 'completed', selectId: s.uri.queryParameters['id'])),
          GoRoute(path: '/platforms', builder: (_, __) => const PlatformsPage()),
          GoRoute(path: '/payments', builder: (_, __) => const PaymentsPage()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsPage()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
          GoRoute(path: '/admin-users', builder: (_, __) => const AdminUsersPage()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        ],
      ),
    ],
  );
});

class GamyaAdminApp extends ConsumerWidget {
  const GamyaAdminApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Gamya Mobility Admin',
        debugShowCheckedModeBanner: false,
        theme: GamyaTheme.light().copyWith(pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: _NoTransitions(), TargetPlatform.iOS: _NoTransitions(), TargetPlatform.macOS: _NoTransitions(), TargetPlatform.windows: _NoTransitions(), TargetPlatform.linux: _NoTransitions()})),
        routerConfig: ref.watch(routerProvider),
        scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars: true),
      );
}

/// Admin pages switch instantly (no slide) – feels snappier for a desktop tool.
class _NoTransitions extends PageTransitionsBuilder {
  const _NoTransitions();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => child;
}
