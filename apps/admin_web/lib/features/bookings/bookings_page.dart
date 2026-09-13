import 'package:file_picker/file_picker.dart';
import '../../core/pick.dart';
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
import 'booking_form.dart';

class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key, this.selectId});
  final String? selectId;
  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  final _q = ListQuery(); final _search = TextEditingController(); DateTimeRange? _range; int _tab = 0;
  Paged<Booking> _data = Paged.empty(); bool _loading = true; String? _error;
  Map<String, dynamic> _stats = {}; Map<String, dynamic> _analytics = {}; List<Map<String, dynamic>> _clients = []; List<Map<String, dynamic>> _locations = [];
  Booking? _selected; bool _detailLoading = false; final Set<String> _checked = {};
  ApiClient get api => ref.read(apiProvider);

  @override
  void initState() { super.initState(); _load(); _loadSide(); if (widget.selectId != null) _open(widget.selectId!); }
  @override
  void didUpdateWidget(covariant BookingsPage old) { super.didUpdateWidget(old); if (widget.selectId != null && widget.selectId != old.selectId) _open(widget.selectId!); }

  Future<void> _loadSide() async { try { final r = await Future.wait([api.get('/bookings/stats'), api.get('/bookings/analytics'), api.get('/clients'), api.get('/locations')]); if (mounted) setState(() { _stats = api.data(r[0]); _analytics = api.data(r[1]); _clients = api.list(r[2]); _locations = api.list(r[3]); }); } catch (_) {} }
  Future<void> _load() async { setState(() { _loading = true; _error = null; }); try { final d = await api.paged('/bookings', Booking.new, query: _q.toQuery()); if (mounted) setState(() { _data = d; _loading = false; }); } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); } }
  Future<void> _open(String id) async { setState(() => _detailLoading = true); try { final r = await api.get('/bookings/$id'); if (mounted) setState(() => _selected = Booking(api.data(r))); } catch (e) { if (mounted) toast(context, e.msg, error: true); } if (mounted) setState(() => _detailLoading = false); }
  Future<void> _after(Future<void> Function() f, [String? ok]) async { try { await f(); if (ok != null && mounted) toast(context, ok); await _load(); await _loadSide(); if (_selected != null) await _open(_selected!.id); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  Future<void> _edit([Booking? b]) async { final saved = await showDialog<bool>(context: context, builder: (_) => BookingFormDialog(existing: b, clients: _clients, locations: _locations)); if (saved == true) { await _load(); await _loadSide(); if (b != null) _open(b.id); } }
  Future<void> _confirm(Booking b) async { if (!await confirmDialog(context, title: 'Confirm Booking', message: 'Confirm ${b.code} for ${b.employeeName}?', confirmLabel: 'Confirm Booking')) return; await _after(() => api.post('/bookings/${b.id}/confirm'), 'Booking confirmed'); }
  Future<void> _cancel(Booking b) async { final r = await reasonDialog(context, title: 'Cancel ${b.code}', label: 'Reason', confirmLabel: 'Cancel Booking', danger: true); if (r == null) return; await _after(() => api.post('/bookings/${b.id}/cancel', body: {'reason': r}), 'Booking cancelled'); }
  Future<void> _assign(Booking b) async {
    final v = await pickFromList(context, title: 'Assign Vehicle / Driver for ${b.code}', fetch: (q) async => (api.data(await api.get('/vehicles', query: {'q': q, 'pageSize': 40, 'status': 'ACTIVE'}))['items'] as List).cast<Map<String, dynamic>>(), tile: (v) => Row(children: [NetImage(v['photoUrl'] as String?, width: 56, height: 36, placeholderIcon: Icons.directions_car), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${v['number']}  ·  ${v['makeModel']}', style: const TextStyle(fontWeight: FontWeight.w600)), Text('${Fmt.vehicleType(v['type'] as String?)} · ${(v['driver'] as Map?)?['fullName'] ?? 'No driver'}', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))]))]));
    if (v == null) return;
    if (v['driver'] == null) { if (mounted) toast(context, 'Vehicle has no assigned driver', error: true); return; }
    await _after(() => api.post('/bookings/${b.id}/assign', body: {'vehicleId': v['id']}), 'Assigned ${v['number']}');
  }
  Future<void> _export() async { try { await downloadTextFile('bookings.csv', await api.getText('/bookings/export', query: _q.filters)); if (mounted) toast(context, 'Export downloaded'); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }
  Future<void> _import() async {
    final files = await pickUploadFiles(type: FileType.custom, extensions: ['csv']);
    if (files.isEmpty) return;
    try { final res = await api.post('/bookings/import', body: {'csv': String.fromCharCodes(files.first.bytes)}); final d = api.data(res); if (mounted) { toast(context, 'Imported ${d['imported']} bookings, ${d['failed']} failed'); await _load(); await _loadSide(); } } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }

  @override
  Widget build(BuildContext context) {
    num n(dynamic v) => (v as num?) ?? 0;
    final trend = ((_analytics['trend'] as List?) ?? []).cast<Map<String, dynamic>>(); final byStatus = ((_analytics['byStatus'] as List?) ?? []).cast<Map<String, dynamic>>(); final top = ((_analytics['topClients'] as List?) ?? []).cast<Map<String, dynamic>>();
    num st(String s) => byStatus.where((x) => x['status'] == s).fold<num>(0, (a, x) => a + n(x['count']));
    return PageBody(children: [
      PageHeader(title: 'Booking Management', breadcrumb: 'Booking Management', subtitle: 'Manage regular and ad-hoc bookings, assign vehicles, track status, and ensure smooth operations.', actions: [OutlineButton(label: 'Import Bookings', icon: Icons.upload_outlined, onPressed: _import), OutlineButton(label: 'Export', icon: Icons.download_outlined, onPressed: _export), GoldButton(label: 'New Booking', icon: Icons.add, onPressed: () => _edit())]),
      const SizedBox(height: 14),
      StatGrid(cards: [
        StatCard(label: 'Total Bookings', value: Fmt.number(_stats['total']), icon: Icons.event_note, trend: '+${n(_stats['newThisWeek'])} from last week', trendPositive: true),
        StatCard(label: 'Confirmed', value: Fmt.number(_stats['confirmed']), icon: Icons.check_circle, iconColor: GamyaColors.success, trend: '${n(_stats['confirmedPct'])}%', trendPositive: true, trendIcon: Icons.verified),
        StatCard(label: 'Pending', value: Fmt.number(_stats['pending']), icon: Icons.schedule, iconColor: GamyaColors.warning, trend: '${n(_stats['pendingPct'])}%', trendColor: GamyaColors.warning, trendIcon: Icons.timelapse, onTap: () { _q.set('status', 'PENDING'); _load(); }),
        StatCard(label: 'Cancelled', value: Fmt.number(_stats['cancelled']), icon: Icons.cancel, iconColor: GamyaColors.danger, trend: '${n(_stats['cancelledPct'])}%', trendPositive: false),
        StatCard(label: 'Unique Employees', value: Fmt.number(_stats['uniqueEmployees']), icon: Icons.groups, trend: 'across all clients', trendColor: GamyaColors.success, trendIcon: Icons.arrow_upward),
        StatCard(label: 'Est. Revenue (This Month)', value: Fmt.inr(_stats['estRevenue']), icon: Icons.currency_rupee, trend: '${n(_stats['revenueGrowthPct']) >= 0 ? '+' : ''}${n(_stats['revenueGrowthPct'])}%', trendPositive: n(_stats['revenueGrowthPct']) >= 0),
      ]),
      const SizedBox(height: 12),
      MasterDetail(
        master: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Align(alignment: Alignment.centerLeft, child: PillTabs(tabs: ['All Bookings (${n(_stats['total'])})', 'Regular (${n(_stats['regular'])})', 'Ad-hoc (${n(_stats['adhoc'])})'], selected: _tab, onChanged: (i) { setState(() => _tab = i); _q.set('tripType', i == 1 ? 'REGULAR' : i == 2 ? 'ADHOC' : null); _load(); }))),
          FilterBar(children: [
            DateRangeButton(range: _range, onChanged: (r) { setState(() => _range = r); _q.set('from', r == null ? null : Fmt.iso(r.start)); _q.set('to', r == null ? null : Fmt.iso(r.end)); _load(); }),
            FilterDropdown<String>(label: 'All Clients', value: _q.filters['clientId'] as String?, items: [for (final c in _clients) ddItem(c['id'] as String, c['name'] as String)], onChanged: (v) { _q.set('clientId', v); _load(); }),
            FilterDropdown<String>(label: 'All Locations', value: _q.filters['location'] as String?, items: [for (final l in _locations) ddItem(l['name'] as String, l['name'] as String)], onChanged: (v) { _q.set('location', v); _load(); }),
            FilterDropdown<String>(label: 'All Status', value: _q.filters['status'] as String?, width: 130, items: [ddItem('PENDING', 'Pending'), ddItem('CONFIRMED', 'Confirmed'), ddItem('RESCHEDULED', 'Rescheduled'), ddItem('COMPLETED', 'Completed'), ddItem('CANCELLED', 'Cancelled')], onChanged: (v) { _q.set('status', v); _load(); }),
            FilterDropdown<String>(label: 'All Trip Types', value: _q.filters['tripType'] as String?, width: 130, items: [ddItem('REGULAR', 'Regular'), ddItem('ADHOC', 'Ad-hoc')], onChanged: (v) { _q.set('tripType', v); setState(() => _tab = v == 'REGULAR' ? 1 : v == 'ADHOC' ? 2 : 0); _load(); }),
            SearchField(controller: _search, hint: 'Search by booking ID, employee name…', width: 230, onSubmitted: (v) { _q.set('q', v); _load(); }),
          ], onApply: () { _q.set('q', _search.text); _load(); }, onReset: () { _q.reset(); _search.clear(); setState(() { _range = null; _tab = 0; }); _load(); }),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GTable<Booking>(
              columns: const [GColumn('Booking ID', width: 140), GColumn('Date', width: 90), GColumn('Employee Name', width: 120), GColumn('Client', width: 90), GColumn('Trip Type', width: 70), GColumn('From → To', flex: 2), GColumn('Vehicle No.', width: 100), GColumn('Driver Name', width: 120), GColumn('Status', width: 95), GColumn('Actions', width: 140)],
              rows: _data.items, loading: _loading, error: _error, onRetry: _load, rowId: (b) => b.id, selected: _checked, onSelect: (id, s) => setState(() => s ? _checked.add(id) : _checked.remove(id)), onSelectAll: (s) => setState(() => s ? _checked.addAll(_data.items.map((e) => e.id)) : _checked.clear()), selectedRow: _selected, onRowTap: (b) => _open(b.id),
              cells: (b, i) => [CellText(b.code, bold: true, color: GamyaColors.info), CellText(Fmt.date(b.date)), CellText(b.employeeName), CellText(b.clientName), CellText(b.tripTypeLabel, color: b.tripType == 'ADHOC' ? GamyaColors.danger : null), RouteText(b.fromLocation, b.toLocation), CellText(b.vehicle?['number'] as String?), CellText(b.driver?['fullName'] as String?), StatusChip(b.status, small: true), RowActions(onView: () => _open(b.id), onEdit: () => _edit(b), extra: [const SizedBox(width: 4), TableIconButton(icon: Icons.receipt_long_outlined, tooltip: 'Trip', onPressed: b.trip == null ? null : () => context.go('${b.trip!['status'] == 'COMPLETED' ? '/completed-trips' : '/live-trips'}?id=${b.trip!['id']}'))], more: () => [if (b.status == 'PENDING' || b.status == 'RESCHEDULED') PopupMenuItem(onTap: () => _confirm(b), child: const Text('Confirm booking')), if (!['COMPLETED', 'CANCELLED'].contains(b.status)) PopupMenuItem(onTap: () => _assign(b), child: const Text('Assign vehicle / driver')), if (!['COMPLETED', 'CANCELLED'].contains(b.status)) PopupMenuItem(onTap: () => _cancel(b), child: const Text('Cancel booking', style: TextStyle(color: GamyaColors.danger)))])],
            ),
            const SizedBox(height: 10),
            PaginationBar(paged: _data, noun: 'bookings', onPage: (p) { _q.page = p; _load(); }, onPageSize: (s) { _q.pageSize = s; _q.page = 1; _load(); }),
          ]))),
          const SizedBox(height: 12),
          CardRow(minWidth: 240, flex: const [4, 3, 3, 3], children: [
            SectionCard(title: 'Bookings Trend (Last 14 Days)', child: LineChart(height: 150, labels: [for (final t in trend) Fmt.dateShort(t['date'])], series: [LineSeries(label: 'Regular', values: [for (final t in trend) n(t['regular'])], color: GamyaColors.gold), LineSeries(label: 'Ad-hoc', values: [for (final t in trend) n(t['adhoc'])], color: GamyaColors.dark)])),
            SectionCard(title: 'Booking Status', child: Center(child: DonutChart(size: 110, slices: [ChartSlice(label: 'Confirmed', value: st('CONFIRMED') + st('COMPLETED'), color: GamyaColors.success), ChartSlice(label: 'Pending', value: st('PENDING'), color: GamyaColors.warning), ChartSlice(label: 'Cancelled', value: st('CANCELLED'), color: GamyaColors.danger), ChartSlice(label: 'Rescheduled', value: st('RESCHEDULED'), color: GamyaColors.info)]))),
            SectionCard(title: 'Top 10 Clients by Bookings', trailing: ViewAllLink(onTap: () => context.go('/reports')), child: HBarList(labelWidth: 80, items: [for (final c in top.take(10)) ChartSlice(label: c['name'] as String, value: n(c['count']), color: GamyaColors.info)])),
            SectionCard(title: 'Trip Type Distribution', child: Center(child: DonutChart(size: 110, slices: [ChartSlice(label: 'Regular', value: n(_stats['regular']), color: GamyaColors.gold), ChartSlice(label: 'Ad-hoc', value: n(_stats['adhoc']), color: GamyaColors.dark)]))),
          ]),
        ]),
        detail: _selected == null && !_detailLoading ? null : _detailLoading ? const Card(child: LoadingState(height: 240)) : _detail(_selected!),
      ),
    ]);
  }

  Widget _detail(Booking b) {
    final closed = ['COMPLETED', 'CANCELLED'].contains(b.status);
    return DetailPanel(
      title: 'Booking Details', onClose: () => setState(() => _selected = null),
      header: Row(children: [Text(b.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(width: 10), StatusChip(b.status, small: true, dot: false), const Spacer(), StatusChip(b.tripType, label: b.tripTypeLabel, small: true, dot: false)]),
      tabs: const ['Details', 'Trip Details', 'Employee Details', 'Vehicle & Driver', 'History'],
      tabViews: [
        Column(children: [KeyValueRow('Booking ID', b.code), KeyValueRow('Booking Date', Fmt.dateTime(b.date)), KeyValueRow('Client', b.clientName), KeyValueRow('Employee', '${b.employeeName}${b.employeeMobile != null ? ' (${b.employeeMobile})' : ''}'), KeyValueRow('Trip Type', b.tripTypeLabel), KeyValueRow('From', b.fromLocation), KeyValueRow('To', b.toLocation), KeyValueRow('Date of Travel', Fmt.date(b.date)), KeyValueRow('No. of Passengers', '${b.passengers}'), KeyValueRow('Vehicle No.', b.vehicle == null ? null : '${b.vehicle!['number']} (${Fmt.vehicleType(b.vehicle!['type'] as String?)})'), KeyValueRow('Driver Name', b.driver == null ? null : '${b.driver!['fullName']} (${b.driver!['mobile'] ?? ''})'), KeyValueRow('Status', null, valueWidget: Align(alignment: Alignment.centerLeft, child: StatusChip(b.status, small: true))), KeyValueRow('Estimated Amount', Fmt.inr(b.estimatedAmount)), if (b.notes != null) KeyValueRow('Notes', b.notes), if (b.cancelReason != null) KeyValueRow('Cancel Reason', b.cancelReason)]),
        b.trip == null ? const EmptyState(icon: Icons.route_outlined, title: 'No trip created yet', message: 'Confirm the booking with a vehicle & driver assigned to create the trip.') : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [KeyValueRow('Trip ID', b.trip!['code'] as String?), KeyValueRow('Trip Status', null, valueWidget: Align(alignment: Alignment.centerLeft, child: StatusChip(b.trip!['status'] as String?, small: true))), KeyValueRow('Started', Fmt.dateTime(b.trip!['startedAt'])), KeyValueRow('Completed', Fmt.dateTime(b.trip!['completedAt'])), const SizedBox(height: 10), TrackingTimeline(steps: TrackingTimeline.fromTrip(events: ((b.trip!['events'] as List?) ?? []).cast<Map<String, dynamic>>(), status: b.trip!['status'] as String, platformName: b.platform?.name ?? 'Platform', createdAt: b.raw['createdAt'])), TextButton.icon(onPressed: () => context.go('${b.trip!['status'] == 'COMPLETED' ? '/completed-trips' : '/live-trips'}?id=${b.trip!['id']}'), icon: const Icon(Icons.open_in_new, size: 14), label: const Text('Open trip'))]),
        Column(children: [KeyValueRow('Employee Name', b.employeeName), KeyValueRow('Mobile', b.employeeMobile), KeyValueRow('Email', b.employeeEmail), KeyValueRow('Client', b.clientName), KeyValueRow('Supervisor', b.supervisor?['fullName'] as String?)]),
        Column(children: [
          if (b.vehicle == null) const EmptyState(icon: Icons.local_taxi_outlined, title: 'No vehicle assigned') else Row(children: [NetImage(b.vehicle!['photoUrl'] as String?, width: 90, height: 58, placeholderIcon: Icons.directions_car), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(b.vehicle!['number'] as String, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${b.vehicle!['make']} ${b.vehicle!['model']} · ${Fmt.vehicleType(b.vehicle!['type'] as String?)}', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))]))]),
          const SizedBox(height: 10),
          if (b.driver != null) Row(children: [GamyaAvatar(url: b.driver!['avatarUrl'] as String?, name: b.driver!['fullName'] as String?, size: 40), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(b.driver!['fullName'] as String, style: const TextStyle(fontWeight: FontWeight.w600)), Text('${b.driver!['code']} · ${b.driver!['mobile']}', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))])), TextButton(onPressed: () => context.go('/drivers?id=${b.driver!['id']}'), child: const Text('Open'))]),
          if (b.platform != null) Padding(padding: const EdgeInsets.only(top: 8), child: Align(alignment: Alignment.centerLeft, child: PlatformChip(name: b.platform!.name, color: b.platform!.color))),
        ]),
        ActivityList(items: b.activities, compact: true),
      ],
      footer: closed ? null : Column(children: [
        Row(children: [Expanded(child: GoldButton(label: 'Confirm Booking', color: GamyaColors.success, dense: true, onPressed: b.status == 'CONFIRMED' ? null : () => _confirm(b))), const SizedBox(width: 8), Expanded(child: OutlineButton(label: 'Cancel Booking', color: GamyaColors.danger, dense: true, onPressed: () => _cancel(b)))]),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: OutlineButton(label: 'Edit Booking', dense: true, onPressed: () => _edit(b))), const SizedBox(width: 8), Expanded(child: OutlineButton(label: 'Assign Vehicle/Driver', dense: true, onPressed: () => _assign(b)))]),
      ]),
      child: const SizedBox.shrink(),
    );
  }
}
