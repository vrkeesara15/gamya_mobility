import 'dart:async';
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

/// Live Trips (view = live) and Completed Trips (view = completed).
class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key, required this.view, this.selectId});
  final String view; final String? selectId;
  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends ConsumerState<TripsPage> {
  final _q = ListQuery(); final _search = TextEditingController(); DateTimeRange? _range; Timer? _timer;
  Paged<Trip> _data = Paged.empty(); bool _loading = true; String? _error; Map<String, dynamic> _stats = {}; List<PlatformInfo> _platforms = [];
  Trip? _selected; bool _detailLoading = false;
  bool get live => widget.view == 'live';
  ApiClient get api => ref.read(apiProvider);

  @override
  void initState() { super.initState(); _q.set('view', widget.view); _load(); _loadSide(); if (widget.selectId != null) _open(widget.selectId!); if (live) _timer = Timer.periodic(const Duration(seconds: 30), (_) { _load(); _loadSide(); }); }
  @override
  void didUpdateWidget(covariant TripsPage old) { super.didUpdateWidget(old); if (old.view != widget.view) { _q.reset(); _q.set('view', widget.view); _selected = null; _load(); _loadSide(); } if (widget.selectId != null && widget.selectId != old.selectId) _open(widget.selectId!); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _loadSide() async { try { final r = await Future.wait([api.get('/trips/stats'), api.get('/platforms')]); if (mounted) setState(() { _stats = api.data(r[0]); _platforms = api.list(r[1]).map(PlatformInfo.new).toList(); }); } catch (_) {} }
  Future<void> _load() async { if (mounted) setState(() { _loading = _data.items.isEmpty; _error = null; }); try { final d = await api.paged('/trips', Trip.new, query: _q.toQuery()); if (mounted) setState(() { _data = d; _loading = false; }); } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); } }
  Future<void> _open(String id) async { setState(() => _detailLoading = true); try { final r = await api.get('/trips/$id'); if (mounted) setState(() => _selected = Trip(api.data(r))); } catch (e) { if (mounted) toast(context, e.msg, error: true); } if (mounted) setState(() => _detailLoading = false); }
  Future<void> _after(Future<void> Function() f, [String? ok]) async { try { await f(); if (ok != null && mounted) toast(context, ok); await _load(); await _loadSide(); if (_selected != null) await _open(_selected!.id); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }
  Future<void> _setStatus(Trip t, String status) async { final note = await reasonDialog(context, title: 'Set ${t.code} to ${Fmt.title(status)}', label: 'Note (optional)', confirmLabel: 'Update', danger: status == 'CANCELLED'); if (note == null) return; await _after(() => api.patch('/trips/${t.id}/status', body: {'status': status, 'note': note}), 'Trip updated'); }
  Future<void> _complete(Trip t) async { final c = TextEditingController(text: t.amount?.toString() ?? ''); final ok = await showDialog<bool>(context: context, builder: (ctx) => FormDialog(title: 'Complete ${t.code}', width: 420, saveLabel: 'Mark Completed', onSave: () => Navigator.pop(ctx, true), child: TextField(controller: c, decoration: const InputDecoration(labelText: 'Trip amount (₹)'), keyboardType: TextInputType.number))); if (ok == true) await _after(() => api.post('/trips/${t.id}/complete', body: {'amount': num.tryParse(c.text)}), 'Trip completed'); }
  Future<void> _export() async { try { await downloadTextFile('trips.csv', await api.getText('/reports/export', query: {'type': 'trips', if (_range != null) 'from': Fmt.iso(_range!.start), if (_range != null) 'to': Fmt.iso(_range!.end)})); if (mounted) toast(context, 'Export downloaded'); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  @override
  Widget build(BuildContext context) {
    num n(dynamic v) => (v as num?) ?? 0;
    return PageBody(children: [
      PageHeader(title: live ? 'Live Trips' : 'Completed Trips', breadcrumb: live ? 'Live Trips' : 'Completed Trips', subtitle: live ? 'Trips currently on the road – auto refreshes every 30 seconds.' : 'History of completed trips with on-time performance and amounts.', actions: [OutlineButton(label: 'Refresh', icon: Icons.refresh, onPressed: () { _load(); _loadSide(); }), OutlineButton(label: 'Export', icon: Icons.download_outlined, onPressed: _export)]),
      const SizedBox(height: 14),
      StatGrid(cards: live ? [
        StatCard(label: 'Live Trips', value: '${n(_stats['live'])}', icon: Icons.navigation, iconColor: GamyaColors.success, trend: 'Live on road', trendColor: GamyaColors.success, trendIcon: Icons.circle),
        StatCard(label: 'On Trip', value: '${n(_stats['onTrip'])}', icon: Icons.local_taxi, trend: 'In progress', trendColor: GamyaColors.info, trendIcon: Icons.play_arrow),
        StatCard(label: 'Delayed', value: '${n(_stats['delayed'])}', icon: Icons.warning_amber_rounded, iconColor: GamyaColors.danger, trend: 'Needs attention', trendPositive: false),
        StatCard(label: 'Yet to Start (Today)', value: '${n(_stats['yetToStart'])}', icon: Icons.schedule, iconColor: GamyaColors.warning, trend: 'Scheduled today', trendColor: GamyaColors.warning),
        StatCard(label: 'Completed Today', value: '${n(_stats['completedToday'])}', icon: Icons.check_circle, iconColor: GamyaColors.success, trend: '${n(_stats['completedGrowthPct']) >= 0 ? '+' : ''}${n(_stats['completedGrowthPct'])}% vs yesterday', trendPositive: n(_stats['completedGrowthPct']) >= 0),
        StatCard(label: 'Cancelled Today', value: '${n(_stats['cancelledToday'])}', icon: Icons.cancel, iconColor: GamyaColors.neutral, trend: 'Today', trendColor: GamyaColors.neutral, trendIcon: Icons.remove),
      ] : [
        StatCard(label: 'Total Completed', value: Fmt.number(_stats['completed']), icon: Icons.check_circle, iconColor: GamyaColors.success, trend: 'All time', trendColor: GamyaColors.success, trendIcon: Icons.history),
        StatCard(label: 'Completed Today', value: '${n(_stats['completedToday'])}', icon: Icons.today, trend: '${n(_stats['onTimeToday'])} on time', trendPositive: true),
        StatCard(label: 'Completed Yesterday', value: '${n(_stats['completedYesterday'])}', icon: Icons.event_available, trend: '${n(_stats['completedGrowthPct']) >= 0 ? '+' : ''}${n(_stats['completedGrowthPct'])}% today', trendPositive: n(_stats['completedGrowthPct']) >= 0),
        StatCard(label: 'Total Trips', value: Fmt.number(_stats['total']), icon: Icons.route, trend: 'Including live & cancelled', trendColor: GamyaColors.textMuted, trendIcon: Icons.info_outline),
      ]),
      const SizedBox(height: 12),
      MasterDetail(
        master: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilterBar(children: [
            if (!live) DateRangeButton(range: _range, onChanged: (r) { setState(() => _range = r); _q.set('from', r == null ? null : Fmt.iso(r.start)); _q.set('to', r == null ? null : Fmt.iso(r.end)); _load(); }),
            if (live) FilterDropdown<String>(label: 'All Status', value: _q.filters['status'] as String?, width: 130, items: [ddItem('ON_TRIP', 'On Trip'), ddItem('DELAYED', 'Delayed'), ddItem('ACCEPTED', 'Accepted'), ddItem('YET_TO_START', 'Yet to Start')], onChanged: (v) { _q.set('status', v); _load(); }),
            FilterDropdown<String>(label: 'All Platforms', value: _q.filters['platform'] as String?, items: [for (final p in _platforms) ddItem(p.id, p.name)], onChanged: (v) { _q.set('platform', v); _load(); }),
            SearchField(controller: _search, hint: 'Search by trip ID, driver, vehicle, route…', width: 260, onSubmitted: (v) { _q.set('q', v); _load(); }),
          ], onApply: () { _q.set('q', _search.text); _load(); }, onReset: () { _q.reset(); _q.set('view', widget.view); _search.clear(); setState(() => _range = null); _load(); }),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GTable<Trip>(
              columns: [const GColumn('Trip ID', width: 120), const GColumn('Driver Name', width: 150), const GColumn('Vehicle No.', width: 100), const GColumn('Platform', width: 125), const GColumn('Client', width: 100), const GColumn('Route', flex: 2), GColumn(live ? 'Scheduled' : 'Completed At', width: 120), if (!live) const GColumn('On Time', width: 70), if (!live) const GColumn('Amount', width: 80, numeric: true), const GColumn('Status', width: 95), const GColumn('Actions', width: 80)],
              rows: _data.items, loading: _loading, error: _error, onRetry: _load, rowId: (t) => t.id, selectedRow: _selected, onRowTap: (t) => _open(t.id), emptyText: live ? 'No trips on the road right now' : 'No completed trips',
              cells: (t, i) => [CellText(t.code, bold: true), PersonCell(name: t.driver['fullName'] as String? ?? '', avatarUrl: t.driver['avatarUrl'] as String?, subtitle: t.driver['mobile'] as String?), CellText(t.vehicle['number'] as String?), PlatformChip(name: t.platformName, color: t.platform?.color, compact: true), CellText(t.clientName), RouteText(t.fromLocation, t.toLocation), CellText(Fmt.dateTimeShort(live ? t.scheduledStart : t.completedAt), maxLines: 2), if (!live) StatusChip(t.onTime == false ? 'DELAYED' : 'ON TIME', label: t.onTime == false ? 'No' : 'Yes', small: true, dot: false), if (!live) CellText(Fmt.inr(t.amount), bold: true), StatusChip(t.status, small: true), RowActions(onView: () => _open(t.id), more: live ? () => [if (t.status != 'ON_TRIP') PopupMenuItem(onTap: () => _setStatus(t, 'ON_TRIP'), child: const Text('Mark on trip')), if (t.status != 'DELAYED') PopupMenuItem(onTap: () => _setStatus(t, 'DELAYED'), child: const Text('Mark delayed')), PopupMenuItem(onTap: () => _complete(t), child: const Text('Mark completed')), PopupMenuItem(onTap: () => _setStatus(t, 'CANCELLED'), child: const Text('Cancel trip', style: TextStyle(color: GamyaColors.danger)))] : null)],
            ),
            const SizedBox(height: 10),
            PaginationBar(paged: _data, noun: 'trips', onPage: (p) { _q.page = p; _load(); }, onPageSize: (s) { _q.pageSize = s; _q.page = 1; _load(); }),
          ]))),
        ]),
        detail: _selected == null && !_detailLoading ? null : _detailLoading ? const Card(child: LoadingState(height: 240)) : _detail(_selected!),
      ),
    ]);
  }

  Widget _detail(Trip t) => DetailPanel(
    title: 'Trip Details', onClose: () => setState(() => _selected = null),
    header: Row(children: [Text(t.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(width: 10), StatusChip(t.status, small: true), const Spacer(), PlatformChip(name: t.platformName, color: t.platform?.color, compact: true)]),
    tabs: const ['Details', 'Timeline', 'Driver & Vehicle'],
    tabViews: [
      Column(children: [KeyValueRow('Trip ID', t.code), if (t.adhocCode != null) KeyValueRow('Ad-hoc Request', t.adhocCode, valueWidget: Align(alignment: Alignment.centerLeft, child: InkWell(onTap: () => context.go('/adhoc?id=${t.raw['adhocRequestId']}'), child: Text(t.adhocCode!, style: const TextStyle(color: GamyaColors.info, fontSize: 12.5, fontWeight: FontWeight.w600))))), if (t.bookingCode != null) KeyValueRow('Booking', t.bookingCode, valueWidget: Align(alignment: Alignment.centerLeft, child: InkWell(onTap: () => context.go('/bookings?id=${t.raw['bookingId']}'), child: Text(t.bookingCode!, style: const TextStyle(color: GamyaColors.info, fontSize: 12.5, fontWeight: FontWeight.w600))))), KeyValueRow('Client', t.clientName), KeyValueRow('Supervisor', t.supervisor?['fullName'] as String?), KeyValueRow('From', t.fromLocation), KeyValueRow('To', t.toLocation), KeyValueRow('Scheduled', Fmt.dateTime(t.scheduledStart)), KeyValueRow('Login / Reporting', '${Fmt.time24(t.loginTime)} / ${Fmt.time24(t.reportingTime)}'), KeyValueRow('Started', Fmt.dateTime(t.startedAt)), KeyValueRow('Completed', Fmt.dateTime(t.completedAt)), KeyValueRow('Vehicle Type', Fmt.vehicleType(t.vehicleType)), KeyValueRow('Passengers', '${t.passengers}'), KeyValueRow('Amount', Fmt.inr(t.amount)), KeyValueRow('Distance', t.raw['distanceKm'] == null ? '—' : '${t.raw['distanceKm']} km'), KeyValueRow('On Time', t.onTime == null ? '—' : t.onTime! ? 'Yes' : 'No'), KeyValueRow('Platform Trip ID', t.externalTripId), if (t.raw['notes'] != null) KeyValueRow('Notes', t.raw['notes'] as String?)]),
      TrackingTimeline(steps: TrackingTimeline.fromTrip(events: t.events, status: t.status, platformName: t.platformName, createdAt: t.raw['createdAt'])),
      Column(children: [
        Row(children: [GamyaAvatar(url: t.driver['avatarUrl'] as String?, name: t.driver['fullName'] as String?, size: 44), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.driver['fullName'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)), Text('${t.driver['code']} · ${t.driver['mobile']}', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))])), TextButton(onPressed: () => context.go('/drivers?id=${t.driver['id']}'), child: const Text('Open'))]),
        const Divider(height: 20),
        Row(children: [NetImage(t.vehicle['photoUrl'] as String?, width: 90, height: 58, placeholderIcon: Icons.directions_car), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.vehicle['number'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)), Text('${t.vehicle['make']} ${t.vehicle['model']} · ${t.vehicle['year']} · ${Fmt.vehicleType(t.vehicle['type'] as String?)}', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))])), TextButton(onPressed: () => context.go('/vehicles?id=${t.vehicle['id']}'), child: const Text('Open'))]),
      ]),
    ],
    footer: !t.isLive && t.status != 'ASSIGNED' ? null : Wrap(spacing: 8, runSpacing: 8, children: [GoldButton(label: 'Mark Completed', color: GamyaColors.success, dense: true, onPressed: () => _complete(t)), if (t.status != 'DELAYED') OutlineButton(label: 'Mark Delayed', dense: true, color: GamyaColors.warning, onPressed: () => _setStatus(t, 'DELAYED')), OutlineButton(label: 'Cancel Trip', dense: true, color: GamyaColors.danger, onPressed: () => _setStatus(t, 'CANCELLED'))]),
    child: const SizedBox.shrink(),
  );
}
