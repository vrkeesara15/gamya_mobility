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
import 'driver_form.dart';

class DriversPage extends ConsumerStatefulWidget {
  const DriversPage({super.key, this.selectId});
  final String? selectId;
  @override
  ConsumerState<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends ConsumerState<DriversPage> {
  final _q = ListQuery(); final _search = TextEditingController();
  Paged<Driver> _data = Paged.empty(); bool _loading = true; String? _error;
  Map<String, dynamic> _stats = {}; Map<String, dynamic> _perf = {}; List<Map<String, dynamic>> _activities = []; List<PlatformInfo> _platforms = [];
  Driver? _selected; bool _detailLoading = false; final Set<String> _checked = {};
  ApiClient get api => ref.read(apiProvider);

  @override
  void initState() { super.initState(); _loadAll(); if (widget.selectId != null) _open(widget.selectId!); }
  @override
  void didUpdateWidget(covariant DriversPage old) { super.didUpdateWidget(old); if (widget.selectId != null && widget.selectId != old.selectId) _open(widget.selectId!); }

  Future<void> _loadAll() => Future.wait([_load(), _loadSide()]);
  Future<void> _loadSide() async {
    try {
      final r = await Future.wait([api.get('/drivers/stats'), api.get('/drivers/performance'), api.get('/drivers/activities', query: {'pageSize': 5}), api.get('/platforms')]);
      if (mounted) setState(() { _stats = api.data(r[0]); _perf = api.data(r[1]); _activities = (api.data(r[2])['items'] as List).cast<Map<String, dynamic>>(); _platforms = api.list(r[3]).map(PlatformInfo.new).toList(); });
    } catch (_) {}
  }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final d = await api.paged('/drivers', Driver.new, query: _q.toQuery()); if (mounted) setState(() { _data = d; _loading = false; }); } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); }
  }
  Future<void> _open(String id) async {
    setState(() => _detailLoading = true);
    try { final r = await api.get('/drivers/$id'); if (mounted) setState(() => _selected = Driver(api.data(r))); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _detailLoading = false);
  }
  Future<void> _after(Future<void> Function() f, [String? ok]) async { try { await f(); if (ok != null && mounted) toast(context, ok); await _load(); await _loadSide(); if (_selected != null) await _open(_selected!.id); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  Future<void> _edit([Driver? d]) async { final saved = await showDialog<bool>(context: context, builder: (_) => DriverFormDialog(existing: d, platforms: _platforms)); if (saved == true) { await _load(); await _loadSide(); if (d != null) _open(d.id); } }
  Future<void> _status(Driver d, String status) async {
    String? reason;
    if (status == 'BLACKLISTED') { reason = await reasonDialog(context, title: 'Blacklist ${d.fullName}', label: 'Reason', confirmLabel: 'Blacklist', danger: true, required: true); if (reason == null) return; }
    else if (!await confirmDialog(context, title: 'Mark ${status.toLowerCase()}', message: 'Set ${d.fullName} as ${status.toLowerCase()}?', danger: status != 'ACTIVE')) { return; }
    await _after(() => api.patch('/drivers/${d.id}/status', body: {'status': status, if (reason != null) 'reason': reason}), 'Driver marked ${status.toLowerCase()}');
  }
  Future<void> _notify(Driver d) async {
    final t = TextEditingController(); final b = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => FormDialog(title: 'Send Notification to ${d.fullName}', width: 460, saveLabel: 'Send', onSave: () => Navigator.pop(ctx, true), child: Column(children: [TextField(controller: t, decoration: const InputDecoration(labelText: 'Title')), const SizedBox(height: 12), TextField(controller: b, maxLines: 3, decoration: const InputDecoration(labelText: 'Message'))])));
    if (ok == true && t.text.trim().isNotEmpty) await _after(() => api.post('/drivers/${d.id}/notify', body: {'title': t.text, 'body': b.text}), 'Notification sent');
  }
  Future<void> _docStatus(Driver d, Map<String, dynamic> doc, String status) async {
    final remarks = status == 'REJECTED' ? await reasonDialog(context, title: 'Reject document', label: 'Remarks', confirmLabel: 'Reject', danger: true) : null;
    if (status == 'REJECTED' && remarks == null) return;
    await _after(() => api.patch('/drivers/${d.id}/documents/${doc['id']}', body: {'status': status, if (remarks != null) 'remarks': remarks}), 'Document ${status.toLowerCase()}');
  }
  Future<void> _export() async { try { await downloadTextFile('drivers.csv', await api.getText('/reports/export', query: {'type': 'drivers'})); if (mounted) toast(context, 'Export downloaded'); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  @override
  Widget build(BuildContext context) {
    num n(dynamic v) => (v as num?) ?? 0;
    return PageBody(children: [
      PageHeader(title: 'Driver Management', breadcrumb: 'Driver Management', subtitle: 'Manage driver registrations, documents, approvals and track their performance.', actions: [OutlineButton(label: 'Export', icon: Icons.download_outlined, onPressed: _export), GoldButton(label: 'Add Driver', icon: Icons.add, onPressed: () => _edit())]),
      const SizedBox(height: 14),
      StatGrid(cards: [
        StatCard(label: 'Total Drivers', value: '${n(_stats['total'])}', icon: Icons.person, trend: '+${n(_stats['newThisMonth'])} this month', trendPositive: true),
        StatCard(label: 'Active Drivers', value: '${n(_stats['active'])}', icon: Icons.how_to_reg, iconColor: GamyaColors.success, trend: '+${n(_stats['activeThisMonth'])} this month', trendPositive: true),
        StatCard(label: 'Pending Approval', value: '${n(_stats['pending'])}', icon: Icons.hourglass_bottom, iconColor: GamyaColors.warning, trend: '${n(_stats['pendingThisWeek'])} this week', trendPositive: false, onTap: () => context.go('/approvals?tab=drivers')),
        StatCard(label: 'Inactive Drivers', value: '${n(_stats['inactive'])}', icon: Icons.person_off, iconColor: GamyaColors.danger, trend: '+${n(_stats['inactiveThisWeek'])} this week', trendPositive: false),
        StatCard(label: 'Re-Verification Due', value: '${n(_stats['reVerificationDue'])}', icon: Icons.event_repeat, trend: 'Due for renewal', trendColor: GamyaColors.warning, trendIcon: Icons.warning_amber_rounded),
        StatCard(label: 'Blacklisted', value: '${n(_stats['blacklisted'])}', icon: Icons.block, iconColor: GamyaColors.danger, trend: 'View List', trendColor: GamyaColors.info, trendIcon: Icons.list, onTap: () { _q.set('status', 'BLACKLISTED'); _load(); }),
      ]),
      const SizedBox(height: 12),
      MasterDetail(
        master: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilterBar(children: [
            SearchField(controller: _search, hint: 'Search by name, mobile, vehicle number…', width: 260, onSubmitted: (v) { _q.set('q', v); _load(); }),
            FilterDropdown<String>(label: 'All Status', value: _q.filters['status'] as String?, width: 130, items: [ddItem('ACTIVE', 'Active'), ddItem('PENDING', 'Pending'), ddItem('INACTIVE', 'Inactive'), ddItem('BLACKLISTED', 'Blacklisted')], onChanged: (v) { _q.set('status', v); _load(); }),
            FilterDropdown<String>(label: 'All Vehicle Type', value: _q.filters['vehicleType'] as String?, items: [for (final t in vehicleTypeItems) ddItem(t.$1, t.$2)], onChanged: (v) { _q.set('vehicleType', v); _load(); }),
            FilterDropdown<String>(label: 'All Platforms', value: _q.filters['platform'] as String?, items: [for (final p in _platforms) ddItem(p.id, p.name)], onChanged: (v) { _q.set('platform', v); _load(); }),
          ], onReset: () { _q.reset(); _search.clear(); _load(); }, onApply: () { _q.set('q', _search.text); _load(); }),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GTable<Driver>(
              columns: const [GColumn('Driver Name', width: 150), GColumn('Photo', width: 54), GColumn('Mobile Number', width: 110), GColumn('Vehicle Number', width: 110), GColumn('Vehicle Type', width: 100), GColumn('Platform', width: 130), GColumn('Status', width: 95), GColumn('Documents', width: 80), GColumn('Actions', width: 110)],
              rows: _data.items, loading: _loading, error: _error, onRetry: _load, rowId: (d) => d.id, selected: _checked, onSelect: (id, v) => setState(() => v ? _checked.add(id) : _checked.remove(id)), onSelectAll: (v) => setState(() => v ? _checked.addAll(_data.items.map((e) => e.id)) : _checked.clear()), selectedRow: _selected, onRowTap: (d) => _open(d.id),
              cells: (d, i) => [PersonCell(name: d.fullName, avatarUrl: d.avatarUrl, subtitle: d.code), GamyaAvatar(url: d.vehicle?['photos'] is List && (d.vehicle!['photos'] as List).isNotEmpty ? (d.vehicle!['photos'] as List).first as String : d.selfieUrl, name: d.fullName, size: 30, square: true), CellText(d.mobile), CellText(d.vehicle?['number'] as String?), CellText(Fmt.vehicleType(d.vehicle?['type'] as String?)), d.platforms.isEmpty ? const PlatformChip(name: 'Other', code: 'OTHER', compact: true) : PlatformChip(name: d.platforms.first.name, color: d.platforms.first.color, compact: true), StatusChip(d.status, small: true), FractionChip(done: d.docsVerified, total: d.docsRequired), RowActions(onView: () => _open(d.id), onEdit: () => _edit(d), more: () => [PopupMenuItem(onTap: () => _notify(d), child: const Text('Send notification')), if (d.status != 'ACTIVE') PopupMenuItem(onTap: () => _status(d, 'ACTIVE'), child: const Text('Mark active')), if (d.status == 'ACTIVE') PopupMenuItem(onTap: () => _status(d, 'INACTIVE'), child: const Text('Mark inactive')), if (d.status != 'BLACKLISTED') PopupMenuItem(onTap: () => _status(d, 'BLACKLISTED'), child: const Text('Blacklist', style: TextStyle(color: GamyaColors.danger)))])],
            ),
            const SizedBox(height: 10),
            PaginationBar(paged: _data, noun: 'drivers', onPage: (p) { _q.page = p; _load(); }, onPageSize: (s) { _q.pageSize = s; _q.page = 1; _load(); }),
          ]))),
          const SizedBox(height: 12),
          CardRow(minWidth: 280, children: [
            SectionCard(title: 'Driver Performance (Last 30 Days)', child: Wrap(spacing: 8, runSpacing: 8, children: [SizedBox(width: 150, child: MiniStat(label: 'Total Trips', value: '${n(_perf['totalTrips'])}', icon: Icons.route)), SizedBox(width: 150, child: MiniStat(label: 'On Time', value: '${n(_perf['onTime'])} (${n(_perf['onTimePct'])}%)', icon: Icons.schedule)), SizedBox(width: 150, child: MiniStat(label: 'Delayed', value: '${n(_perf['delayed'])} (${n(_perf['delayedPct'])}%)', icon: Icons.block, color: GamyaColors.danger)), SizedBox(width: 150, child: MiniStat(label: 'Earnings', value: Fmt.inr(_perf['earnings'] as num?), icon: Icons.currency_rupee))])),
            SectionCard(title: 'Platform Wise Trips', child: Center(child: DonutChart(size: 110, slices: [for (final p in (_perf['platformWise'] as List? ?? []).cast<Map<String, dynamic>>()) ChartSlice(label: p['name'] as String, value: n(p['count']), color: GamyaColors.fromHex(p['color'] as String?))]))),
            SectionCard(title: 'Recent Activities', trailing: ViewAllLink(onTap: () => context.go('/reports')), child: ActivityList(items: _activities, compact: true)),
          ]),
        ]),
        detail: _selected == null && !_detailLoading ? null : _detailLoading ? const Card(child: LoadingState(height: 240)) : _detail(_selected!),
      ),
    ]);
  }

  Widget _detail(Driver d) {
    final v = d.vehicle; final perf = d.performance;
    final docLabels = {'RC': 'RC (Registration Certificate)', 'PERMIT': 'Permit', 'INSURANCE': 'Insurance', 'DRIVING_LICENCE': 'Driving Licence', 'VEHICLE_PHOTO_1': 'Vehicle Photo 1', 'VEHICLE_PHOTO_2': 'Vehicle Photo 2', 'FACE_VERIFICATION': 'Face Verification'};
    Map<String, dynamic>? doc(String t) { final l = d.documents.where((x) => x['type'] == t).toList(); return l.isEmpty ? null : l.first; }
    return DetailPanel(
      title: 'Driver Details', onClose: () => setState(() => _selected = null),
      header: Row(children: [GamyaAvatar(url: d.avatarUrl, name: d.fullName, size: 56), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), Text(d.code, style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary)), const SizedBox(height: 4), StatusChip(d.status, small: true)])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Last Active', style: TextStyle(fontSize: 10.5, color: GamyaColors.textMuted)), Text(Fmt.dateTime(d.lastActiveAt), style: const TextStyle(fontSize: 11))])]),
      tabs: const ['Details', 'Documents', 'Trips', 'Earnings', 'History'],
      tabViews: [
        Column(children: [
          PanelSection(title: 'Driver Information', trailing: TextButton.icon(onPressed: () => _edit(d), icon: const Icon(Icons.edit_outlined, size: 14), label: const Text('Edit', style: TextStyle(fontSize: 12))), child: Column(children: [KeyValueRow('Full Name', d.fullName), KeyValueRow('Mobile Number', d.mobile), KeyValueRow('Email ID', d.email), KeyValueRow('Date of Birth', Fmt.date(d.dateOfBirth)), KeyValueRow('Address', d.address), KeyValueRow('Joining Date', Fmt.date(d.joiningDate)), KeyValueRow('Platform Access', d.platformNames), KeyValueRow('Status', null, valueWidget: Align(alignment: Alignment.centerLeft, child: StatusChip(d.status, small: true))), if (d.blacklistReason != null) KeyValueRow('Blacklist Reason', d.blacklistReason)])),
          PanelSection(title: 'Vehicle Information', trailing: v == null ? null : TextButton.icon(onPressed: () => context.go('/vehicles?id=${v['id']}'), icon: const Icon(Icons.open_in_new, size: 14), label: const Text('Open', style: TextStyle(fontSize: 12))), child: v == null ? const Text('No vehicle linked', style: TextStyle(color: GamyaColors.textMuted, fontSize: 12.5)) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(children: [KeyValueRow('Vehicle Number', v['number'] as String?, labelWidth: 100), KeyValueRow('Vehicle Make', v['make'] as String?, labelWidth: 100), KeyValueRow('Model Year', '${v['year']}', labelWidth: 100), KeyValueRow('Vehicle Type', Fmt.vehicleType(v['type'] as String?), labelWidth: 100)])), Column(children: [for (final p in ((v['photos'] as List?) ?? []).take(2)) Padding(padding: const EdgeInsets.only(bottom: 6), child: InkWell(onTap: () => showImageDialog(context, p as String, title: v['number'] as String?), child: NetImage(p, width: 84, height: 54)))])])),
          PanelSection(title: 'Documents', trailing: FractionChip(done: d.docsVerified, total: d.docsRequired), child: Column(children: [for (final e in docLabels.entries) DocumentRow(label: e.value, status: doc(e.key)?['status'] as String? ?? 'MISSING', url: doc(e.key)?['fileUrl'] as String?, onView: doc(e.key) == null ? null : () => showImageDialog(context, doc(e.key)!['fileUrl'] as String?, title: e.value), onVerify: doc(e.key) == null ? null : () => _docStatus(d, doc(e.key)!, 'VERIFIED'), onReject: doc(e.key) == null ? null : () => _docStatus(d, doc(e.key)!, 'REJECTED'))])),
        ]),
        Column(children: [
          if (d.selfieUrl != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [InkWell(onTap: () => showImageDialog(context, d.selfieUrl, title: 'Live Selfie'), child: NetImage(d.selfieUrl, width: 90, height: 90)), const SizedBox(width: 10), InkWell(onTap: () => showImageDialog(context, d.idPhotoUrl ?? d.selfieUrl, title: 'ID Photo'), child: NetImage(d.idPhotoUrl ?? d.selfieUrl, width: 90, height: 90)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [StatusChip(d.faceVerified ? 'VERIFIED' : 'PENDING', label: d.faceVerified ? 'Face Matched' : 'Face Not Verified', small: true), const SizedBox(height: 6), Text(d.faceMatchScore == null ? '' : 'Match score ${(d.faceMatchScore! * 100).round()}%', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))]))])),
          for (final x in d.documents) DocumentRow(label: '${Fmt.title(x['type'] as String?)}${x['validTill'] != null ? ' · valid till ${Fmt.date(x['validTill'])}' : ''}', status: x['status'] as String, url: x['fileUrl'] as String?, onView: () => showImageDialog(context, x['fileUrl'] as String?, title: Fmt.title(x['type'] as String?)), onVerify: () => _docStatus(d, x, 'VERIFIED'), onReject: () => _docStatus(d, x, 'REJECTED')),
          if (d.documents.isEmpty) const EmptyState(title: 'No documents uploaded'),
        ]),
        Column(children: [
          Row(children: [Expanded(child: MiniStat(label: 'Trips (30d)', value: '${perf['totalTrips'] ?? 0}')), const SizedBox(width: 6), Expanded(child: MiniStat(label: 'On Time', value: '${perf['onTime'] ?? 0}')), const SizedBox(width: 6), Expanded(child: MiniStat(label: 'Delayed', value: '${perf['delayed'] ?? 0}'))]), const SizedBox(height: 10),
          if (d.trips.isEmpty) const EmptyState(title: 'No trips yet') else for (final t in d.trips.take(12)) ListTile(dense: true, contentPadding: EdgeInsets.zero, onTap: () => context.go('${t['status'] == 'COMPLETED' ? '/completed-trips' : '/live-trips'}?id=${t['id']}'), title: Text('${t['code']}  ·  ${t['fromLocation']} → ${t['toLocation']}', style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${Fmt.dateTimeShort(t['scheduledStart'])} · ${(t['platform'] as Map?)?['name'] ?? 'Other'}', style: const TextStyle(fontSize: 11)), trailing: StatusChip(t['status'] as String?, small: true)),
        ]),
        Column(children: [
          MiniStat(label: 'Earnings (last 30 days)', value: Fmt.inr(perf['earnings'] as num?), icon: Icons.currency_rupee), const SizedBox(height: 10),
          if (d.earnings.isEmpty) const EmptyState(title: 'No earnings yet') else for (final e in d.earnings.take(12)) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('${Fmt.date(e['date'])}  ·  ${(e['trip'] as Map?)?['code'] ?? ''}', style: const TextStyle(fontSize: 12.5)), subtitle: Text('${((e['trip'] as Map?)?['platform'] as Map?)?['name'] ?? 'Other'} · ${Fmt.title(e['status'] as String?)}', style: const TextStyle(fontSize: 11)), trailing: Text(Fmt.inr(e['amount'] as num?), style: const TextStyle(fontWeight: FontWeight.w700, color: GamyaColors.success))),
        ]),
        ActivityList(items: d.activities, compact: true),
      ],
      footer: Wrap(spacing: 8, runSpacing: 8, children: [OutlineButton(label: d.status == 'ACTIVE' ? 'Mark Inactive' : 'Mark Active', icon: d.status == 'ACTIVE' ? Icons.pause_circle_outline : Icons.play_circle_outline, dense: true, color: d.status == 'ACTIVE' ? GamyaColors.goldDark : GamyaColors.success, onPressed: () => _status(d, d.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE')), if (d.status != 'BLACKLISTED') OutlineButton(label: 'Blacklist', icon: Icons.block, dense: true, color: GamyaColors.danger, onPressed: () => _status(d, 'BLACKLISTED')), GoldButton(label: 'Send Notification', icon: Icons.send_outlined, dense: true, onPressed: () => _notify(d))]),
      child: const SizedBox.shrink(),
    );
  }
}
