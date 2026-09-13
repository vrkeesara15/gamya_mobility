import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class TripCompletedPage extends ConsumerStatefulWidget {
  const TripCompletedPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<TripCompletedPage> createState() => _TripCompletedPageState();
}

class _TripCompletedPageState extends ConsumerState<TripCompletedPage> {
  Trip? _t;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final api = ref.read(apiProvider); final r = await api.get('/trips/${widget.id}'); if (mounted) setState(() => _t = Trip(api.data(r))); } catch (_) {} }
  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(backgroundColor: Colors.white, body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: t == null ? const LoadingState(height: 300) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 30),
      const SuccessHeader(title: 'Trip Completed!', subtitle: 'Great job!'),
      const SizedBox(height: 22),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GamyaColors.goldPale, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.gold)), child: Row(children: [const Expanded(child: Text('Trip Amount', style: TextStyle(fontWeight: FontWeight.w700))), Text(Fmt.inr(t.amount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: GamyaColors.goldDark))])),
      const SizedBox(height: 12),
      InfoCard(children: [InfoRow('Trip ID', '#${t.code}', icon: Icons.confirmation_number_outlined), InfoRow('Date', Fmt.date(t.scheduledStart), icon: Icons.calendar_today_outlined), InfoRow('Pickup', t.fromLocation, icon: Icons.trip_origin), InfoRow('Drop', t.toLocation, icon: Icons.location_on_outlined), InfoRow('Platform', null, icon: Icons.hub_outlined, valueWidget: Align(alignment: Alignment.centerRight, child: PlatformChip(name: t.platformName, color: t.platform?.color, compact: true))), InfoRow('Completed At', Fmt.dateTime(t.completedAt), icon: Icons.check_circle_outline), if (t.onTime != null) InfoRow('On Time', t.onTime! ? 'Yes' : 'No', icon: Icons.schedule)]),
      const Spacer(),
      OutlineButton(label: 'View Earnings', expand: true, onPressed: () => context.push('/drv/earnings')), const SizedBox(height: 10),
      GoldButton(label: 'Back to Home', expand: true, onPressed: () => context.go('/drv')),
    ]))));
  }
}
