import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/download.dart';
import '../../core/providers.dart';
import '../../widgets/data_table.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/list_helpers.dart';
import '../../widgets/page_scaffold.dart';
import 'adhoc_form.dart';

class AdhocPage extends ConsumerStatefulWidget {
  const AdhocPage({super.key, this.selectId});
  final String? selectId;
  @override
  ConsumerState<AdhocPage> createState() => _AdhocPageState();
}

class _AdhocPageState extends ConsumerState<AdhocPage> {
  final _q = ListQuery(); final _search = TextEditingController(); DateTimeRange? _range;
  Paged<AdhocRequest> _data = Paged.empty(); bool _loading = true; String? _error;
  Map<String, dynamic> _stats = {}; Map<String, dynamic> _analytics = {}; List<Map<String, dynamic>> _clients = []; List<Map<String, dynamic>> _locations = [];
  AdhocRequest? _selected; bool _detailLoading = false; final Set<String> _checked = {};
  ApiClient get api => ref.read(apiProvider);

  @override
  void initState() { super.initState(); _load(); _loadSide(); if (widget.selectId != null) _open(widget.selectId!); }
  @override
  void didUpdateWidget(covariant AdhocPage old) { super.didUpdateWidget(old); if (widget.selectId != null && widget.selectId != old.selectId) _open(widget.selectId!); }

  Future<void> _loadSide() async { try { final r = await Future.wait([api.get('/adhoc/stats'), api.get('/adhoc/analytics'), api.get('/clients'), api.get('/locations')]); if (mounted) setState(() { _stats = api.data(r[0]); _analytics = api.data(r[1]); _clients = api.list(r[2]); _locations = api.list(r[3]); }); } catch (_) {} }
  Future<void> _load() async { setState(() { _loading = true; _error = null; }); try { final d = await api.paged('/adhoc', AdhocRequest.new, query: _q.toQuery()); if (mounted) setState(() { _data = d; _loading = false; }); } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); } }
  Future<void> _open(String id) async { setState(() => _detailLoading = true); try { final r = await api.get('/adhoc/$id'); if (mounted) setState(() => _selected = AdhocRequest(api.data(r))); } catch (e) { if (mounted) toast(context, e.msg, error: true); } if (mounted) setState(() => _detailLoading = false); }
  Future<void> _after(Future<void> Function() f, [String? ok]) async { try { await f(); if (ok != null && mounted) toast(context, ok); await _load(); await _loadSide(); if (_selected != null) await _open(_selected!.id); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  Future<void> _edit([AdhocRequest? a]) async { final saved = await showDialog<bool>(context: context, builder: (_) => AdhocFormDialog(existing: a, clients: _clients, locations: _locations)); if (saved == true) { await _load(); await _loadSide(); if (a != null) _open(a.id); } }
  Future<void> _assign(AdhocRequest a) async {
    final v = await pickFromList(context, title: 'Assign Vehicle for ${a.code} (${Fmt.vehicleType(a.vehicleType)})', fetch: (q) async => (api.data(await api.get('/vehicles', query: {'q': q, 'pageSize': 40, 'status': 'ACTIVE', 'type': q.isEmpty ? a.vehicleType : null}))['items'] as List).cast<Map<String, dynamic>>(), tile: (v) => Row(children: [NetImage(v['photoUrl'] as String?, width: 56, height: 36, placeholderIcon: Icons.directions_car), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${v['number']}  ·  ${v['makeModel']}', style: const TextStyle(fontWeight: FontWeight.w600)), Text('${Fmt.vehicleType(v['type'] as String?)} · ${(v['driver'] as Map?)?['fullName'] ?? 'No driver'} · ${(v['platform'] as Map?)?['name'] ?? 'Other'}', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))])), StatusChip(v['status'] as String?, small: true)]));
    if (v == null) return;
    if (v['driver'] == null) { if (mounted) toast(context, 'That vehicle has no assigned driver. Assign a driver on the Vehicles page first.', error: true); return; }
    await _after(() => api.post('/adhoc/${a.id}/assign', body: {'vehicleId': v['id']}), 'Vehicle ${v['number']} assigned');
  }
  Future<void> _cancel(AdhocRequest a) async { final r = await reasonDialog(context, title: 'Cancel ${a.code}', label: 'Reason', confirmLabel: 'Cancel Request', danger: true); if (r == null) return; await _after(() => api.post('/adhoc/${a.id}/cancel', body: {'reason': r}), 'Request cancelled'); }
  Future<void> _export() async { try { await downloadTextFile('adhoc-requests.csv', await api.getText('/reports/export', query: {'type': 'adhoc', if (_range != null) 'from': Fmt.iso(_range!.start), if (_range != null) 'to': Fmt.iso(_range!.end)})); if (mounted) toast(context, 'Export downloaded'); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  @override
  Widget build(BuildContext context) {
    num n(dynamic v) => (v as num?) ?? 0;
    final byStatus = ((_analytics['byStatus'] as List?) ?? []).cast<Map<String, dynamic>>(); final byType = ((_analytics['byVehicleType'] as List?) ?? []).cast<Map<String, dynamic>>(); final byClient = ((_analytics['byClient'] as List?) ?? []).cast<Map<String, dynamic>>(); final trend = ((_analytics['trend'] as List?) ?? []).cast<Map<String, dynamic>>();
    num st(String s) => byStatus.where((x) => x['status'] == s).fold<num>(0, (a, x) => a + n(x['count']));
    return PageBody(children: [
      PageHeader(title: 'Ad-hoc Requirements', breadcrumb: 'Ad-hoc Requirements', subtitle: 'Manage on-demand transportation requests, assign vehicles, and track fulfillment.', actions: [OutlineButton(label: 'Export', icon: Icons.download_outlined, onPressed: _export), GoldButton(label: 'New Ad-hoc Request', icon: Icons.add, onPressed: () => _edit())]),
      const SizedBox(height: 14),
      StatGrid(cards: [
        StatCard(label: 'Total Requests', value: '${n(_stats['total'])}', icon: Icons.list_alt, trend: '+${n(_stats['newThisMonth'])} this month', trendPositive: true),
        StatCard(label: 'Assigned', value: '${n(_stats['assigned'])}', icon: Icons.check_circle, iconColor: GamyaColors.success, trend: '${n(_stats['fulfillmentPct'])}% fulfillment', trendPositive: true, trendIcon: Icons.verified),
        StatCard(label: 'Pending', value: '${n(_stats['pending'])}', icon: Icons.schedule, iconColor: GamyaColors.warning, trend: '${n(_stats['pendingPct'])}%', trendColor: GamyaColors.warning, trendIcon: Icons.timelapse, onTap: () { _q.set('status', 'PENDING'); _load(); }),
        StatCard(label: 'Cancelled', value: '${n(_stats['cancelled'])}', icon: Icons.cancel, iconColor: GamyaColors.danger, trend: '${n(_stats['cancelledPct'])}%', trendPositive: false),
        StatCard(label: "Today's Requests", value: '${n(_stats['todays'])}', icon: Icons.groups, trend: '${n(_stats['yesterdays'])} yesterday', trendPositive: n(_stats['todays']) >= n(_stats['yesterdays'])),
        StatCard(label: 'Est. Revenue (This Month)', value: Fmt.inr(_stats['estRevenue']), icon: Icons.currency_rupee, trend: '${n(_stats['revenueGrowthPct']) >= 0 ? '+' : ''}${n(_stats['revenueGrowthPct'])}%', trendPositive: n(_stats['revenueGrowthPct']) >= 0),
      ]),
      const SizedBox(height: 12),
      MasterDetail(
        master: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilterBar(children: [
            DateRangeButton(range: _range, onChanged: (r) { setState(() => _range = r); _q.set('from', r == null ? null : Fmt.iso(r.start)); _q.set('to', r == null ? null : Fmt.iso(r.end)); _load(); }),
            FilterDropdown<String>(label: 'All Clients', value: _q.filters['clientId'] as String?, items: [for (final c in _clients) ddItem(c['id'] as String, c['name'] as String)], onChanged: (v) { _q.set('clientId', v); _load(); }),
            FilterDropdown<String>(label: 'All Locations', value: _q.filters['location'] as String?, items: [for (final l in _locations) ddItem(l['name'] as String, l['name'] as String)], onChanged: (v) { _q.set('location', v); _load(); }),
            FilterDropdown<String>(label: 'All Status', value: _q.filters['status'] as String?, width: 130, items: [ddItem('PENDING', 'Pending'), ddItem('ASSIGNED', 'Assigned'), ddItem('ACCEPTED', 'Accepted'), ddItem('IN_PROGRESS', 'In Progress'), ddItem('COMPLETED', 'Completed'), ddItem('CANCELLED', 'Cancelled')], onChanged: (v) { _q.set('status', v); _load(); }),
            FilterDropdown<String>(label: 'All Vehicle Types', value: _q.filters['vehicleType'] as String?, items: [for (final t in vehicleTypeItems) ddItem(t.$1, t.$2)], onChanged: (v) { _q.set('vehicleType', v); _load(); }),
            SearchField(controller: _search, hint: 'Search by request ID, employee, location…', width: 240, onSubmitted: (v) { _q.set('q', v); _load(); }),
          ], onApply: () { _q.set('q', _search.text); _load(); }, onReset: () { _q.reset(); _search.clear(); setState(() => _range = null); _load(); }),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GTable<AdhocRequest>(
              columns: const [GColumn('Request ID', width: 140), GColumn('Date & Time', width: 110), GColumn('Client / Employee', width: 130), GColumn('From → To', flex: 2), GColumn('No. of Pax', width: 60, numeric: true), GColumn('Vehicle Type', width: 100), GColumn('Status', width: 95), GColumn('Assigned Vehicle', width: 110), GColumn('Actions', width: 110)],
              rows: _data.items, loading: _loading, error: _error, onRetry: _load, rowId: (a) => a.id, selected: _checked, onSelect: (id, s) => setState(() => s ? _checked.add(id) : _checked.remove(id)), onSelectAll: (s) => setState(() => s ? _checked.addAll(_data.items.map((e) => e.id)) : _checked.clear()), selectedRow: _selected, onRowTap: (a) => _open(a.id),
              cells: (a, i) => [CellText(a.code, bold: true), Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [CellText(Fmt.date(a.scheduledAt)), CellText(Fmt.time(a.scheduledAt), muted: true)]), Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [CellText(a.clientName, bold: true), CellText(a.contactName, muted: true)]), RouteText(a.fromLocation, a.toLocation), CellText('${a.passengers}'), CellText(Fmt.vehicleType(a.vehicleType)), StatusChip(a.status, small: true, dot: false), CellText(a.assignedVehicle?['number'] as String?), RowActions(onView: () => _open(a.id), onEdit: () => _edit(a), more: () => [if (!['COMPLETED', 'CANCELLED'].contains(a.status)) PopupMenuItem(onTap: () => _assign(a), child: const Text('Assign vehicle')), if (a.trip != null) PopupMenuItem(onTap: () => context.go('${a.trip!['status'] == 'COMPLETED' ? '/completed-trips' : '/live-trips'}?id=${a.trip!['id']}'), child: const Text('Open trip')), if (!['COMPLETED', 'CANCELLED'].contains(a.status)) PopupMenuItem(onTap: () => _cancel(a), child: const Text('Cancel request', style: TextStyle(color: GamyaColors.danger)))])],
            ),
            const SizedBox(height: 10),
            PaginationBar(paged: _data, noun: 'requests', onPage: (p) { _q.page = p; _load(); }, onPageSize: (s) { _q.pageSize = s; _q.page = 1; _load(); }),
          ]))),
          const SizedBox(height: 12),
          CardRow(minWidth: 240, flex: const [3, 3, 3, 4], children: [
            SectionCard(title: 'Requests by Client (This Month)', child: HBarList(labelWidth: 80, colors: const [GamyaColors.info, GamyaColors.success, GamyaColors.danger, GamyaColors.gold, GamyaColors.goldDark, GamyaColors.neutral], items: [for (final c in byClient.take(6)) ChartSlice(label: c['name'] as String, value: n(c['count']), color: GamyaColors.info)])),
            SectionCard(title: 'Request Status', child: Center(child: DonutChart(size: 110, slices: [ChartSlice(label: 'Assigned', value: st('ASSIGNED') + st('ACCEPTED') + st('IN_PROGRESS'), color: GamyaColors.success), ChartSlice(label: 'Pending', value: st('PENDING'), color: GamyaColors.warning), ChartSlice(label: 'Cancelled', value: st('CANCELLED'), color: GamyaColors.danger), ChartSlice(label: 'Completed', value: st('COMPLETED'), color: GamyaColors.info)]))),
            SectionCard(title: 'Vehicle Type Wise', child: HBarList(labelWidth: 100, items: [for (final t in byType) ChartSlice(label: Fmt.vehicleType(t['vehicleType'] as String?), value: n(t['count']), color: GamyaColors.info)])),
            SectionCard(title: 'Ad-hoc Trends (Last 14 Days)', child: LineChart(height: 150, labels: [for (final t in trend) Fmt.dateShort(t['date'])], series: [LineSeries(label: 'Requests', values: [for (final t in trend) n(t['count'])], color: GamyaColors.goldDark)])),
          ]),
        ]),
        detail: _selected == null && !_detailLoading ? null : _detailLoading ? const Card(child: LoadingState(height: 240)) : _detail(_selected!),
      ),
    ]);
  }

  Widget _detail(AdhocRequest a) {
    final closed = ['COMPLETED', 'CANCELLED'].contains(a.status);
    return DetailPanel(
      title: 'Request Details', onClose: () => setState(() => _selected = null),
      header: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(a.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(width: 10), StatusChip(a.status, small: true, dot: false), const Spacer(), StatusChip(a.bookingType, label: a.bookingType == 'INSTANT' ? 'Instant' : 'Scheduled', small: true, dot: false)]), Text('Created on ${Fmt.dateTime(a.createdAt)}', style: const TextStyle(fontSize: 11.5, color: GamyaColors.textSecondary))]),
      tabs: const ['Details', 'Assignment', 'Costing', 'Activity Log'],
      tabViews: [
        Column(children: [
          KeyValueRow('Client / Employee', a.clientName, icon: Icons.business_outlined), KeyValueRow('Contact Person', '${a.contactName ?? ''} ${a.contactMobile != null ? '(${a.contactMobile})' : ''}', icon: Icons.person_outline), KeyValueRow('From', a.fromLocation, icon: Icons.trip_origin), KeyValueRow('To', a.toLocation, icon: Icons.location_on_outlined), KeyValueRow('Date & Time', Fmt.dateTime(a.scheduledAt), icon: Icons.calendar_today_outlined), KeyValueRow('Login / Reporting', '${Fmt.time24(a.loginTime)} / ${Fmt.time24(a.reportingTime)}', icon: Icons.schedule), KeyValueRow('No. of Passengers', '${a.passengers}', icon: Icons.groups_outlined), KeyValueRow('Vehicle Type', '${Fmt.vehicleType(a.vehicleType)}${a.modelYearMin != null ? ' (${a.modelYearMin} & above)' : ''} × ${a.numberOfVehicles}', icon: Icons.directions_car_outlined), KeyValueRow('Platform', a.platformName, icon: Icons.hub_outlined), KeyValueRow('Special Instructions', a.specialInstructions, icon: Icons.info_outline), KeyValueRow('Estimated Amount', Fmt.inr(a.estimatedAmount), icon: Icons.currency_rupee), if (a.cancelReason != null) KeyValueRow('Cancel Reason', a.cancelReason, icon: Icons.cancel_outlined),
          const SizedBox(height: 10),
          _routeMap(a),
        ]),
        Column(children: [
          if (a.assignedVehicle == null) const EmptyState(icon: Icons.local_taxi_outlined, title: 'No vehicle assigned yet') else Row(children: [NetImage(a.assignedVehicle!['photoUrl'] as String?, width: 90, height: 58, placeholderIcon: Icons.directions_car), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.assignedVehicle!['number'] as String, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${a.assignedVehicle!['make']} ${a.assignedVehicle!['model']} · ${Fmt.vehicleType(a.assignedVehicle!['type'] as String?)}', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))]))]),
          const SizedBox(height: 10),
          if (a.assignedDriver != null) Row(children: [GamyaAvatar(url: a.assignedDriver!['avatarUrl'] as String?, name: a.assignedDriver!['fullName'] as String?, size: 40), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.assignedDriver!['fullName'] as String, style: const TextStyle(fontWeight: FontWeight.w600)), Text('${a.assignedDriver!['code']} · ${a.assignedDriver!['mobile']}', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))])), TextButton(onPressed: () => context.go('/drivers?id=${a.assignedDriver!['id']}'), child: const Text('Open'))]),
          const SizedBox(height: 12),
          if (a.trip != null) ...[const Align(alignment: Alignment.centerLeft, child: Text('Trip timeline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))), const SizedBox(height: 8), TrackingTimeline(steps: TrackingTimeline.fromTrip(events: a.events, status: a.trip!['status'] as String, platformName: a.platformName, createdAt: a.createdAt)), const SizedBox(height: 8), Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => context.go('${a.trip!['status'] == 'COMPLETED' ? '/completed-trips' : '/live-trips'}?id=${a.trip!['id']}'), icon: const Icon(Icons.open_in_new, size: 14), label: Text('Open trip ${a.trip!['code']}')))],
        ]),
        Column(children: [KeyValueRow('Vehicle Type', Fmt.vehicleType(a.vehicleType)), KeyValueRow('No. of Vehicles', '${a.numberOfVehicles}'), KeyValueRow('Estimated Amount', Fmt.inr(a.estimatedAmount)), KeyValueRow('Trip Amount', a.trip == null ? '—' : Fmt.inr(a.trip!['amount'] ?? a.estimatedAmount)), const SizedBox(height: 8), const Text('Amounts are based on the tariff configured in Settings; the final trip amount can be adjusted when the trip is completed.', style: TextStyle(fontSize: 11.5, color: GamyaColors.textMuted))]),
        ActivityList(items: a.activities, compact: true),
      ],
      footer: Wrap(spacing: 8, runSpacing: 8, children: [if (!closed) GoldButton(label: a.assignedVehicle == null ? 'Assign Vehicle' : 'Re-assign Vehicle', dense: true, onPressed: () => _assign(a)), if (!closed) OutlineButton(label: 'Edit Request', dense: true, onPressed: () => _edit(a)), if (!closed) OutlineButton(label: 'Cancel Request', dense: true, color: GamyaColors.danger, onPressed: () => _cancel(a))]),
      child: const SizedBox.shrink(),
    );
  }

  Widget _routeMap(AdhocRequest a) => Container(height: 96, decoration: BoxDecoration(color: const Color(0xFFEFF3F8), borderRadius: BorderRadius.circular(10), border: Border.all(color: GamyaColors.border)), child: CustomPaint(painter: _RoutePainter(), child: Padding(padding: const EdgeInsets.all(10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(Icons.location_on, color: GamyaColors.info, size: 18), const SizedBox(width: 4), Text(a.fromLocation, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))]), Column(mainAxisAlignment: MainAxisAlignment.end, children: [Row(children: [const Icon(Icons.location_on, color: GamyaColors.danger, size: 18), const SizedBox(width: 4), Text(a.toLocation, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))])])]))));
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final grid = Paint()..color = Colors.white..strokeWidth = 1;
    for (var x = 0.0; x < s.width; x += 22) { canvas.drawLine(Offset(x, 0), Offset(x, s.height), grid); }
    for (var y = 0.0; y < s.height; y += 22) { canvas.drawLine(Offset(0, y), Offset(s.width, y), grid); }
    final p = Path()..moveTo(26, 22)..lineTo(s.width * 0.3, s.height * 0.35)..lineTo(s.width * 0.55, s.height * 0.3)..lineTo(s.width * 0.7, s.height * 0.62)..lineTo(s.width - 60, s.height - 24);
    canvas.drawPath(p, Paint()..color = GamyaColors.info..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
