import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class AvailableTripsPage extends ConsumerStatefulWidget {
  const AvailableTripsPage({super.key});
  @override
  ConsumerState<AvailableTripsPage> createState() => _AvailableTripsPageState();
}

class _AvailableTripsPageState extends ConsumerState<AvailableTripsPage> {
  List<Trip> _assigned = []; List<Map<String, dynamic>> _open = []; bool _loading = true; String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() { _loading = true; _error = null; }); try { final api = ref.read(apiProvider); final r = await api.get('/trips/available'); final d = api.data(r); if (mounted) setState(() { _assigned = (d['assigned'] as List).cast<Map<String, dynamic>>().map(Trip.new).toList(); _open = (d['open'] as List).cast<Map<String, dynamic>>(); _loading = false; }); } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); } }
  @override
  Widget build(BuildContext context) => PageScaffold(title: 'Available Trips', padding: const EdgeInsets.all(14), child: _loading ? const LoadingState() : _error != null ? ErrorState(message: _error!, onRetry: _load) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (_assigned.isEmpty && _open.isEmpty) const EmptyState(icon: Icons.add_road, title: 'No trip requests right now', message: 'New ad-hoc requirements matching your vehicle will appear here.'),
    if (_assigned.isNotEmpty) ...[const Text('Assigned to you', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 8), for (final t in _assigned) _card(context, code: t.adhocCode ?? t.code, vehicleType: t.vehicleType, when: t.scheduledStart, from: t.fromLocation, to: t.toLocation, platform: t.platformName, color: t.platform?.color, amount: t.amount, tag: 'Assigned', onTap: () => context.push('/drv/trip/${t.id}').then((_) => _load())), const SizedBox(height: 12)],
    if (_open.isNotEmpty) ...[const Text('New Ad-hoc Requirements', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 8), for (final a in _open) _card(context, code: a['code'] as String, vehicleType: a['vehicleType'] as String, when: a['scheduledAt'], from: a['fromLocation'] as String, to: a['toLocation'] as String, platform: (a['platform'] as Map?)?['name'] as String? ?? 'Other', color: (a['platform'] as Map?)?['color'] as String?, amount: a['estimatedAmount'] as num?, tag: 'Open', onTap: () => context.push('/drv/trip/${a['id']}?adhoc=1').then((_) => _load()))],
  ]));

  Widget _card(BuildContext context, {required String code, required String vehicleType, required dynamic when, required String from, required String to, required String platform, String? color, num? amount, required String tag, required VoidCallback onTap}) => InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(width: 34, height: 34, decoration: const BoxDecoration(color: GamyaColors.gold, shape: BoxShape.circle), child: const Icon(Icons.local_taxi, color: Colors.white, size: 18)), const SizedBox(width: 10), Expanded(child: Text('New Ad-hoc Requirement', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))), StatusChip(tag == 'Open' ? 'OPEN' : 'ASSIGNED', label: tag, small: true)]), const SizedBox(height: 8),
    Text('${Fmt.vehicleType(vehicleType)} • ${Fmt.date(when)} • ${Fmt.time(when)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)), const SizedBox(height: 3),
    Text('$from → $to', maxLines: 2, style: const TextStyle(fontSize: 12.5, color: GamyaColors.textSecondary)), const SizedBox(height: 6),
    Row(children: [PlatformChip(name: platform, color: color, compact: true), const Spacer(), Text(Fmt.inr(amount), style: const TextStyle(fontWeight: FontWeight.w800, color: GamyaColors.goldDark)), const SizedBox(width: 4), const Icon(Icons.chevron_right, color: GamyaColors.textMuted, size: 18)]),
  ])));
}
