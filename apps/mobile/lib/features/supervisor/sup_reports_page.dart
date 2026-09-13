import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class SupReportsPage extends ConsumerStatefulWidget {
  const SupReportsPage({super.key});
  @override
  ConsumerState<SupReportsPage> createState() => _SupReportsPageState();
}

class _SupReportsPageState extends ConsumerState<SupReportsPage> {
  Map<String, dynamic>? _r; String? _error; DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 29)), end: DateTime.now());
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final api = ref.read(apiProvider); final r = await api.get('/supervisor/reports', query: {'from': Fmt.iso(_range.start), 'to': Fmt.iso(_range.end)}); if (mounted) setState(() => _r = api.data(r)); } catch (e) { if (mounted) setState(() => _error = e.msg); } }
  @override
  Widget build(BuildContext context) {
    final r = _r; num n(dynamic v) => (v as num?) ?? 0;
    return PageScaffold(title: 'Reports', child: _error != null ? ErrorState(message: _error!, onRetry: _load) : r == null ? const LoadingState(height: 300) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlinedButton.icon(onPressed: () async { final p = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now(), initialDateRange: _range); if (p != null) { setState(() => _range = p); _load(); } }, icon: const Icon(Icons.calendar_today_outlined, size: 16), label: Text('${Fmt.date(_range.start)} – ${Fmt.date(_range.end)}')), const SizedBox(height: 14),
      Row(children: [Expanded(child: MiniStat(label: 'Requests', value: '${n(r['total'])}', icon: Icons.list_alt)), const SizedBox(width: 8), Expanded(child: MiniStat(label: 'Completed', value: '${n(r['completed'])}', icon: Icons.check_circle_outline, color: GamyaColors.success))]), const SizedBox(height: 8),
      Row(children: [Expanded(child: MiniStat(label: 'Cancelled', value: '${n(r['cancelled'])}', icon: Icons.cancel_outlined, color: GamyaColors.danger)), const SizedBox(width: 8), Expanded(child: MiniStat(label: 'Est. Spend', value: Fmt.inr(r['estimatedSpend']), icon: Icons.currency_rupee))]), const SizedBox(height: 16),
      InfoCard(title: 'By Vehicle Type', children: [HBarList(labelWidth: 110, items: [for (final x in (r['byVehicleType'] as List).cast<Map<String, dynamic>>()) ChartSlice(label: Fmt.vehicleType(x['vehicleType'] as String?), value: n(x['count']), color: GamyaColors.gold)])]),
      InfoCard(title: 'By Platform', children: [Center(child: DonutChart(size: 120, slices: [for (final x in (r['byPlatform'] as List).cast<Map<String, dynamic>>()) ChartSlice(label: x['name'] as String, value: n(x['count']), color: GamyaColors.fromHex(x['color'] as String?))]))]),
    ]));
  }
}
