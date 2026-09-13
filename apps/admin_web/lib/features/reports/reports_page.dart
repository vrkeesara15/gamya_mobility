import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/download.dart';
import '../../core/providers.dart';
import '../../widgets/data_table.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/list_helpers.dart';
import '../../widgets/page_scaffold.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 29)), end: DateTime.now());
  Map<String, dynamic> _summary = {}; List<Map<String, dynamic>> _trend = []; List<Map<String, dynamic>> _byPlatform = []; List<Map<String, dynamic>> _byClient = []; List<Map<String, dynamic>> _drivers = []; List<Map<String, dynamic>> _vehicles = []; bool _loading = true; String? _error; int _tab = 0;
  ApiClient get api => ref.read(apiProvider);
  Map<String, dynamic> get _q => {'from': Fmt.iso(_range.start), 'to': Fmt.iso(_range.end)};
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final r = await Future.wait([api.get('/reports/summary', query: _q), api.get('/reports/trips-trend', query: _q), api.get('/reports/by-platform', query: _q), api.get('/reports/by-client', query: _q), api.get('/reports/driver-performance', query: _q), api.get('/reports/vehicle-utilisation', query: _q)]); if (mounted) setState(() { _summary = api.data(r[0]); _trend = api.list(r[1]); _byPlatform = api.list(r[2]); _byClient = api.list(r[3]); _drivers = api.list(r[4]); _vehicles = api.list(r[5]); _loading = false; }); }
    catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); }
  }
  Future<void> _export(String type) async { try { await downloadTextFile('$type-report.csv', await api.getText('/reports/export', query: {..._q, 'type': type})); if (mounted) toast(context, 'Export downloaded'); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  @override
  Widget build(BuildContext context) {
    num n(dynamic v) => (v as num?) ?? 0;
    final step = _trend.length > 16 ? (_trend.length / 12).ceil() : 1;
    final grouped = [for (var i = 0; i < _trend.length; i += step) BarGroup(label: Fmt.dateShort(_trend[i]['date']), values: [_trend.skip(i).take(step).fold<num>(0, (s, x) => s + n(x['scheduled'])), _trend.skip(i).take(step).fold<num>(0, (s, x) => s + n(x['adhoc']))])];
    return PageBody(children: [
      PageHeader(title: 'Reports & Analytics', breadcrumb: 'Reports & Analytics', subtitle: 'Trips, revenue, platform and client analytics for the selected period.', actions: [DateRangeButton(range: _range, onChanged: (r) { if (r != null) { setState(() => _range = r); _load(); } }), PopupMenuButton<String>(onSelected: _export, itemBuilder: (_) => const [PopupMenuItem(value: 'trips', child: Text('Export Trips CSV')), PopupMenuItem(value: 'adhoc', child: Text('Export Ad-hoc Requests CSV')), PopupMenuItem(value: 'drivers', child: Text('Export Drivers CSV')), PopupMenuItem(value: 'vehicles', child: Text('Export Vehicles CSV')), PopupMenuItem(value: 'supervisors', child: Text('Export Supervisors CSV'))], child: const GoldButton(label: 'Export', icon: Icons.download_outlined, onPressed: null))]),
      const SizedBox(height: 14),
      if (_loading) const LoadingState() else if (_error != null) ErrorState(message: _error!, onRetry: _load) else ...[
        StatGrid(cards: [
          StatCard(label: 'Total Trips', value: '${n(_summary['trips'])}', icon: Icons.route, trend: '${n(_summary['completed'])} completed', trendPositive: true),
          StatCard(label: 'On-Time %', value: '${n(_summary['onTimePct'])}%', icon: Icons.schedule, iconColor: GamyaColors.success, trend: '${n(_summary['delayed'])} delayed', trendPositive: n(_summary['delayed']) == 0),
          StatCard(label: 'Revenue', value: Fmt.inr(_summary['revenue'] as num?), icon: Icons.currency_rupee, trend: 'Completed trips', trendPositive: true),
          StatCard(label: 'Driver Payout', value: Fmt.inr(_summary['driverPayout'] as num?), icon: Icons.account_balance_wallet, trend: 'Earnings accrued', trendColor: GamyaColors.info, trendIcon: Icons.arrow_upward),
          StatCard(label: 'Bookings', value: '${n(_summary['bookings'])}', icon: Icons.event_note, trend: '${n(_summary['adhocRequests'])} ad-hoc requests', trendColor: GamyaColors.textSecondary, trendIcon: Icons.add_box_outlined),
          StatCard(label: 'New Registrations', value: '${n(_summary['newDrivers']) + n(_summary['newSupervisors'])}', icon: Icons.person_add, trend: '${n(_summary['newDrivers'])} drivers · ${n(_summary['newVehicles'])} vehicles · ${n(_summary['newSupervisors'])} supervisors', trendColor: GamyaColors.textSecondary, trendIcon: Icons.info_outline),
        ]),
        const SizedBox(height: 12),
        CardRow(minWidth: 320, flex: const [3, 2], children: [
          SectionCard(title: 'Trips Trend', child: StackedBarChart(height: 200, colors: const [GamyaColors.gold, GamyaColors.dark], legend: const ['Scheduled', 'Ad-hoc'], groups: grouped)),
          SectionCard(title: 'Revenue Trend', child: LineChart(height: 200, fill: true, labels: [for (final t in _trend) Fmt.dateShort(t['date'])], series: [LineSeries(label: 'Revenue', values: [for (final t in _trend) n(t['revenue'])], color: GamyaColors.success)])),
        ]),
        const SizedBox(height: 12),
        CardRow(minWidth: 320, children: [
          SectionCard(title: 'Trips by Platform', child: Center(child: DonutChart(slices: [for (final p in _byPlatform) ChartSlice(label: p['name'] as String, value: n(p['trips']), color: GamyaColors.fromHex(p['color'] as String?))]))),
          SectionCard(title: 'Trips by Client', child: HBarList(labelWidth: 100, items: [for (final c in _byClient.take(8)) ChartSlice(label: c['name'] as String, value: n(c['trips']), color: GamyaColors.info)])),
          SectionCard(title: 'Revenue by Platform', child: HBarList(labelWidth: 110, items: [for (final p in _byPlatform) ChartSlice(label: p['name'] as String, value: n(p['revenue']), color: GamyaColors.fromHex(p['color'] as String?))])),
        ]),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: PillTabs(tabs: const ['Driver Performance', 'Vehicle Utilisation'], selected: _tab, onChanged: (i) => setState(() => _tab = i))),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: _tab == 0
          ? GTable<Map<String, dynamic>>(minWidth: 800, columns: const [GColumn('Driver', width: 180), GColumn('Mobile', width: 110), GColumn('Vehicle', width: 110), GColumn('Trips', width: 60, numeric: true), GColumn('Completed', width: 80, numeric: true), GColumn('Delayed', width: 70, numeric: true), GColumn('On-Time %', width: 80, numeric: true), GColumn('Earnings', width: 100, numeric: true), GColumn('Rating', width: 70, numeric: true)], rows: _drivers, cells: (d, i) => [CellText(d['fullName'] as String?, bold: true), CellText(d['mobile'] as String?), CellText(d['vehicleNumber'] as String?), CellText('${d['trips']}'), CellText('${d['completed']}'), CellText('${d['delayed']}', color: n(d['delayed']) > 0 ? GamyaColors.danger : null), CellText('${d['onTimePct']}%', color: n(d['onTimePct']) >= 90 ? GamyaColors.success : GamyaColors.warning), CellText(Fmt.inr(d['earnings'] as num?), bold: true), Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star, size: 13, color: GamyaColors.gold), CellText('${d['rating'] ?? '—'}')])])
          : GTable<Map<String, dynamic>>(minWidth: 800, columns: const [GColumn('Vehicle', width: 120), GColumn('Make & Model', width: 160), GColumn('Type', width: 100), GColumn('Driver', width: 150), GColumn('Trips', width: 60, numeric: true), GColumn('Trips / Day', width: 80, numeric: true), GColumn('Distance (km)', width: 100, numeric: true), GColumn('Revenue', width: 100, numeric: true)], rows: _vehicles, cells: (v, i) => [CellText(v['number'] as String?, bold: true), CellText(v['makeModel'] as String?), CellText(Fmt.vehicleType(v['type'] as String?)), CellText(v['driverName'] as String?), CellText('${v['trips']}'), CellText('${v['tripsPerDay']}'), CellText('${v['distanceKm']}'), CellText(Fmt.inr(v['revenue'] as num?), bold: true)]))),
      ],
    ]);
  }
}
