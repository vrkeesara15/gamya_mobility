import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/data_table.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Map<String, dynamic>? _d; String? _error; DateTime _date = DateTime.now(); int _approvalsTab = 0; int _regTab = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _error = null; });
    try { final api = ref.read(apiProvider); final r = await api.get('/dashboard', query: {'date': Fmt.iso(_date)}); if (mounted) setState(() => _d = api.data(r)); }
    catch (e) { if (mounted) setState(() => _error = e.msg); }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final d = _d;
    if (d == null) return const LoadingState(height: 400);
    final s = (d['stats'] as Map).cast<String, dynamic>();
    final ts = (d['tripStatus'] as Map).cast<String, dynamic>();
    final pw = (d['platformWise'] as Map).cast<String, dynamic>();
    final ov = (d['bookingsOverview'] as List).cast<Map<String, dynamic>>();
    final pa = (d['pendingApprovals'] as Map).cast<String, dynamic>();
    final rr = (d['recentRegistrations'] as Map).cast<String, dynamic>();
    num n(dynamic v) => (v as num?) ?? 0;
    return PageBody(children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), Text('Welcome to ${GamyaBrand.company} Admin Panel', style: TextStyle(fontSize: 13, color: GamyaColors.textSecondary))])),
        OutlinedButton.icon(onPressed: () async { final p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 365))); if (p != null) { setState(() => _date = p); _load(); } }, icon: const Icon(Icons.calendar_today_outlined, size: 16), label: Text(Fmt.date(_date))),
      ]),
      const SizedBox(height: 14),
      StatGrid(cards: [
        StatCard(label: 'Total Supervisors', value: '${n(s['totalSupervisors'])}', icon: Icons.supervisor_account, trend: '+${n(s['supervisorsThisWeek'])} this week', trendPositive: true, onTap: () => context.go('/supervisors')),
        StatCard(label: 'Total Drivers', value: '${n(s['totalDrivers'])}', icon: Icons.person, trend: '+${n(s['driversThisWeek'])} this week', trendPositive: true, onTap: () => context.go('/drivers')),
        StatCard(label: 'Total Vehicles', value: '${n(s['totalVehicles'])}', icon: Icons.directions_car, trend: '+${n(s['vehiclesThisWeek'])} this week', trendPositive: true, onTap: () => context.go('/vehicles')),
        StatCard(label: 'Ad-hoc Requirements', value: '${n(s['adhocRequirements'])}', icon: Icons.assignment, trend: '${n(s['adhocGrowthPct']) >= 0 ? '+' : ''}${n(s['adhocGrowthPct'])}% from last week', trendPositive: n(s['adhocGrowthPct']) >= 0, onTap: () => context.go('/adhoc')),
        StatCard(label: 'Active Trips', value: '${n(s['activeTrips'])}', icon: Icons.navigation, trend: 'Live on road', trendIcon: Icons.arrow_upward, trendColor: GamyaColors.success, onTap: () => context.go('/live-trips')),
        StatCard(label: 'Completed Today', value: '${n(s['completedToday'])}', icon: Icons.check_circle, trend: '${n(s['completedGrowthPct']) >= 0 ? '+' : ''}${n(s['completedGrowthPct'])}% from yesterday', trendPositive: n(s['completedGrowthPct']) >= 0, onTap: () => context.go('/completed-trips')),
      ]),
      const SizedBox(height: 12),
      CardRow(minWidth: 300, flex: const [3, 2, 2], children: [
        SectionCard(title: 'Bookings Overview', child: StackedBarChart(groups: [for (final b in ov) BarGroup(label: b['label'] as String, values: [n(b['instant']), n(b['scheduled'])])], colors: const [GamyaColors.dark, GamyaColors.gold], legend: const ['Instant (Ad-hoc)', 'Scheduled'], height: 200)),
        SectionCard(title: 'Platform Wise Bookings', child: Center(child: DonutChart(slices: [for (final p in (pw['items'] as List).cast<Map<String, dynamic>>()) ChartSlice(label: p['name'] as String, value: n(p['count']), color: GamyaColors.fromHex(p['color'] as String?))]))),
        SectionCard(title: 'Trip Status (Today)', child: Center(child: DonutChart(totalLabel: 'Total Trips', slices: [ChartSlice(label: 'On Time', value: n(ts['onTime']), color: GamyaColors.success), ChartSlice(label: 'Delayed', value: n(ts['delayed']), color: GamyaColors.danger), ChartSlice(label: 'Yet to Start', value: n(ts['yetToStart']), color: GamyaColors.warning), ChartSlice(label: 'Cancelled', value: n(ts['cancelled']), color: GamyaColors.neutral)]))),
      ]),
      const SizedBox(height: 12),
      CardRow(minWidth: 420, children: [
        SectionCard(title: 'Recent Ad-hoc Requirements', trailing: ViewAllLink(onTap: () => context.go('/adhoc')), padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: GTable<Map<String, dynamic>>(minWidth: 420, columns: const [GColumn('Date', width: 92), GColumn('Vehicle Type', width: 100), GColumn('Pickup → Drop', flex: 2), GColumn('Platform', width: 110), GColumn('Status', width: 90)], rows: (d['recentAdhoc'] as List).cast<Map<String, dynamic>>(), onRowTap: (r) => context.go('/adhoc?id=${r['id']}'), cells: (r, i) => [CellText(Fmt.date(r['date'])), CellText(Fmt.vehicleType(r['vehicleType'] as String?)), RouteText(r['fromLocation'] as String, r['toLocation'] as String), PlatformChip(name: r['platform'] as String, color: r['platformColor'] as String?, compact: true), StatusChip(r['status'] == 'PENDING' ? 'OPEN' : r['status'] as String?, small: true, label: r['status'] == 'PENDING' ? 'Open' : r['bookingType'] == 'SCHEDULED' && r['status'] == 'ASSIGNED' ? 'Scheduled' : null)])),
        SectionCard(title: 'Live Trips', trailing: ViewAllLink(onTap: () => context.go('/live-trips')), padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: GTable<Map<String, dynamic>>(minWidth: 460, columns: const [GColumn('Driver Name', width: 120), GColumn('Vehicle No.', width: 100), GColumn('Platform', width: 110), GColumn('Route', flex: 2), GColumn('Status', width: 80)], rows: (d['liveTrips'] as List).cast<Map<String, dynamic>>(), onRowTap: (r) => context.go('/live-trips?id=${r['id']}'), emptyText: 'No trips on the road right now', cells: (r, i) => [CellText(r['driverName'] as String?), CellText(r['vehicleNumber'] as String?), PlatformChip(name: r['platform'] as String, color: r['platformColor'] as String?, compact: true), RouteText(r['fromLocation'] as String, r['toLocation'] as String), StatusChip(r['status'] as String?, small: true)])),
      ]),
      const SizedBox(height: 12),
      CardRow(minWidth: 420, children: [
        SectionCard(title: 'Pending Approvals', trailing: ViewAllLink(onTap: () => context.go('/approvals')), padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PillTabs(tabs: ['Drivers (${n(pa['driversCount'])})', 'Supervisors (${n(pa['supervisorsCount'])})'], selected: _approvalsTab, onChanged: (i) => setState(() => _approvalsTab = i)), const SizedBox(height: 8),
          GTable<Map<String, dynamic>>(minWidth: 460, columns: [const GColumn('Name', flex: 2), const GColumn('Mobile No.', width: 100), GColumn(_approvalsTab == 0 ? 'Vehicle No.' : 'Company', width: 110), const GColumn('Submitted On', width: 100), const GColumn('Action', width: 80)], rows: ((_approvalsTab == 0 ? pa['drivers'] : pa['supervisors']) as List).cast<Map<String, dynamic>>(), emptyText: 'No pending approvals', cells: (r, i) => [CellText(r['name'] as String?), CellText(r['mobile'] as String?), CellText((_approvalsTab == 0 ? r['vehicleNumber'] : r['company']) as String?), CellText(Fmt.date(r['submittedOn'])), OutlinedButton(onPressed: () => context.go('/approvals?id=${r['approvalId']}'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero, side: const BorderSide(color: GamyaColors.gold), foregroundColor: GamyaColors.goldDark), child: const Text('Review', style: TextStyle(fontSize: 12)))]),
        ])),
        SectionCard(title: 'Recent Registrations', trailing: ViewAllLink(onTap: () => context.go(_regTab == 0 ? '/drivers' : '/supervisors')), padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PillTabs(tabs: const ['Drivers', 'Supervisors'], selected: _regTab, onChanged: (i) => setState(() => _regTab = i)), const SizedBox(height: 8),
          GTable<Map<String, dynamic>>(minWidth: 460, columns: const [GColumn('Name', flex: 2), GColumn('Mobile No.', width: 100), GColumn('Type', width: 80), GColumn('Registered On', width: 100), GColumn('Status', width: 90)], rows: ((_regTab == 0 ? rr['drivers'] : rr['supervisors']) as List).cast<Map<String, dynamic>>(), onRowTap: (r) => context.go('${_regTab == 0 ? '/drivers' : '/supervisors'}?id=${r['id']}'), cells: (r, i) => [CellText(r['name'] as String?), CellText(r['mobile'] as String?), CellText(r['type'] as String?), CellText(Fmt.date(r['registeredOn'])), StatusChip(r['status'] as String?, small: true, dot: false)]),
        ])),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 28, runSpacing: 8, children: [for (final b in GamyaBrand.footerBadges) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 26, height: 26, decoration: const BoxDecoration(color: GamyaColors.gold, shape: BoxShape.circle), child: const Icon(Icons.verified_user, size: 15, color: Colors.white)), const SizedBox(width: 8), Text(b, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500))])]),
    ]);
  }
}
