import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class BookingSummaryPage extends ConsumerStatefulWidget {
  const BookingSummaryPage({super.key, required this.draft});
  final Map<String, dynamic> draft;
  @override
  ConsumerState<BookingSummaryPage> createState() => _BookingSummaryPageState();
}

class _BookingSummaryPageState extends ConsumerState<BookingSummaryPage> {
  num? _amount; bool _busy = false;
  Map<String, dynamic> get d => widget.draft;
  @override
  void initState() { super.initState(); _estimate(); }
  Future<void> _estimate() async { try { final api = ref.read(apiProvider); final r = await api.post('/adhoc/estimate', body: {'vehicleType': d['vehicleType'], 'numberOfVehicles': d['numberOfVehicles'], 'passengers': d['passengers']}); if (mounted) setState(() => _amount = api.data(r)['estimatedAmount'] as num?); } catch (_) {} }
  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      final r = await api.post('/adhoc', body: {'fromLocation': d['fromLocation'], 'toLocation': d['toLocation'], 'scheduledAt': d['scheduledAt'], 'loginTime': d['loginTime'], 'reportingTime': d['reportingTime'], 'passengers': d['passengers'], 'vehicleType': d['vehicleType'], 'modelYearMin': d['modelYearMin'], 'numberOfVehicles': d['numberOfVehicles'], 'bookingType': d['bookingType'], 'platformId': d['platformId'], 'otherPlatformName': d['otherPlatformName'], 'specialInstructions': d['specialInstructions']});
      if (mounted) context.go('/sup/confirmed/${api.data(r)['id']}');
    } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Booking Summary', bottom: GoldButton(label: 'Confirm Booking', expand: true, loading: _busy, onPressed: _confirm),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InfoCard(title: 'Vehicle Details', children: [InfoRow('Vehicle Type', Fmt.vehicleType(d['vehicleType'] as String?)), InfoRow('Model Year', '${d['modelYearMin']} & Above'), InfoRow('No. of Vehicles', '${d['numberOfVehicles']}'), InfoRow('Passengers', '${d['passengers']}')]),
      InfoCard(title: 'Trip Details', children: [InfoRow('Date', Fmt.date(d['scheduledLocal']), icon: Icons.calendar_today_outlined), InfoRow('Login Time', Fmt.time24(d['loginTime'] as String?), icon: Icons.schedule), InfoRow('Reporting Time', Fmt.time24(d['reportingTime'] as String?), icon: Icons.schedule), InfoRow('Pickup Location', d['fromLocation'] as String?, icon: Icons.trip_origin), InfoRow('Drop Location', d['toLocation'] as String?, icon: Icons.location_on_outlined), if ((d['specialInstructions'] as String?)?.isNotEmpty == true) InfoRow('Instructions', d['specialInstructions'] as String?, icon: Icons.info_outline)]),
      InfoCard(children: [InfoRow('Booking Type', d['bookingType'] == 'INSTANT' ? 'Instant Booking' : 'Scheduled Booking')]),
      InfoCard(title: 'Selected Platform', children: [PlatformChip(name: d['platformCode'] == 'OTHER' && (d['otherPlatformName'] as String).isNotEmpty ? d['otherPlatformName'] as String : d['platformName'] as String, color: d['platformColor'] as String?)]),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.gold)), child: Row(children: [const Expanded(child: Text('Estimated Amount', style: TextStyle(fontWeight: FontWeight.w700))), Text(Fmt.inr(_amount), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: GamyaColors.goldDark))])),
    ]),
  );
}
