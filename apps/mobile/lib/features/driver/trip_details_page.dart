import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

/// Trip Details (before accept). Works for an assigned Trip or an open ad-hoc request (adhoc = true).
class TripDetailsPage extends ConsumerStatefulWidget {
  const TripDetailsPage({super.key, required this.id, this.adhoc = false});
  final String id; final bool adhoc;
  @override
  ConsumerState<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends ConsumerState<TripDetailsPage> {
  Map<String, dynamic>? _d; String? _error; bool _busy = false;
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      if (widget.adhoc) { final r = await api.get('/trips/available'); final open = (api.data(r)['open'] as List).cast<Map<String, dynamic>>(); final a = open.where((x) => x['id'] == widget.id).firstOrNull; if (a == null) { setState(() => _error = 'This request is no longer available.'); return; } setState(() => _d = {...a, 'status': 'OPEN'}); }
      else { final r = await api.get('/trips/${widget.id}'); setState(() => _d = api.data(r)); }
    } catch (e) { if (mounted) setState(() => _error = e.msg); }
  }
  Future<void> _accept() async {
    setState(() => _busy = true);
    try { final r = widget.adhoc ? await api.post('/trips/adhoc/${widget.id}/accept') : await api.post('/trips/${widget.id}/accept'); if (mounted) context.pushReplacement('/drv/accepted/${api.data(r)['id']}'); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }
  Future<void> _decline() async {
    if (widget.adhoc) { context.pop(); return; }
    if (!await confirm(context, title: 'Decline trip', message: 'Decline this trip? The admin will re-assign it.', confirmLabel: 'Decline', danger: true)) return;
    setState(() => _busy = true);
    try { await api.post('/trips/${widget.id}/decline', body: {'reason': 'Declined by driver'}); if (mounted) { toast(context, 'Trip declined'); context.pop(); } } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (_error != null) return PageScaffold(title: 'Trip Details', child: ErrorState(message: _error!, onRetry: _load));
    if (d == null) return const PageScaffold(title: 'Trip Details', child: LoadingState(height: 300));
    final status = d['status'] as String; final canAct = status == 'OPEN' || status == 'ASSIGNED';
    final platform = d['platform'] as Map<String, dynamic>?; final when = d['scheduledAt'] ?? d['scheduledStart'];
    return PageScaffold(
      title: 'Trip Details',
      bottom: canAct ? Row(children: [Expanded(child: OutlineButton(label: 'Decline', color: GamyaColors.danger, loading: _busy, onPressed: _decline)), const SizedBox(width: 10), Expanded(child: GoldButton(label: 'Accept', loading: _busy, onPressed: _accept))]) : GoldButton(label: status == 'ACCEPTED' || status == 'ON_TRIP' || status == 'DELAYED' || status == 'YET_TO_START' ? 'Open Trip' : 'Back', expand: true, onPressed: () => canAct ? null : status == 'COMPLETED' ? context.pushReplacement('/drv/completed/${widget.id}') : status == 'CANCELLED' ? context.pop() : context.pushReplacement('/drv/accepted/${widget.id}')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: GamyaColors.successBg, borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.local_taxi, color: GamyaColors.success), const SizedBox(width: 10), Expanded(child: Text(status == 'OPEN' ? 'New Ad-hoc Requirement' : status == 'ASSIGNED' ? 'Trip assigned to you' : 'Trip ${Fmt.title(status)}', style: const TextStyle(fontWeight: FontWeight.w700))), if (d['code'] != null) Text('#${d['adhocCode'] ?? d['code']}', style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))])),
        const SizedBox(height: 12),
        InfoCard(children: [InfoRow('Vehicle Type', Fmt.vehicleType(d['vehicleType'] as String?)), InfoRow('Model Year', d['modelYearMin'] == null ? '—' : '${d['modelYearMin']} & Above'), InfoRow('Date', Fmt.date(when)), InfoRow('Login Time', Fmt.time24(d['loginTime'] as String?)), InfoRow('Reporting Time', Fmt.time24(d['reportingTime'] as String?)), InfoRow('Passengers', '${d['passengers'] ?? 1}')]),
        InfoCard(children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.trip_origin, color: GamyaColors.info, size: 18), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Pickup Location', style: TextStyle(fontSize: 11.5, color: GamyaColors.textSecondary)), Text(d['fromLocation'] as String, style: const TextStyle(fontWeight: FontWeight.w600))]))]), const SizedBox(height: 10), Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.location_on, color: GamyaColors.danger, size: 18), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Drop Location', style: TextStyle(fontSize: 11.5, color: GamyaColors.textSecondary)), Text(d['toLocation'] as String, style: const TextStyle(fontWeight: FontWeight.w600))]))])]),
        InfoCard(children: [InfoRow('Booking Type', d['bookingType'] == 'SCHEDULED' ? 'Scheduled Booking' : 'Instant Booking'), InfoRow('Platform', null, valueWidget: Align(alignment: Alignment.centerRight, child: PlatformChip(name: platform?['name'] as String? ?? 'Other', color: platform?['color'] as String?, compact: true))), if (d['clientName'] != null) InfoRow('Client', d['clientName'] as String?), if (d['specialInstructions'] != null) InfoRow('Instructions', d['specialInstructions'] as String?), InfoRow('Estimated Amount', Fmt.inr(d['estimatedAmount'] ?? d['amount']), bold: true)]),
      ]),
    );
  }
}
