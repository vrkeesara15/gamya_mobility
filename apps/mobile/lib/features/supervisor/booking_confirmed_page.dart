import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class BookingConfirmedPage extends ConsumerStatefulWidget {
  const BookingConfirmedPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<BookingConfirmedPage> createState() => _BookingConfirmedPageState();
}

class _BookingConfirmedPageState extends ConsumerState<BookingConfirmedPage> {
  AdhocRequest? _a;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final api = ref.read(apiProvider); final r = await api.get('/adhoc/${widget.id}'); if (mounted) setState(() => _a = AdhocRequest(api.data(r))); } catch (_) {} }
  @override
  Widget build(BuildContext context) {
    final a = _a;
    return Scaffold(backgroundColor: Colors.white, body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 30),
      const SuccessHeader(title: 'Your requirement has been\nposted successfully!'),
      const SizedBox(height: 16),
      Center(child: Column(children: [const Text('Request ID', style: TextStyle(color: GamyaColors.textSecondary, fontSize: 12.5)), Text('#${a?.code ?? '…'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))])),
      const SizedBox(height: 20),
      if (a != null) InfoCard(children: [InfoRow('Vehicle', '${Fmt.vehicleType(a.vehicleType)}${a.modelYearMin != null ? ' (${a.modelYearMin} & Above)' : ''}', icon: Icons.directions_car_outlined), InfoRow('Date & Time', Fmt.dateTime(a.scheduledAt), icon: Icons.calendar_today_outlined), InfoRow('Pickup', a.fromLocation, icon: Icons.trip_origin), InfoRow('Drop', a.toLocation, icon: Icons.location_on_outlined), InfoRow('Platform', a.platformName, icon: Icons.hub_outlined), InfoRow('Estimated Amount', Fmt.inr(a.estimatedAmount), icon: Icons.currency_rupee, bold: true)]) else const LoadingState(height: 120),
      const Spacer(),
      OutlineButton(label: 'View Details', expand: true, onPressed: () => context.go('/sup/track/${widget.id}')), const SizedBox(height: 10),
      GoldButton(label: 'Go to Dashboard', expand: true, onPressed: () => context.go('/sup')),
    ]))));
  }
}
