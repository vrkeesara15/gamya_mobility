import 'package:file_picker/file_picker.dart';
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
import 'vehicle_form.dart';

class VehiclesPage extends ConsumerStatefulWidget {
  const VehiclesPage({super.key, this.selectId});
  final String? selectId;
  @override
  ConsumerState<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends ConsumerState<VehiclesPage> {
  final _q = ListQuery(); final _search = TextEditingController();
  Paged<Vehicle> _data = Paged.empty(); bool _loading = true; String? _error;
  Map<String, dynamic> _stats = {}; Map<String, dynamic> _analytics = {}; List<PlatformInfo> _platforms = [];
  Vehicle? _selected; bool _detailLoading = false; final Set<String> _checked = {};
  ApiClient get api => ref.read(apiProvider);

  @override
  void initState() { super.initState(); _load(); _loadSide(); if (widget.selectId != null) _open(widget.selectId!); }
  @override
  void didUpdateWidget(covariant VehiclesPage old) { super.didUpdateWidget(old); if (widget.selectId != null && widget.selectId != old.selectId) _open(widget.selectId!); }

  Future<void> _loadSide() async { try { final r = await Future.wait([api.get('/vehicles/stats'), api.get('/vehicles/analytics'), api.get('/platforms')]); if (mounted) setState(() { _stats = api.data(r[0]); _analytics = api.data(r[1]); _platforms = api.list(r[2]).map(PlatformInfo.new).toList(); }); } catch (_) {} }
  Future<void> _load() async { setState(() { _loading = true; _error = null; }); try { final d = await api.paged('/vehicles', Vehicle.new, query: _q.toQuery()); if (mounted) setState(() { _data = d; _loading = false; }); } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); } }
  Future<void> _open(String id) async { setState(() => _detailLoading = true); try { final r = await api.get('/vehicles/$id'); if (mounted) setState(() => _selected = Vehicle(api.data(r))); } catch (e) { if (mounted) toast(context, e.msg, error: true); } if (mounted) setState(() => _detailLoading = false); }
  Future<void> _after(Future<void> Function() f, [String? ok]) async { try { await f(); if (ok != null && mounted) toast(context, ok); await _load(); await _loadSide(); if (_selected != null) await _open(_selected!.id); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  Future<void> _edit([Vehicle? v]) async { final saved = await showDialog<bool>(context: context, builder: (_) => VehicleFormDialog(existing: v, platforms: _platforms)); if (saved == true) { await _load(); await _loadSide(); if (v != null) _open(v.id); } }
  Future<void> _status(Vehicle v, String status) async {
    String? reason;
    if (status == 'BLACKLISTED') { reason = await reasonDialog(context, title: 'Blacklist ${v.number}', label: 'Reason', confirmLabel: 'Blacklist', danger: true, required: true); if (reason == null) return; }
    else if (!await confirmDialog(context, title: 'Change status', message: 'Set ${v.number} to ${Fmt.title(status)}?', danger: status != 'ACTIVE')) { return; }
    await _after(() => api.patch('/vehicles/${v.id}/status', body: {'status': status, if (reason != null) 'reason': reason}), 'Vehicle updated');
  }
  Future<void> _addPhotos(Vehicle v) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (r == null || r.files.isEmpty) return;
    await _after(() => api.upload('/vehicles/${v.id}/photos', files: {'photos': [for (final f in r.files) if (f.bytes != null) UploadFile(name: f.name, bytes: f.bytes!)]}), 'Photos uploaded');
  }
  Future<void> _uploadDoc(Vehicle v, String type) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'], withData: true);
    if (r == null || r.files.isEmpty || r.files.first.bytes == null) return;
    await _after(() => api.upload('/vehicles/${v.id}/documents', files: {'file': [UploadFile(name: r.files.first.name, bytes: r.files.first.bytes!)]}, fields: {'type': type}), 'Document uploaded');
  }
  Future<void> _docStatus(Vehicle v, Map<String, dynamic> doc, String status) async {
    final remarks = status == 'REJECTED' ? await reasonDialog(context, title: 'Reject document', label: 'Remarks', confirmLabel: 'Reject', danger: true) : null;
    if (status == 'REJECTED' && remarks == null) return;
    await _after(() => api.patch('/vehicles/${v.id}/documents/${doc['id']}', body: {'status': status, if (remarks != null) 'remarks': remarks}), 'Document ${status.toLowerCase()}');
  }
  Future<void> _bulkUpload() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (r == null || r.files.isEmpty || r.files.first.bytes == null) return;
    try {
      final res = await api.upload('/vehicles/bulk', files: {'file': [UploadFile(name: r.files.first.name, bytes: r.files.first.bytes!)]});
      final d = api.data(res);
      if (mounted) { toast(context, 'Imported ${d['imported']} vehicles, ${d['failed']} failed'); await _load(); await _loadSide(); }
    } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }
  Future<void> _export() async { try { await downloadTextFile('vehicles.csv', await api.getText('/reports/export', query: {'type': 'vehicles'})); if (mounted) toast(context, 'Export downloaded'); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  @override
  Widget build(BuildContext context) {
    num n(dynamic v) => (v as num?) ?? 0;
    final byType = ((_analytics['byType'] as Map?) ?? {}).cast<String, dynamic>(); final byYear = ((_analytics['byYear'] as Map?) ?? {}).cast<String, dynamic>(); final byComp = ((_analytics['byCompliance'] as Map?) ?? {}).cast<String, dynamic>();
    const typeColors = {'SEDAN': GamyaColors.success, 'SUV': GamyaColors.info, 'TEMPO_TRAVELLER': GamyaColors.warning, 'TEMPO': GamyaColors.purple, 'INNOVA': GamyaColors.gold, 'OTHER': GamyaColors.neutral};
    return PageBody(children: [
      PageHeader(title: 'Vehicle Management', breadcrumb: 'Vehicle Management', subtitle: 'Manage vehicle details, documents, compliance, and track their utilization.', actions: [OutlineButton(label: 'Export', icon: Icons.download_outlined, onPressed: _export), OutlineButton(label: 'Bulk Upload', icon: Icons.upload_file_outlined, onPressed: _bulkUpload), GoldButton(label: 'Add Vehicle', icon: Icons.add, onPressed: () => _edit())]),
      const SizedBox(height: 14),
      StatGrid(cards: [
        StatCard(label: 'Total Vehicles', value: '${n(_stats['total'])}', icon: Icons.directions_car, trend: '+${n(_stats['newThisMonth'])} this month', trendPositive: true),
        StatCard(label: 'Active Vehicles', value: '${n(_stats['active'])}', icon: Icons.local_taxi, iconColor: GamyaColors.success, trend: '+${n(_stats['activeThisMonth'])} this month', trendPositive: true),
        StatCard(label: 'Inactive Vehicles', value: '${n(_stats['inactive'])}', icon: Icons.no_transfer, iconColor: GamyaColors.danger, trend: '${n(_stats['inactive'])} inactive', trendPositive: false),
        StatCard(label: 'Non-Compliant', value: '${n(_stats['nonCompliant'])}', icon: Icons.warning_amber_rounded, iconColor: GamyaColors.danger, trend: '${n(_stats['dueForRenewal'])} due for renewal', trendColor: GamyaColors.danger, trendIcon: Icons.error_outline, onTap: () { _q.set('compliance', 'NON_COMPLIANT'); _load(); }),
        StatCard(label: 'Under Verification', value: '${n(_stats['underVerification'])}', icon: Icons.schedule, iconColor: GamyaColors.warning, trend: 'Awaiting approval', trendColor: GamyaColors.warning, onTap: () => context.go('/approvals?tab=vehicles')),
        StatCard(label: 'Blacklisted', value: '${n(_stats['blacklisted'])}', icon: Icons.block, iconColor: GamyaColors.danger, trend: 'View List', trendColor: GamyaColors.info, trendIcon: Icons.list, onTap: () { _q.set('status', 'BLACKLISTED'); _load(); }),
      ]),
      const SizedBox(height: 12),
      MasterDetail(
        master: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilterBar(children: [
            SearchField(controller: _search, hint: 'Search vehicle no, make, model or driver…', width: 260, onSubmitted: (v) { _q.set('q', v); _load(); }),
            FilterDropdown<String>(label: 'All Status', value: _q.filters['status'] as String?, width: 130, items: [ddItem('ACTIVE', 'Active'), ddItem('INACTIVE', 'Inactive'), ddItem('UNDER_REVIEW', 'Under Review'), ddItem('BLACKLISTED', 'Blacklisted')], onChanged: (v) { _q.set('status', v); _load(); }),
            FilterDropdown<String>(label: 'All Vehicle Type', value: _q.filters['type'] as String?, items: [for (final t in vehicleTypeItems) ddItem(t.$1, t.$2)], onChanged: (v) { _q.set('type', v); _load(); }),
            FilterDropdown<String>(label: 'All Compliance', value: _q.filters['compliance'] as String?, items: [ddItem('FULLY_COMPLIANT', 'Fully Compliant'), ddItem('DUE_FOR_RENEWAL', 'Due for Renewal'), ddItem('UNDER_VERIFICATION', 'Under Verification'), ddItem('NON_COMPLIANT', 'Non-Compliant')], onChanged: (v) { _q.set('compliance', v); _load(); }),
            FilterDropdown<String>(label: 'All Platforms', value: _q.filters['platform'] as String?, items: [for (final p in _platforms) ddItem(p.id, p.name)], onChanged: (v) { _q.set('platform', v); _load(); }),
          ], onReset: () { _q.reset(); _search.clear(); _load(); }, onApply: () { _q.set('q', _search.text); _load(); }),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GTable<Vehicle>(
              columns: const [GColumn('Vehicle Number', width: 110), GColumn('Vehicle Photo', width: 76), GColumn('Make & Model', width: 130), GColumn('Year', width: 50), GColumn('Type', width: 90), GColumn('Assigned Driver', width: 150), GColumn('Platform', width: 120), GColumn('Compliance', width: 80), GColumn('Status', width: 100), GColumn('Actions', width: 110)],
              rows: _data.items, loading: _loading, error: _error, onRetry: _load, rowId: (v) => v.id, selected: _checked, onSelect: (id, s) => setState(() => s ? _checked.add(id) : _checked.remove(id)), onSelectAll: (s) => setState(() => s ? _checked.addAll(_data.items.map((e) => e.id)) : _checked.clear()), selectedRow: _selected, onRowTap: (v) => _open(v.id),
              cells: (v, i) => [CellText(v.number, bold: true), NetImage(v.photoUrl, width: 60, height: 38, placeholderIcon: Icons.directions_car), CellText(v.makeModel, maxLines: 2), CellText('${v.year}'), CellText(Fmt.vehicleType(v.type)), v.driver == null ? const CellText('Unassigned', muted: true) : PersonCell(name: v.driver!['fullName'] as String, avatarUrl: v.driver!['avatarUrl'] as String?, subtitle: v.driver!['mobile'] as String?), v.platform == null ? const PlatformChip(name: 'Other', code: 'OTHER', compact: true) : PlatformChip(name: v.platform!.name, color: v.platform!.color, compact: true), FractionChip(done: v.complianceVerified, total: 7), StatusChip(v.status, small: true), RowActions(onView: () => _open(v.id), onEdit: () => _edit(v), more: () => [if (v.status != 'ACTIVE') PopupMenuItem(onTap: () => _status(v, 'ACTIVE'), child: const Text('Mark active')), if (v.status == 'ACTIVE') PopupMenuItem(onTap: () => _status(v, 'INACTIVE'), child: const Text('Mark inactive')), PopupMenuItem(onTap: () => _addPhotos(v), child: const Text('Add photos')), if (v.status != 'BLACKLISTED') PopupMenuItem(onTap: () => _status(v, 'BLACKLISTED'), child: const Text('Blacklist', style: TextStyle(color: GamyaColors.danger)))])],
            ),
            const SizedBox(height: 10),
            PaginationBar(paged: _data, noun: 'vehicles', onPage: (p) { _q.page = p; _load(); }, onPageSize: (s) { _q.pageSize = s; _q.page = 1; _load(); }),
          ]))),
          const SizedBox(height: 12),
          CardRow(minWidth: 280, children: [
            SectionCard(title: 'Vehicle Type Distribution', child: Center(child: DonutChart(size: 110, slices: [for (final e in byType.entries) ChartSlice(label: Fmt.vehicleType(e.key), value: n(e.value), color: typeColors[e.key] ?? GamyaColors.neutral)]))),
            SectionCard(title: 'Compliance Status', child: Center(child: DonutChart(size: 110, slices: [ChartSlice(label: 'Fully Compliant', value: n(byComp['FULLY_COMPLIANT']), color: GamyaColors.success), ChartSlice(label: 'Due for Renewal', value: n(byComp['DUE_FOR_RENEWAL']), color: GamyaColors.warning), ChartSlice(label: 'Under Verification', value: n(byComp['UNDER_VERIFICATION']), color: GamyaColors.info), ChartSlice(label: 'Non-Compliant', value: n(byComp['NON_COMPLIANT']), color: GamyaColors.danger)]))),
            SectionCard(title: 'Vehicle Age (Year Wise)', child: StackedBarChart(height: 150, showValues: true, colors: const [GamyaColors.gold], groups: [for (final k in (byYear.keys.toList()..sort())) BarGroup(label: k, values: [n(byYear[k])])])),
          ]),
        ]),
        detail: _selected == null && !_detailLoading ? null : _detailLoading ? const Card(child: LoadingState(height: 240)) : _detail(_selected!),
      ),
    ]);
  }

  Widget _detail(Vehicle v) {
    Map<String, dynamic>? doc(String t) { final l = v.documents.where((x) => x['type'] == t).toList(); return l.isEmpty ? null : l.first; }
    const docLabels = {'RC': 'RC (Registration Certificate)', 'PERMIT': 'Permit', 'INSURANCE': 'Insurance', 'PUC': 'PUC Certificate', 'FITNESS': 'Fitness Certificate', 'VEHICLE_PHOTO_1': 'Vehicle Photo 1', 'VEHICLE_PHOTO_2': 'Vehicle Photo 2'};
    return DetailPanel(
      title: 'Vehicle Details', onClose: () => setState(() => _selected = null),
      header: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [InkWell(onTap: () => showImageDialog(context, v.photoUrl, title: v.number), child: NetImage(v.photoUrl, width: 130, height: 90, placeholderIcon: Icons.directions_car)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [StatusChip(v.status, small: true), const SizedBox(height: 4), Text(v.number, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), Text(v.makeModel, style: const TextStyle(fontSize: 13, color: GamyaColors.textSecondary)), const SizedBox(height: 4), Text('${Fmt.vehicleType(v.type)}  |  ${v.year}  |  ${v.color ?? '—'}', style: const TextStyle(fontSize: 12)), const SizedBox(height: 4), if (v.platform != null) PlatformChip(name: v.platform!.name, color: v.platform!.color, compact: true)]))]),
      tabs: const ['Overview', 'Documents', 'Trips', 'Compliance', 'History'],
      tabViews: [
        Column(children: [
          KeyValueRow('Assigned Driver', v.driver == null ? 'Unassigned' : '${v.driver!['fullName']} (${v.driver!['mobile'] ?? ''})'), KeyValueRow('Supervisor', v.supervisor?['fullName'] as String?), KeyValueRow('Registration Date', Fmt.date(v.registrationDate)), KeyValueRow('Fuel Type', Fmt.title(v.fuelType)), KeyValueRow('Seating Capacity', v.seatingCapacity), KeyValueRow('Permit Valid Till', Fmt.date(v.permitValidTill)), KeyValueRow('Insurance Valid Till', Fmt.date(v.insuranceValidTill)), KeyValueRow('PUC Valid Till', Fmt.date(v.pucValidTill)), KeyValueRow('Fitness Valid Till', Fmt.date(v.fitnessValidTill)), KeyValueRow('Current Location', v.currentLocation),
          const SizedBox(height: 10),
          PanelSection(title: 'Vehicle Photos', trailing: TextButton.icon(onPressed: () => _addPhotos(v), icon: const Icon(Icons.add_a_photo_outlined, size: 14), label: const Text('Add Photo', style: TextStyle(fontSize: 12))), child: Wrap(spacing: 6, runSpacing: 6, children: [for (final p in v.photos) InkWell(onTap: () => showImageDialog(context, p['url'] as String?, title: v.number), child: NetImage(p['url'] as String?, width: 96, height: 62)), if (v.photos.isEmpty) const Text('No photos', style: TextStyle(fontSize: 12, color: GamyaColors.textMuted))])),
          PanelSection(title: 'Documents', trailing: FractionChip(done: v.complianceVerified, total: 7), child: Column(children: [for (final e in docLabels.entries) DocumentRow(label: e.value, status: doc(e.key)?['status'] as String? ?? 'MISSING', onView: doc(e.key) == null ? () => _uploadDoc(v, e.key) : () => showImageDialog(context, doc(e.key)!['fileUrl'] as String?, title: e.value), onVerify: doc(e.key) == null ? null : () => _docStatus(v, doc(e.key)!, 'VERIFIED'), onReject: doc(e.key) == null ? null : () => _docStatus(v, doc(e.key)!, 'REJECTED'))])),
        ]),
        Column(children: [
          for (final x in v.documents) DocumentRow(label: '${Fmt.title(x['type'] as String?)}${x['validTill'] != null ? ' · valid till ${Fmt.date(x['validTill'])}' : ''}', status: x['status'] as String, onView: () => showImageDialog(context, x['fileUrl'] as String?, title: Fmt.title(x['type'] as String?)), onVerify: () => _docStatus(v, x, 'VERIFIED'), onReject: () => _docStatus(v, x, 'REJECTED')),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final e in docLabels.entries) OutlineButton(label: 'Upload ${e.key == 'RC' ? 'RC' : Fmt.title(e.key)}', icon: Icons.upload_outlined, dense: true, onPressed: () => _uploadDoc(v, e.key))]),
        ]),
        v.trips.isEmpty ? const EmptyState(title: 'No trips yet') : Column(children: [for (final t in v.trips.take(15)) ListTile(dense: true, contentPadding: EdgeInsets.zero, onTap: () => context.go('${t['status'] == 'COMPLETED' ? '/completed-trips' : '/live-trips'}?id=${t['id']}'), title: Text('${t['code']}  ·  ${t['fromLocation']} → ${t['toLocation']}', style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${Fmt.dateTimeShort(t['scheduledStart'])} · ${t['driverName'] ?? ''}', style: const TextStyle(fontSize: 11)), trailing: StatusChip(t['status'] as String?, small: true))]),
        Column(children: [
          Row(children: [const Text('Compliance level: ', style: TextStyle(fontSize: 12.5)), StatusChip(v.complianceLevel, small: true)]), const SizedBox(height: 8),
          _expiry('Permit', v.permitValidTill), _expiry('Insurance', v.insuranceValidTill), _expiry('PUC', v.pucValidTill), _expiry('Fitness', v.fitnessValidTill),
          const SizedBox(height: 8), Text('${v.complianceVerified} of 7 required documents verified.', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary)),
        ]),
        ActivityList(items: v.activities, compact: true),
      ],
      footer: Wrap(spacing: 8, runSpacing: 8, children: [OutlineButton(label: 'Edit Vehicle', icon: Icons.edit_outlined, dense: true, onPressed: () => _edit(v)), OutlineButton(label: v.status == 'ACTIVE' ? 'Mark Inactive' : 'Mark Active', dense: true, color: v.status == 'ACTIVE' ? GamyaColors.goldDark : GamyaColors.success, onPressed: () => _status(v, v.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE')), if (v.status != 'BLACKLISTED') OutlineButton(label: 'Blacklist', icon: Icons.block, dense: true, color: GamyaColors.danger, onPressed: () => _status(v, 'BLACKLISTED'))]),
      child: const SizedBox.shrink(),
    );
  }

  Widget _expiry(String label, dynamic date) {
    final d = Fmt.parse(date);
    final days = d?.difference(DateTime.now()).inDays;
    final c = days == null ? GamyaColors.textMuted : days < 0 ? GamyaColors.danger : days < 30 ? GamyaColors.warning : GamyaColors.success;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Icon(Icons.circle, size: 9, color: c), const SizedBox(width: 8), SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12.5))), Expanded(child: Text(d == null ? 'Not set' : days! < 0 ? 'Expired ${-days} days ago (${Fmt.date(d)})' : 'Valid till ${Fmt.date(d)} ($days days)', style: TextStyle(fontSize: 12, color: c)))]));
  }
}
