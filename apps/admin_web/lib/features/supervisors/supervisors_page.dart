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
import 'supervisor_form.dart';

class SupervisorsPage extends ConsumerStatefulWidget {
  const SupervisorsPage({super.key, this.selectId});
  final String? selectId;
  @override
  ConsumerState<SupervisorsPage> createState() => _SupervisorsPageState();
}

class _SupervisorsPageState extends ConsumerState<SupervisorsPage> {
  final _q = ListQuery(); final _search = TextEditingController();
  Paged<Supervisor> _data = Paged.empty(); bool _loading = true; String? _error;
  Map<String, dynamic> _stats = {}; List<Map<String, dynamic>> _activities = []; List<Map<String, dynamic>> _locations = [];
  Supervisor? _selected; bool _detailLoading = false; int _tab = 0; final Set<String> _checked = {};

  ApiClient get api => ref.read(apiProvider);

  @override
  void initState() { super.initState(); _loadAll(); if (widget.selectId != null) _open(widget.selectId!); }
  @override
  void didUpdateWidget(covariant SupervisorsPage old) { super.didUpdateWidget(old); if (widget.selectId != null && widget.selectId != old.selectId) _open(widget.selectId!); }

  Future<void> _loadAll() async { await Future.wait([_load(), _loadStats(), _loadLocations()]); }
  Future<void> _loadStats() async { try { final r = await api.get('/supervisors/stats'); final a = await api.get('/supervisors/activities', query: {'pageSize': 5}); if (mounted) setState(() { _stats = api.data(r); _activities = (api.data(a)['items'] as List).cast<Map<String, dynamic>>(); }); } catch (_) {} }
  Future<void> _loadLocations() async { try { final r = await api.get('/locations'); if (mounted) setState(() => _locations = api.list(r)); } catch (_) {} }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final d = await api.paged('/supervisors', Supervisor.new, query: _q.toQuery()); if (mounted) setState(() { _data = d; _loading = false; }); }
    catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); }
  }
  Future<void> _open(String id) async {
    setState(() => _detailLoading = true);
    try { final r = await api.get('/supervisors/$id'); if (mounted) setState(() => _selected = Supervisor(api.data(r))); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _detailLoading = false);
  }
  Future<void> _refreshAfter(Future<void> Function() f) async { try { await f(); await _load(); await _loadStats(); if (_selected != null) await _open(_selected!.id); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  Future<void> _export() async {
    try { final csv = await api.getText('/reports/export', query: {'type': 'supervisors'}); await downloadTextFile('supervisors.csv', csv); if (mounted) toast(context, 'Export downloaded'); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }

  Future<void> _edit([Supervisor? s]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => SupervisorFormDialog(existing: s, locations: _locations));
    if (saved == true) { await _load(); await _loadStats(); if (s != null) _open(s.id); }
  }

  Future<void> _setStatus(Supervisor s, String status) async {
    if (!await confirmDialog(context, title: 'Mark ${status.toLowerCase()}', message: 'Set ${s.fullName} as ${status.toLowerCase()}?', danger: status != 'ACTIVE')) return;
    await _refreshAfter(() => api.patch('/supervisors/${s.id}/status', body: {'status': status}));
  }

  Future<void> _resetPassword(Supervisor s) async {
    if (!await confirmDialog(context, title: 'Reset Password', message: 'Generate a new temporary password for ${s.fullName}?')) return;
    try { final r = await api.post('/supervisors/${s.id}/reset-password', body: {}); if (mounted) showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Temporary password'), content: SelectableText(api.data(r)['temporaryPassword'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))])); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }

  Future<void> _notify(Supervisor? s) async {
    final t = TextEditingController(); final b = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => FormDialog(title: s == null ? 'Send Notification to all Supervisors' : 'Send Notification to ${s.fullName}', width: 460, saveLabel: 'Send', onSave: () => Navigator.pop(ctx, true), child: Column(children: [TextField(controller: t, decoration: const InputDecoration(labelText: 'Title')), const SizedBox(height: 12), TextField(controller: b, maxLines: 3, decoration: const InputDecoration(labelText: 'Message'))])));
    if (ok != true || t.text.trim().isEmpty) return;
    try { if (s == null) { await api.post('/notifications/send', body: {'title': t.text, 'body': b.text, 'audience': 'SUPERVISORS'}); } else { await api.post('/supervisors/${s.id}/notify', body: {'title': t.text, 'body': b.text}); } if (mounted) toast(context, 'Notification sent'); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }

  @override
  Widget build(BuildContext context) {
    num n(dynamic v) => (v as num?) ?? 0;
    return PageBody(children: [
      PageHeader(title: 'Supervisor Management', breadcrumb: 'Supervisor Management', subtitle: 'Manage supervisors, assign locations, and control access to the platform.', actions: [OutlineButton(label: 'Export', icon: Icons.download_outlined, onPressed: _export), GoldButton(label: 'Add Supervisor', icon: Icons.add, onPressed: () => _edit())]),
      const SizedBox(height: 14),
      StatGrid(cards: [
        StatCard(label: 'Total Supervisors', value: '${n(_stats['total'])}', icon: Icons.supervisor_account, trend: '+${n(_stats['newThisWeek'])} this week', trendPositive: true),
        StatCard(label: 'Active Supervisors', value: '${n(_stats['active'])}', icon: Icons.person, iconColor: GamyaColors.success, trend: '+${n(_stats['newThisWeek'])} this week', trendPositive: true),
        StatCard(label: 'Inactive Supervisors', value: '${n(_stats['inactive'])}', icon: Icons.person_off, iconColor: GamyaColors.danger, trend: '${n(_stats['inactive'])} inactive', trendPositive: false),
        StatCard(label: 'Total Trip Requests', value: Fmt.number(_stats['totalRequests']), icon: Icons.list_alt, trend: '+${n(_stats['requestsThisWeek'])} from last week', trendPositive: true),
        StatCard(label: 'Total Bookings', value: Fmt.number(_stats['totalBookings']), icon: Icons.directions_car, trend: '+${n(_stats['bookingsThisWeek'])} from last week', trendPositive: true),
      ]),
      const SizedBox(height: 12),
      MasterDetail(
        master: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilterBar(
            leading: PillTabs(tabs: ['All (${n(_stats['total'])})', 'Active (${n(_stats['active'])})', 'Inactive (${n(_stats['inactive'])})'], selected: _tab, onChanged: (i) { setState(() => _tab = i); _q.set('status', i == 1 ? 'ACTIVE' : i == 2 ? 'INACTIVE' : null); _load(); }),
            children: [
              SearchField(controller: _search, hint: 'Search supervisor…', width: 220, onSubmitted: (v) { _q.set('q', v); _load(); }),
              FilterDropdown<String>(label: 'All Locations', value: _q.filters['location'] as String?, items: [for (final l in _locations) ddItem(l['id'] as String, l['name'] as String)], onChanged: (v) { _q.set('location', v); _load(); }),
              FilterDropdown<String>(label: 'All Status', value: _q.filters['status'] as String?, width: 130, items: [ddItem('ACTIVE', 'Active'), ddItem('INACTIVE', 'Inactive'), ddItem('PENDING', 'Pending')], onChanged: (v) { _q.set('status', v); setState(() => _tab = v == 'ACTIVE' ? 1 : v == 'INACTIVE' ? 2 : 0); _load(); }),
            ],
            onReset: () { _q.reset(); _search.clear(); setState(() => _tab = 0); _load(); },
          ),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GTable<Supervisor>(
              columns: const [GColumn('Name', width: 150), GColumn('Employee ID', width: 90), GColumn('Mobile Number', width: 110), GColumn('Email ID', flex: 2), GColumn('Assigned Locations', flex: 2), GColumn('Total Requests', width: 80, numeric: true), GColumn('Total Bookings', width: 80, numeric: true), GColumn('Status', width: 90), GColumn('Actions', width: 110)],
              rows: _data.items, loading: _loading, error: _error, onRetry: _load, rowId: (s) => s.id, selected: _checked, onSelect: (id, v) => setState(() => v ? _checked.add(id) : _checked.remove(id)), onSelectAll: (v) => setState(() => v ? _checked.addAll(_data.items.map((e) => e.id)) : _checked.clear()),
              selectedRow: _selected, onRowTap: (s) => _open(s.id),
              cells: (s, i) => [PersonCell(name: s.fullName, avatarUrl: s.avatarUrl), CellText(s.code), CellText(s.mobile), CellText(s.email), CellText(s.assignedLocations), CellText('${s.totalRequests}'), CellText('${s.totalBookings}'), StatusChip(s.status, small: true), RowActions(onEdit: () => _edit(s), more: () => [PopupMenuItem(onTap: () => _open(s.id), child: const Text('View details')), PopupMenuItem(onTap: () => _resetPassword(s), child: const Text('Reset password')), PopupMenuItem(onTap: () => _notify(s), child: const Text('Send notification')), PopupMenuItem(onTap: () => _setStatus(s, s.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE'), child: Text(s.status == 'ACTIVE' ? 'Mark inactive' : 'Mark active'))])],
            ),
            const SizedBox(height: 10),
            PaginationBar(paged: _data, noun: 'supervisors', onPage: (p) { _q.page = p; _load(); }, onPageSize: (s) { _q.pageSize = s; _q.page = 1; _load(); }),
          ]))),
          const SizedBox(height: 12),
          SectionCard(title: 'Recent Supervisor Activities', trailing: ViewAllLink(onTap: () => context.go('/reports')), child: GTable<Map<String, dynamic>>(minWidth: 600, columns: const [GColumn('Date & Time', width: 150), GColumn('Supervisor Name', width: 140), GColumn('Activity', width: 170), GColumn('Details', flex: 3)], rows: _activities, cells: (a, i) => [CellText(Fmt.dateTimeShort(a['createdAt'])), CellText(a['actorName'] as String?, bold: true), Row(children: [const Icon(Icons.bolt, size: 14, color: GamyaColors.gold), const SizedBox(width: 4), Flexible(child: CellText(Fmt.title(a['action'] as String?)))]), CellText(a['details'] as String?)])),
        ]),
        detail: _selected == null && !_detailLoading ? _quickActions() : Column(children: [
          if (_detailLoading) const Card(child: LoadingState(height: 200)) else _detail(_selected!),
          const SizedBox(height: 12), _quickActions(),
        ]),
      ),
    ]);
  }

  Widget _quickActions() => SectionCard(title: 'Quick Actions', child: LayoutBuilder(builder: (ctx, c) {
    final w = (c.maxWidth - 16) / 3;
    Widget qa(IconData i, String l, VoidCallback f) => SizedBox(width: w, child: InkWell(borderRadius: BorderRadius.circular(10), onTap: f, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(border: Border.all(color: GamyaColors.border), borderRadius: BorderRadius.circular(10)), child: Column(children: [Icon(i, color: GamyaColors.gold, size: 24), const SizedBox(height: 6), Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5))]))));
    return Wrap(spacing: 8, runSpacing: 8, children: [qa(Icons.person_add_alt, 'Add Supervisor', () => _edit()), qa(Icons.location_on_outlined, 'Assign Locations', () => _selected == null ? toast(context, 'Select a supervisor first') : _edit(_selected)), qa(Icons.bar_chart, 'View Reports', () => context.go('/reports')), qa(Icons.security, 'Manage Access', () => _selected == null ? toast(context, 'Select a supervisor first') : _setStatus(_selected!, _selected!.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE')), qa(Icons.notifications_active_outlined, 'Send Notification', () => _notify(_selected)), qa(Icons.download_outlined, 'Export Data', _export)]);
  }));

  Widget _detail(Supervisor s) => DetailPanel(
    title: 'Supervisor Details', onClose: () => setState(() => _selected = null),
    header: Row(children: [GamyaAvatar(url: s.avatarUrl, name: s.fullName, size: 56), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), Text(s.code, style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary)), const SizedBox(height: 4), StatusChip(s.status, small: true)]))]),
    tabs: const ['Overview', 'Access & Locations', 'Activity'],
    tabViews: [
      Column(children: [
        KeyValueRow('Full Name', s.fullName, icon: Icons.person_outline), KeyValueRow('Employee ID', s.employeeId ?? s.code, icon: Icons.badge_outlined), KeyValueRow('Mobile Number', s.mobile, icon: Icons.phone_android_outlined), KeyValueRow('Email ID', s.email, icon: Icons.mail_outline), KeyValueRow('Company', s.companyName, icon: Icons.business_outlined), KeyValueRow('Assigned Locations', s.assignedLocations, icon: Icons.location_on_outlined), KeyValueRow('Role', s.designation ?? 'Supervisor', icon: Icons.work_outline), KeyValueRow('Date of Joining', Fmt.date(s.dateOfJoining), icon: Icons.calendar_today_outlined), KeyValueRow('Last Login', Fmt.dateTime(s.lastLoginAt), icon: Icons.history),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _counter('${s.totalRequests}', 'Trip Requests')), const SizedBox(width: 8), Expanded(child: _counter('${s.totalBookings}', 'Total Bookings'))]),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Assigned Locations', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [if (s.locations.isEmpty) const Chip(label: Text('All Locations')), for (final l in s.locations) Chip(label: Text(l['name'] as String), avatar: const Icon(Icons.location_on, size: 14, color: GamyaColors.gold))]),
        const SizedBox(height: 12),
        KeyValueRow('Access', s.status == 'ACTIVE' ? 'Can post requirements & bookings' : 'Access disabled'), KeyValueRow('Face Verified', s.faceVerified ? 'Yes' : 'No'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [OutlineButton(label: 'Assign Locations', icon: Icons.location_on_outlined, dense: true, onPressed: () => _edit(s)), OutlineButton(label: s.status == 'ACTIVE' ? 'Disable Access' : 'Enable Access', icon: Icons.lock_outline, dense: true, color: s.status == 'ACTIVE' ? GamyaColors.danger : GamyaColors.success, onPressed: () => _setStatus(s, s.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE'))]),
      ]),
      ActivityList(items: s.activities, compact: true),
    ],
    footer: Row(children: [Expanded(child: OutlineButton(label: 'Edit Details', onPressed: () => _edit(s))), const SizedBox(width: 8), Expanded(child: GoldButton(label: 'Reset Password', onPressed: () => _resetPassword(s)))]),
    child: const SizedBox.shrink(),
  );

  Widget _counter(String v, String l) => Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: GamyaColors.surface, borderRadius: BorderRadius.circular(10)), child: Column(children: [Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), Text(l, style: const TextStyle(fontSize: 11.5, color: GamyaColors.textSecondary))]));
}
