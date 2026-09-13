import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class SupDashboardPage extends ConsumerStatefulWidget {
  const SupDashboardPage({super.key});
  @override
  ConsumerState<SupDashboardPage> createState() => _SupDashboardPageState();
}

class _SupDashboardPageState extends ConsumerState<SupDashboardPage> {
  Map<String, dynamic> _d = {}; bool _loading = true; final _key = GlobalKey<ScaffoldState>();
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final r = await api.get('/supervisor/dashboard'); if (mounted) setState(() { _d = api.data(r); _loading = false; }); } catch (e) { if (mounted) { setState(() => _loading = false); toast(context, e.msg, error: true); } } }
  @override
  Widget build(BuildContext context) {
    final u = ref.watch(sessionProvider)!;
    num n(dynamic v) => (v as num?) ?? 0;
    final recent = ((_d['recent'] as List?) ?? []).cast<Map<String, dynamic>>();
    return Scaffold(
      key: _key, backgroundColor: GamyaColors.surface,
      drawer: GamyaDrawer(name: u.fullName, subtitle: '${_d['designation'] ?? 'Supervisor'} - ${_d['companyName'] ?? u.companyName ?? ''}', avatarUrl: _d['avatarUrl'] as String?, onLogout: () => ref.read(sessionProvider.notifier).logout(), items: [
        (Icons.dashboard_outlined, 'Dashboard', () {}), (Icons.add_box_outlined, 'Post Your Requirement', () => context.push('/sup/post')), (Icons.event_note_outlined, 'My Bookings', () => context.push('/sup/bookings')), (Icons.navigation_outlined, 'Ongoing Trips', () => context.push('/sup/bookings?tab=ongoing')), (Icons.history, 'Booking History', () => context.push('/sup/bookings?tab=history')), (Icons.bar_chart, 'Reports', () => context.push('/sup/reports')), (Icons.person_outline, 'My Profile', () => context.push('/profile')), (Icons.support_agent, 'Support', () => context.push('/support')),
      ]),
      body: RefreshIndicator(onRefresh: _load, child: ListView(padding: EdgeInsets.zero, children: [
        DashboardHeader(name: 'Hello, ${u.fullName}', subtitle: '${_d['designation'] ?? 'Supervisor'} - ${_d['companyName'] ?? u.companyName ?? ''}', avatarUrl: _d['avatarUrl'] as String?, unread: n(_d['unreadNotifications']).toInt(), onMenu: () => _key.currentState?.openDrawer(), onBell: () => context.push('/notifications').then((_) => _load()), onAvatar: () => context.push('/profile')),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: ActionTile(icon: Icons.add, label: 'Post Your\nRequirement', onTap: () => context.push('/sup/post').then((_) => _load()))), const SizedBox(width: 12), Expanded(child: ActionTile(icon: Icons.event_note_outlined, label: 'My Bookings', onTap: () => context.push('/sup/bookings')))]),
          const SizedBox(height: 14),
          if (_loading) const LoadingState(height: 60) else Row(children: [_stat("Today's Bookings", n(_d['todaysBookings'])), _stat('Scheduled', n(_d['scheduled'])), _stat('Completed', n(_d['completed']))]),
          const SizedBox(height: 14),
          MenuTile(icon: Icons.navigation_outlined, label: 'Ongoing Trips', badge: n(_d['ongoing']).toInt(), onTap: () => context.push('/sup/bookings?tab=ongoing')),
          MenuTile(icon: Icons.history, label: 'Booking History', onTap: () => context.push('/sup/bookings?tab=history')),
          MenuTile(icon: Icons.bar_chart, label: 'Reports', onTap: () => context.push('/sup/reports')),
          MenuTile(icon: Icons.person_outline, label: 'My Profile', onTap: () => context.push('/profile')),
          MenuTile(icon: Icons.support_agent, label: 'Support', onTap: () => context.push('/support')),
          if (recent.isNotEmpty) ...[const SizedBox(height: 6), const Text('Recent Requirements', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 8), for (final r in recent) _RecentTile(r: r, onTap: () => context.push('/sup/track/${r['id']}'))],
          const SizedBox(height: 8),
          const PromoBanner(lines: ['Safe Rides', 'Productive Teams', GamyaBrand.tagline]),
        ])),
      ])),
    );
  }
  Widget _stat(String l, num v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 11.5, color: GamyaColors.textSecondary)), Text('$v', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))]));
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.r, required this.onTap});
  final Map<String, dynamic> r; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.border)), child: Row(children: [
    Container(width: 40, height: 40, decoration: BoxDecoration(color: GamyaColors.goldPale, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.local_taxi, color: GamyaColors.goldDark)), const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['code']}  ·  ${Fmt.vehicleType(r['vehicleType'] as String?)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text('${r['fromLocation']} → ${r['toLocation']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary)), Text(Fmt.dateTimeShort(r['scheduledAt']), style: const TextStyle(fontSize: 11.5, color: GamyaColors.textMuted))])),
    StatusChip(r['status'] as String?, small: true),
  ])));
}
