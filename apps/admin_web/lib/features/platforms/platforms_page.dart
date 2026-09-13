import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/providers.dart';
import '../../widgets/data_table.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/page_scaffold.dart';

class PlatformsPage extends ConsumerStatefulWidget {
  const PlatformsPage({super.key});
  @override
  ConsumerState<PlatformsPage> createState() => _PlatformsPageState();
}

class _PlatformsPageState extends ConsumerState<PlatformsPage> {
  List<PlatformInfo> _items = []; List<Map<String, dynamic>> _usage = []; bool _loading = true; String? _error;
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() { _loading = true; _error = null; }); try { final r = await Future.wait([api.get('/platforms', query: {'all': '1'}), api.get('/platforms/usage')]); if (mounted) setState(() { _items = api.list(r[0]).map(PlatformInfo.new).toList(); _usage = api.list(r[1]); _loading = false; }); } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); } }

  Future<void> _edit([PlatformInfo? p]) async {
    final name = TextEditingController(text: p?.name); final color = TextEditingController(text: p?.color ?? '#16A34A'); final link = TextEditingController(text: p?.deepLinkScheme); final web = TextEditingController(text: p?.websiteUrl); bool active = p?.active ?? true;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => FormDialog(title: p == null ? 'Add Platform' : 'Edit ${p.name}', width: 480, onSave: () => Navigator.pop(ctx, true), child: Column(children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Platform Name *')), const SizedBox(height: 12), FieldRow([TextField(controller: color, decoration: InputDecoration(labelText: 'Colour (hex)', prefixIcon: Padding(padding: const EdgeInsets.all(12), child: Container(width: 14, height: 14, decoration: BoxDecoration(color: GamyaColors.fromHex(color.text), borderRadius: BorderRadius.circular(3)))))), TextField(controller: link, decoration: const InputDecoration(labelText: 'Deep link scheme (e.g. routematic://)'))]), const SizedBox(height: 12), TextField(controller: web, decoration: const InputDecoration(labelText: 'Website URL')), const SizedBox(height: 8), SwitchListTile(value: active, onChanged: (v) => setS(() => active = v), title: const Text('Active'), contentPadding: EdgeInsets.zero)]))));
    if (ok != true || name.text.trim().isEmpty) return;
    try { final body = {'name': name.text.trim(), 'color': color.text.trim(), 'deepLinkScheme': link.text.trim(), 'websiteUrl': web.text.trim(), 'active': active}; if (p == null) { await api.post('/platforms', body: body); } else { await api.put('/platforms/${p.id}', body: body); } if (mounted) toast(context, 'Platform saved'); _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }

  Future<void> _toggle(PlatformInfo p) async { try { await api.put('/platforms/${p.id}', body: {'active': !p.active}); _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  @override
  Widget build(BuildContext context) {
    num n(dynamic v) => (v as num?) ?? 0;
    final total = _usage.fold<num>(0, (s, u) => s + n(u['trips']));
    return PageBody(children: [
      PageHeader(title: 'Platform Management', breadcrumb: 'Platform Management', subtitle: 'Trip tracking platforms drivers perform trips in (Routematic, MoveInSync, WhistleDrive, Uber for Business…).', actions: [GoldButton(label: 'Add Platform', icon: Icons.add, onPressed: () => _edit())]),
      const SizedBox(height: 14),
      if (_loading) const LoadingState() else if (_error != null) ErrorState(message: _error!, onRetry: _load) else ...[
        StatGrid(minWidth: 200, cards: [for (final u in _usage) StatCard(label: u['name'] as String, value: '${n(u['trips'])} trips', icon: Icons.near_me, iconColor: GamyaColors.fromHex(u['color'] as String?), trend: '${n(u['adhocRequests'])} requests · ${n(u['bookings'])} bookings', trendColor: GamyaColors.textSecondary, trendIcon: Icons.info_outline)]),
        const SizedBox(height: 12),
        CardRow(minWidth: 320, flex: const [3, 2], children: [
          SectionCard(title: 'Platforms', padding: const EdgeInsets.all(12), child: GTable<PlatformInfo>(minWidth: 700, columns: const [GColumn('Platform', width: 180), GColumn('Code', width: 130), GColumn('Deep link', flex: 1), GColumn('Drivers', width: 70, numeric: true), GColumn('Vehicles', width: 70, numeric: true), GColumn('Trips', width: 70, numeric: true), GColumn('Status', width: 80), GColumn('Actions', width: 90)], rows: _items, rowId: (p) => p.id, cells: (p, i) => [PlatformChip(name: p.name, color: p.color), CellText(p.code, muted: true), CellText(p.deepLinkScheme ?? p.websiteUrl, muted: true), CellText('${p.drivers}'), CellText('${p.vehicles}'), CellText('${p.trips}'), StatusChip(p.active ? 'ACTIVE' : 'INACTIVE', small: true), RowActions(onEdit: () => _edit(p), extra: [const SizedBox(width: 4), TableIconButton(icon: p.active ? Icons.toggle_on : Icons.toggle_off, color: p.active ? GamyaColors.success : GamyaColors.textMuted, tooltip: p.active ? 'Deactivate' : 'Activate', onPressed: () => _toggle(p))])])),
          SectionCard(title: 'Platform Wise Trips', child: Center(child: DonutChart(centerLabel: '$total', slices: [for (final u in _usage) ChartSlice(label: u['name'] as String, value: n(u['trips']), color: GamyaColors.fromHex(u['color'] as String?))]))),
        ]),
      ],
    ]);
  }
}
