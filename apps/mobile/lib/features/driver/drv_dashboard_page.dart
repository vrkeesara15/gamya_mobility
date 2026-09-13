import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class DrvDashboardPage extends ConsumerStatefulWidget {
  const DrvDashboardPage({super.key});
  @override
  ConsumerState<DrvDashboardPage> createState() => _DrvDashboardPageState();
}

class _DrvDashboardPageState extends ConsumerState<DrvDashboardPage> {
  Map<String, dynamic> _d = {}; bool _loading = true; final _key = GlobalKey<ScaffoldState>();
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final r = await api.get('/driver/dashboard'); if (mounted) setState(() { _d = api.data(r); _loading = false; }); } catch (e) { if (mounted) { setState(() => _loading = false); toast(context, e.msg, error: true); } } }
  @override
  Widget build(BuildContext context) {
    final u = ref.watch(sessionProvider)!;
    num n(dynamic v) => (v as num?) ?? 0;
    return Scaffold(
      key: _key, backgroundColor: GamyaColors.surface,
      drawer: GamyaDrawer(name: u.fullName, subtitle: 'Driver ID : ${_d['code'] ?? u.code ?? ''}', avatarUrl: _d['avatarUrl'] as String?, onLogout: () => ref.read(sessionProvider.notifier).logout(), items: [
        (Icons.dashboard_outlined, 'Dashboard', () {}), (Icons.add_road, 'Available Trips', () => context.push('/drv/available')), (Icons.route_outlined, 'My Trips', () => context.push('/drv/trips')), (Icons.currency_rupee, 'My Earnings', () => context.push('/drv/earnings')), (Icons.description_outlined, 'Documents', () => context.push('/drv/documents')), (Icons.person_outline, 'My Profile', () => context.push('/profile')), (Icons.help_outline, 'Help & Support', () => context.push('/support')),
      ]),
      body: RefreshIndicator(onRefresh: _load, child: ListView(padding: EdgeInsets.zero, children: [
        DashboardHeader(name: u.fullName, subtitle: 'Driver ID : ${_d['code'] ?? u.code ?? ''}', avatarUrl: _d['avatarUrl'] as String?, unread: n(_d['unreadNotifications']).toInt(), onMenu: () => _key.currentState?.openDrawer(), onBell: () => context.push('/notifications').then((_) => _load()), onAvatar: () => context.push('/profile'), trailing: StatusChip(_d['status'] as String? ?? u.status, small: true)),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_loading) const LoadingState(height: 70) else Row(children: [Expanded(child: MiniStat(label: "Today's Trips", value: '${n(_d['todaysTrips'])}', icon: Icons.route)), const SizedBox(width: 10), Expanded(child: MiniStat(label: 'Earnings', value: Fmt.inr(_d['earningsToday']), icon: Icons.currency_rupee, color: GamyaColors.success))]),
          const SizedBox(height: 14),
          MenuTile(icon: Icons.add_road, label: 'Available Trips', badge: n(_d['availableTrips']).toInt(), onTap: () => context.push('/drv/available').then((_) => _load())),
          MenuTile(icon: Icons.route_outlined, label: 'My Trips', onTap: () => context.push('/drv/trips')),
          MenuTile(icon: Icons.currency_rupee, label: 'My Earnings', subtitle: 'Total ${Fmt.inr(_d['earningsTotal'])}', onTap: () => context.push('/drv/earnings')),
          MenuTile(icon: Icons.description_outlined, label: 'Documents', subtitle: '${(_d['onboarding'] as Map?)?['docs']?['label'] ?? ''} verified', onTap: () => context.push('/drv/documents')),
          MenuTile(icon: Icons.person_outline, label: 'My Profile', onTap: () => context.push('/profile')),
          MenuTile(icon: Icons.help_outline, label: 'Help & Support', onTap: () => context.push('/support')),
          const SizedBox(height: 8),
          const PromoBanner(lines: ['Drive Safe', 'Earn Better', 'Grow Together']),
        ])),
      ])),
    );
  }
}
