import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/data_table.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/list_helpers.dart';
import '../../widgets/page_scaffold.dart';

class ApprovalsPage extends ConsumerStatefulWidget {
  const ApprovalsPage({super.key, this.selectId, this.category});
  final String? selectId; final String? category;
  @override
  ConsumerState<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends ConsumerState<ApprovalsPage> {
  final _q = ListQuery(); final _search = TextEditingController(); final _remarks = TextEditingController();
  Paged<Approval> _data = Paged.empty(); bool _loading = true; String? _error;
  Map<String, dynamic> _stats = {}; List<Map<String, dynamic>> _trend = []; List<Approval> _oldest = [];
  Approval? _selected; bool _detailLoading = false; final Set<String> _checked = {}; int _tab = 0; bool _busy = false;
  static const _cats = ['all', 'drivers', 'vehicles', 'documents', 'supervisors'];
  ApiClient get api => ref.read(apiProvider);

  @override
  void initState() {
    super.initState();
    _q.set('status', 'PENDING');
    if (widget.category != null) { _tab = _cats.indexOf(widget.category!).clamp(0, 4); if (_tab > 0) _q.set('category', _cats[_tab]); }
    _load(); _loadSide(); if (widget.selectId != null) _open(widget.selectId!);
  }
  @override
  void didUpdateWidget(covariant ApprovalsPage old) { super.didUpdateWidget(old); if (widget.selectId != null && widget.selectId != old.selectId) _open(widget.selectId!); }

  Future<void> _loadSide() async { try { final r = await Future.wait([api.get('/approvals/stats'), api.get('/approvals/trend'), api.get('/approvals/oldest')]); if (mounted) setState(() { _stats = api.data(r[0]); _trend = api.list(r[1]); _oldest = api.list(r[2]).map(Approval.new).toList(); }); ref.read(badgesProvider.notifier).state = Badges(pendingApprovals: (_stats['total'] as num?)?.toInt() ?? 0, unread: ref.read(badgesProvider).unread); } catch (_) {} }
  Future<void> _load() async { setState(() { _loading = true; _error = null; }); try { final d = await api.paged('/approvals', Approval.new, query: _q.toQuery()); if (mounted) setState(() { _data = d; _loading = false; }); } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); } }
  Future<void> _open(String id) async { setState(() => _detailLoading = true); try { final r = await api.get('/approvals/$id'); if (mounted) setState(() { _selected = Approval(api.data(r)); _remarks.clear(); }); } catch (e) { if (mounted) toast(context, e.msg, error: true); } if (mounted) setState(() => _detailLoading = false); }

  Future<void> _decide(Approval a, bool approve, {String? remarks}) async {
    final r = remarks ?? _remarks.text.trim();
    if (!approve && r.isEmpty) { final rr = await reasonDialog(context, title: 'Reject request', label: 'Reason for rejection', confirmLabel: 'Reject', danger: true, required: true); if (rr == null) return; return _decide(a, false, remarks: rr); }
    if (approve && !await confirmDialog(context, title: 'Approve ${a.typeLabel}', message: 'Approve ${a.subjectName ?? a.vehicleNumber ?? 'this request'}?', confirmLabel: 'Approve')) return;
    setState(() => _busy = true);
    try { await api.post('/approvals/${a.id}/${approve ? 'approve' : 'reject'}', body: {'remarks': r}); if (mounted) toast(context, approve ? 'Approved' : 'Rejected'); if (_selected?.id == a.id) _selected = null; await _load(); await _loadSide(); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }
  Future<void> _bulk(bool approve) async {
    if (_checked.isEmpty) return;
    if (!await confirmDialog(context, title: '${approve ? 'Approve' : 'Reject'} ${_checked.length} requests', message: 'This will ${approve ? 'approve' : 'reject'} all selected requests.', confirmLabel: approve ? 'Approve all' : 'Reject all', danger: !approve)) return;
    try { await api.post('/approvals/bulk', body: {'ids': _checked.toList(), 'decision': approve ? 'APPROVED' : 'REJECTED'}); _checked.clear(); await _load(); await _loadSide(); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }

  @override
  Widget build(BuildContext context) {
    num n(dynamic v) => (v as num?) ?? 0;
    final byType = ((_stats['byType'] as List?) ?? []).cast<Map<String, dynamic>>();
    const typeColors = {'DRIVER_REGISTRATION': GamyaColors.success, 'VEHICLE_REGISTRATION': GamyaColors.info, 'DOCUMENT_UPLOAD': GamyaColors.warning, 'DOCUMENT_RENEWAL': GamyaColors.gold, 'SUPERVISOR_REGISTRATION': GamyaColors.purple};
    return PageBody(children: [
      PageHeader(title: 'Pending Approvals', breadcrumb: 'Pending Approvals', subtitle: 'Review and approve driver registrations, vehicle documents, and other requests.', actions: [if (_checked.isNotEmpty) ...[OutlineButton(label: 'Reject Selected (${_checked.length})', icon: Icons.close, color: GamyaColors.danger, onPressed: () => _bulk(false)), GoldButton(label: 'Approve Selected (${_checked.length})', icon: Icons.check, onPressed: () => _bulk(true))]]),
      const SizedBox(height: 14),
      StatGrid(minWidth: 230, cards: [
        StatCard(label: 'Driver Approvals', value: '${n(_stats['drivers'])}', icon: Icons.person, trend: 'Pending Review', onTap: () => _setTab(1)),
        StatCard(label: 'Vehicle Approvals', value: '${n(_stats['vehicles'])}', icon: Icons.directions_car, trend: 'Pending Review', onTap: () => _setTab(2)),
        StatCard(label: 'Document Renewals', value: '${n(_stats['documents'])}', icon: Icons.description, trend: 'Pending Review', onTap: () => _setTab(3)),
        StatCard(label: 'Supervisor Approvals', value: '${n(_stats['supervisors'])}', icon: Icons.supervisor_account, trend: 'Pending Review', onTap: () => _setTab(4)),
      ]),
      const SizedBox(height: 12),
      MasterDetail(
        master: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilterBar(
            leading: PillTabs(tabs: ['All Requests (${n(_stats['total'])})', 'Drivers (${n(_stats['drivers'])})', 'Vehicles (${n(_stats['vehicles'])})', 'Documents (${n(_stats['documents'])})', 'Supervisors (${n(_stats['supervisors'])})'], selected: _tab, onChanged: _setTab),
            children: [
              FilterDropdown<String>(label: 'All Status', value: _q.filters['status'] as String?, width: 130, items: [ddItem('PENDING', 'Pending'), ddItem('APPROVED', 'Approved'), ddItem('REJECTED', 'Rejected')], onChanged: (v) { _q.set('status', v); _load(); }),
              FilterDropdown<String>(label: 'Oldest First', value: _q.filters['sort'] as String?, width: 130, items: [ddItem('newest', 'Newest First')], onChanged: (v) { _q.set('sort', v); _load(); }),
              SearchField(controller: _search, hint: 'Search requests…', width: 200, onSubmitted: (v) { _q.set('q', v); _load(); }),
            ],
          ),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GTable<Approval>(
              columns: const [GColumn('Request Type', width: 140), GColumn('Name / Vehicle No.', width: 170), GColumn('Details', flex: 2), GColumn('Submitted On', width: 110), GColumn('Status', width: 90), GColumn('Actions', width: 230)],
              rows: _data.items, loading: _loading, error: _error, onRetry: _load, rowId: (a) => a.id, selected: _checked, onSelect: (id, s) => setState(() => s ? _checked.add(id) : _checked.remove(id)), onSelectAll: (s) => setState(() => s ? _checked.addAll(_data.items.where((a) => a.status == 'PENDING').map((e) => e.id)) : _checked.clear()), selectedRow: _selected, onRowTap: (a) => _open(a.id), emptyText: 'No requests found',
              cells: (a, i) => [CellText(a.typeLabel), Row(children: [GamyaAvatar(url: a.subjectPhoto, name: a.subjectName ?? a.vehicleNumber, size: 30, square: a.isVehicle), const SizedBox(width: 8), Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.isVehicle ? (a.vehicleNumber ?? '') : (a.subjectName ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)), Text(a.isVehicle ? (a.vehicleLabel ?? '') : (a.subjectMobile ?? ''), style: const TextStyle(fontSize: 11, color: GamyaColors.textSecondary))]))]), CellText(a.details), CellText(Fmt.dateTimeShort(a.submittedAt), maxLines: 2), StatusChip(a.status, small: true), Row(children: [OutlineButton(label: 'View', icon: Icons.visibility_outlined, dense: true, onPressed: () => _open(a.id)), if (a.status == 'PENDING') ...[const SizedBox(width: 4), OutlineButton(label: 'Approve', icon: Icons.check, dense: true, color: GamyaColors.success, onPressed: () => _decide(a, true)), const SizedBox(width: 4), OutlineButton(label: 'Reject', icon: Icons.close, dense: true, color: GamyaColors.danger, onPressed: () => _decide(a, false))]])],
            ),
            const SizedBox(height: 10),
            PaginationBar(paged: _data, noun: 'requests', onPage: (p) { _q.page = p; _load(); }, onPageSize: (s) { _q.pageSize = s; _q.page = 1; _load(); }),
          ]))),
          const SizedBox(height: 12),
          CardRow(minWidth: 280, children: [
            SectionCard(title: 'Approval Trend (Last 30 Days)', child: StackedBarChart(height: 150, colors: const [GamyaColors.success, GamyaColors.danger], legend: const ['Approved', 'Rejected'], barWidthFactor: 0.6, groups: [for (var i = 0; i < _trend.length; i += 5) BarGroup(label: Fmt.dateShort(_trend[i]['date']), values: [_trend.skip(i).take(5).fold<num>(0, (s, x) => s + n(x['approved'])), _trend.skip(i).take(5).fold<num>(0, (s, x) => s + n(x['rejected']))])])),
            SectionCard(title: 'Pending by Type', child: Center(child: DonutChart(size: 110, slices: [for (final t in byType) ChartSlice(label: t['label'] as String, value: n(t['count']), color: typeColors[t['type']] ?? GamyaColors.neutral)]))),
            SectionCard(title: 'Oldest Pending Requests', trailing: ViewAllLink(onTap: () { _q.set('sort', null); _load(); }), child: Column(children: [for (var i = 0; i < _oldest.length; i++) InkWell(onTap: () => _open(_oldest[i].id), child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [SizedBox(width: 18, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: GamyaColors.textMuted))), Expanded(child: Text(_oldest[i].isVehicle ? (_oldest[i].vehicleNumber ?? '') : (_oldest[i].subjectName ?? ''), style: const TextStyle(fontSize: 12.5))), Text('${_oldest[i].ageDays} days', style: const TextStyle(fontSize: 12, color: GamyaColors.danger, fontWeight: FontWeight.w600)), const SizedBox(width: 10), SizedBox(width: 120, child: Text(_oldest[i].typeLabel, style: const TextStyle(fontSize: 11.5, color: GamyaColors.textSecondary)))]))), if (_oldest.isEmpty) const EmptyState(title: 'All caught up!', icon: Icons.task_alt)])),
          ]),
        ]),
        detail: _selected == null && !_detailLoading ? null : _detailLoading ? const Card(child: LoadingState(height: 240)) : _detail(_selected!),
      ),
    ]);
  }

  void _setTab(int i) { setState(() => _tab = i); _q.set('category', i == 0 ? null : _cats[i]); _load(); }

  Widget _detail(Approval a) {
    final d = a.driver; final s = a.supervisor; final v = a.vehicle ?? d?['vehicle'] as Map<String, dynamic>?;
    final docs = ((d?['documents'] ?? a.vehicle?['documents']) as List?)?.cast<Map<String, dynamic>>() ?? [];
    final selfie = (d?['selfieUrl'] ?? s?['selfieUrl']) as String?; final idPhoto = (d?['idPhotoUrl'] as String?) ?? selfie; final faceVerified = (d?['faceVerified'] ?? s?['faceVerified']) == true; final score = (d?['faceMatchScore'] ?? s?['faceMatchScore']) as num?;
    final person = d ?? s;
    return DetailPanel(
      title: 'Request Details', onClose: () => setState(() => _selected = null),
      header: Row(children: [GamyaAvatar(url: a.subjectPhoto, name: a.subjectName ?? a.vehicleNumber, size: 60, square: a.isVehicle), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.isVehicle ? (a.vehicleNumber ?? '') : (a.subjectName ?? ''), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 4), StatusChip(a.status, small: true), const SizedBox(height: 4), Text(a.typeLabel, style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))]))]),
      tabs: ['Basic Details', 'Documents (${docs.length})', 'Vehicle Details', 'Activity'],
      tabViews: [
        Column(children: [
          if (person != null) ...[KeyValueRow('Full Name', person['fullName'] as String?), KeyValueRow('Mobile Number', person['mobile'] as String?), KeyValueRow('Email ID', person['email'] as String?), if (d != null) KeyValueRow('Date of Birth', Fmt.date(d['dateOfBirth'])), if (d != null) KeyValueRow('Address', d['address'] as String?), if (s != null) KeyValueRow('Company', s['companyName'] as String?), if (s != null) KeyValueRow('Employee ID', s['employeeId'] as String?), KeyValueRow('Registration Date', Fmt.dateTime(person['registeredAt']))],
          if (a.document != null) ...[KeyValueRow('Document', Fmt.title(a.document!['type'] as String?)), KeyValueRow('Valid Till', Fmt.date(a.document!['validTill'])), Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => showImageDialog(context, a.document!['fileUrl'] as String?, title: Fmt.title(a.document!['type'] as String?)), icon: const Icon(Icons.visibility_outlined, size: 16), label: const Text('View document')))],
          KeyValueRow('Submitted On', Fmt.dateTime(a.submittedAt)), if (a.reviewedAt != null) KeyValueRow('Reviewed', '${Fmt.dateTime(a.reviewedAt)} by ${a.raw['reviewedBy'] ?? ''}'), if (a.remarks != null) KeyValueRow('Remarks', a.remarks),
          if (selfie != null) ...[
            const SizedBox(height: 12),
            PanelSection(title: 'Selfie / Facial Verification', trailing: StatusChip(faceVerified ? 'VERIFIED' : 'PENDING', label: faceVerified ? 'Face Matched${score != null ? ' ${(score * 100).round()}%' : ''}' : 'Not Verified', small: true), child: Row(children: [Expanded(child: Column(children: [InkWell(onTap: () => showImageDialog(context, selfie, title: 'Live Selfie'), child: NetImage(selfie, height: 120)), const SizedBox(height: 4), const Text('Live Selfie', style: TextStyle(fontSize: 11, color: GamyaColors.textSecondary))])), const SizedBox(width: 10), Expanded(child: Column(children: [InkWell(onTap: () => showImageDialog(context, idPhoto, title: 'Aadhaar Photo'), child: NetImage(idPhoto, height: 120)), const SizedBox(height: 4), const Text('Aadhaar Photo', style: TextStyle(fontSize: 11, color: GamyaColors.textSecondary))]))])),
          ],
        ]),
        docs.isEmpty ? const EmptyState(title: 'No documents attached') : Column(children: [for (final x in docs) DocumentRow(label: '${Fmt.title(x['type'] as String?)}${x['validTill'] != null ? ' · till ${Fmt.date(x['validTill'])}' : ''}', status: x['status'] as String, onView: () => showImageDialog(context, x['fileUrl'] as String?, title: Fmt.title(x['type'] as String?)))]),
        v == null ? const EmptyState(title: 'No vehicle attached', icon: Icons.directions_car_outlined) : Column(children: [KeyValueRow('Vehicle Number', v['number'] as String?), KeyValueRow('Make & Model', '${v['make']} ${v['model']}'), KeyValueRow('Model Year', '${v['year']}'), KeyValueRow('Vehicle Type', Fmt.vehicleType(v['type'] as String?)), const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: [for (final p in ((v['photos'] as List?) ?? []).cast<String>()) InkWell(onTap: () => showImageDialog(context, p, title: v['number'] as String?), child: NetImage(p, width: 110, height: 70))]), if (a.vehicle?['id'] != null || d?['vehicle']?['id'] != null) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => context.go('/vehicles?id=${v['id']}'), icon: const Icon(Icons.open_in_new, size: 14), label: const Text('Open vehicle')))]),
        ActivityList(items: a.activities, compact: true),
      ],
      footer: a.status != 'PENDING' ? null : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Admin Remarks (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(height: 6),
        TextField(controller: _remarks, maxLines: 2, decoration: const InputDecoration(hintText: 'Add remarks…')), const SizedBox(height: 10),
        Row(children: [Expanded(child: OutlineButton(label: 'Reject', icon: Icons.close, color: GamyaColors.danger, loading: _busy, onPressed: () => _decide(a, false))), const SizedBox(width: 8), Expanded(child: GoldButton(label: 'Approve', icon: Icons.check, loading: _busy, onPressed: () => _decide(a, true)))]),
      ]),
      child: const SizedBox.shrink(),
    );
  }
}
