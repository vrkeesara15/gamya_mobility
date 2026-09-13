import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class EarningsPage extends ConsumerStatefulWidget {
  const EarningsPage({super.key});
  @override
  ConsumerState<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends ConsumerState<EarningsPage> {
  int _tab = 0; Map<String, dynamic>? _d; String? _error;
  static const _periods = ['week', 'month', 'all'];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() { _d = null; _error = null; }); try { final api = ref.read(apiProvider); final r = await api.get('/driver/earnings', query: {'period': _periods[_tab], 'pageSize': 100}); if (mounted) setState(() => _d = api.data(r)); } catch (e) { if (mounted) setState(() => _error = e.msg); } }
  @override
  Widget build(BuildContext context) {
    final d = _d; final items = ((d?['items'] as List?) ?? []).cast<Map<String, dynamic>>().map(Earning.new).toList();
    return PageScaffold(title: 'My Earnings', padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [GamyaColors.goldDark, GamyaColors.gold]), borderRadius: BorderRadius.circular(14)), child: Column(children: [Text(_tab == 0 ? 'This Week' : _tab == 1 ? 'This Month' : 'Total Earnings', style: const TextStyle(color: Colors.white70, fontSize: 12.5)), const SizedBox(height: 4), Text(Fmt.inr(d?['periodTotal']), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text('Pending settlement ${Fmt.inr(d?['pending'])}', style: const TextStyle(color: Colors.white, fontSize: 12))])),
      const SizedBox(height: 12),
      PillTabs(tabs: const ['This Week', 'This Month', 'All Time'], selected: _tab, onChanged: (i) { setState(() => _tab = i); _load(); }), const SizedBox(height: 12),
      if (_error != null) ErrorState(message: _error!, onRetry: _load) else if (d == null) const LoadingState() else if (items.isEmpty) const EmptyState(icon: Icons.currency_rupee, title: 'No earnings in this period')
      else for (final e in items) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.border)), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(Fmt.date(e.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text('${Fmt.vehicleType(e.vehicleType)} | ${e.platform}${e.tripCode != null ? ' · #${e.tripCode}' : ''}', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(Fmt.inr(e.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: GamyaColors.success, fontSize: 14)), StatusChip(e.status, small: true, dot: false)]),
      ])),
    ]));
  }
}
