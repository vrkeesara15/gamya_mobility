import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

/// Supervisor: "Pending Approval – awaiting approval from the vendor owner."
/// Driver: "Registration Submitted – under review by Gamya Mobility Admin."
class PendingPage extends ConsumerStatefulWidget {
  const PendingPage({super.key});
  @override
  ConsumerState<PendingPage> createState() => _PendingPageState();
}

class _PendingPageState extends ConsumerState<PendingPage> {
  Timer? _timer; Map<String, dynamic>? _driverStatus;
  @override
  void initState() { super.initState(); _check(); _timer = Timer.periodic(const Duration(seconds: 20), (_) => _check()); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  Future<void> _check() async {
    final u = await refreshSession(ref);
    if (!mounted || u == null) return;
    if (u.status == 'ACTIVE') { context.go('/approved'); return; }
    if (u.status == 'REJECTED') return;
    if (u.isDriver) { try { final api = ref.read(apiProvider); final r = await api.get('/driver/status'); if (mounted) setState(() => _driverStatus = api.data(r)); } catch (_) {} }
  }
  @override
  Widget build(BuildContext context) {
    final u = ref.watch(sessionProvider)!;
    final rejected = u.status == 'REJECTED';
    final sup = u.isSupervisor;
    return AuthScaffold(headerHeight: 150, showTagline: false, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      SuccessHeader(icon: rejected ? Icons.close : Icons.hourglass_bottom, color: rejected ? GamyaColors.danger : GamyaColors.dark, title: rejected ? 'Registration Rejected' : sup ? 'Pending Approval' : 'Registration Submitted!', subtitle: rejected ? 'Your registration was not approved. Please contact Gamya Mobility support.' : sup ? 'Your registration is submitted and awaiting approval from the vendor owner.' : 'Your details and documents are under review by Gamya Mobility Admin.'),
      const SizedBox(height: 22),
      if (sup) InfoCard(children: [InfoRow('Supervisor Name', u.fullName, icon: Icons.person_outline), InfoRow('Company', u.companyName, icon: Icons.business_outlined), InfoRow('Submitted On', Fmt.date(DateTime.now()), icon: Icons.calendar_today_outlined)])
      else InfoCard(children: [for (final e in {'driverDetails': 'Driver Details', 'vehicleDetails': 'Vehicle Details', 'documents': 'Documents', 'faceVerification': 'Face Verification'}.entries) InfoRow(e.value, null, icon: e.key == 'driverDetails' ? Icons.person_outline : e.key == 'vehicleDetails' ? Icons.directions_car_outlined : e.key == 'documents' ? Icons.description_outlined : Icons.face, valueWidget: Align(alignment: Alignment.centerRight, child: StatusChip(_driverStatus?[e.key] as String? ?? 'SUBMITTED', small: true, dot: false)))]),
      if (!rejected) const NoteBox('You will be notified once your account is approved.', icon: Icons.check_circle_outline, color: GamyaColors.gold),
      const SizedBox(height: 18),
      OutlineButton(label: 'Refresh Status', icon: Icons.refresh, expand: true, onPressed: _check), const SizedBox(height: 8),
      if (!sup && !rejected) OutlineButton(label: 'Edit Vehicle & Documents', icon: Icons.edit_outlined, expand: true, onPressed: () => context.go('/drv/onboarding')),
      TextButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: const Text('Logout', style: TextStyle(color: GamyaColors.textSecondary))),
      const SizedBox(height: 4), Center(child: Text('Need help? ${GamyaBrand.supportPhone}', style: const TextStyle(fontSize: 12, color: GamyaColors.textMuted))),
      const SizedBox(height: 0), if (u.status == 'ACTIVE') TextButton(onPressed: () => context.go(homeFor(u)), child: const Text('Continue')),
    ]));
  }
}
