import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import 'core/providers.dart';
import 'features/auth/welcome_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/auth/face_page.dart';
import 'features/auth/pending_page.dart';
import 'features/auth/approved_page.dart';
import 'features/auth/forgot_page.dart';
import 'features/common/notifications_page.dart';
import 'features/common/profile_page.dart';
import 'features/common/support_page.dart';
import 'features/supervisor/sup_dashboard_page.dart';
import 'features/supervisor/post_requirement_page.dart';
import 'features/supervisor/booking_summary_page.dart';
import 'features/supervisor/booking_confirmed_page.dart';
import 'features/supervisor/booking_tracking_page.dart';
import 'features/supervisor/my_bookings_page.dart';
import 'features/supervisor/sup_reports_page.dart';
import 'features/driver/drv_dashboard_page.dart';
import 'features/driver/vehicle_documents_page.dart';
import 'features/driver/available_trips_page.dart';
import 'features/driver/trip_details_page.dart';
import 'features/driver/trip_accepted_page.dart';
import 'features/driver/my_trips_page.dart';
import 'features/driver/trip_completed_page.dart';
import 'features/driver/earnings_page.dart';
import 'features/driver/documents_page.dart';

/// Where a logged-in user should land based on role + onboarding state.
String homeFor(AuthUser u) {
  if (u.isSupervisor) {
    if (!u.faceVerified) return '/face';
    if (u.status != 'ACTIVE') return '/pending';
    return '/sup';
  }
  if (u.isDriver) {
    if (!u.faceVerified) return '/face';
    if (u.status == 'ACTIVE') return '/drv';
    return '/drv/onboarding';
  }
  return '/welcome';
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<AuthUser?>(ref.read(sessionProvider));
  ref.listen(sessionProvider, (_, next) => session.value = next);
  const public = {'/welcome', '/login', '/register', '/forgot'};
  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: session,
    redirect: (ctx, state) {
      final u = session.value; final loc = state.matchedLocation;
      if (u == null) return public.contains(loc) ? null : '/welcome';
      if (public.contains(loc)) return homeFor(u);
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(path: '/face', builder: (_, __) => const FacePage()),
      GoRoute(path: '/pending', builder: (_, __) => const PendingPage()),
      GoRoute(path: '/approved', builder: (_, __) => const ApprovedPage()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(path: '/support', builder: (_, __) => const SupportPage()),
      // supervisor
      GoRoute(path: '/sup', builder: (_, __) => const SupDashboardPage()),
      GoRoute(path: '/sup/post', builder: (_, __) => const PostRequirementPage()),
      GoRoute(path: '/sup/summary', builder: (_, s) => BookingSummaryPage(draft: s.extra as Map<String, dynamic>)),
      GoRoute(path: '/sup/confirmed/:id', builder: (_, s) => BookingConfirmedPage(id: s.pathParameters['id']!)),
      GoRoute(path: '/sup/track/:id', builder: (_, s) => BookingTrackingPage(id: s.pathParameters['id']!)),
      GoRoute(path: '/sup/bookings', builder: (_, s) => MyBookingsPage(initialTab: s.uri.queryParameters['tab'])),
      GoRoute(path: '/sup/reports', builder: (_, __) => const SupReportsPage()),
      // driver
      GoRoute(path: '/drv', builder: (_, __) => const DrvDashboardPage()),
      GoRoute(path: '/drv/onboarding', builder: (_, __) => const VehicleDocumentsPage()),
      GoRoute(path: '/drv/available', builder: (_, __) => const AvailableTripsPage()),
      GoRoute(path: '/drv/trip/:id', builder: (_, s) => TripDetailsPage(id: s.pathParameters['id']!, adhoc: s.uri.queryParameters['adhoc'] == '1')),
      GoRoute(path: '/drv/accepted/:id', builder: (_, s) => TripAcceptedPage(id: s.pathParameters['id']!)),
      GoRoute(path: '/drv/trips', builder: (_, s) => MyTripsPage(initialTab: s.uri.queryParameters['tab'])),
      GoRoute(path: '/drv/completed/:id', builder: (_, s) => TripCompletedPage(id: s.pathParameters['id']!)),
      GoRoute(path: '/drv/earnings', builder: (_, __) => const EarningsPage()),
      GoRoute(path: '/drv/documents', builder: (_, __) => const DocumentsPage()),
    ],
  );
});

class GamyaMobileApp extends ConsumerWidget {
  const GamyaMobileApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(title: 'Gamya Mobility', debugShowCheckedModeBanner: false, theme: GamyaTheme.light(), routerConfig: ref.watch(routerProvider));
}
