import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

/// "Trip Accepted!" screen + start / complete controls for the accepted trip.
class TripAcceptedPage extends ConsumerStatefulWidget {
  const TripAcceptedPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<TripAcceptedPage> createState() => _TripAcceptedPageState();
}

class _TripAcceptedPageState extends ConsumerState<TripAcceptedPage> {
  Trip? _t; String? _error; bool _busy = false; bool _details = false;
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final r = await api.get('/trips/${widget.id}'); if (mounted) setState(() => _t = Trip(api.data(r))); } catch (e) { if (mounted) setState(() => _error = e.msg); } }
  Future<void> _openPlatform() async {
    final p = _t?.platform; if (p == null) { toast(context, 'Perform this trip in the assigned platform app.'); return; }
    try { if (p.deepLinkScheme != null && p.deepLinkScheme!.isNotEmpty && await canLaunchUrl(Uri.parse(p.deepLinkScheme!))) { await launchUrl(Uri.parse(p.deepLinkScheme!)); return; } } catch (_) {}
    if (p.websiteUrl != null && p.websiteUrl!.isNotEmpty) { await launchUrl(Uri.parse(p.websiteUrl!), mode: LaunchMode.externalApplication); } else if (mounted) { toast(context, 'Open the ${p.name} app to perform this trip.'); }
  }
  Future<void> _start() async { setState(() => _busy = true); try { await api.post('/trips/${widget.id}/start'); await _load(); if (mounted) toast(context, 'Trip started. Drive safe!'); } catch (e) { if (mounted) toast(context, e.msg, error: true); } if (mounted) setState(() => _busy = false); }
  Future<void> _complete() async {
    if (!await confirm(context, title: 'Complete trip', message: 'Mark this trip as completed?', confirmLabel: 'Complete')) return;
    setState(() => _busy = true);
    try { await api.post('/trips/${widget.id}/complete'); if (mounted) context.pushReplacement('/drv/completed/${widget.id}'); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (_error != null) return PageScaffold(title: 'Trip', child: ErrorState(message: _error!, onRetry: _load));
    if (t == null) return const PageScaffold(title: 'Trip', child: LoadingState(height: 300));
    final started = t.status == 'ON_TRIP' || t.status == 'DELAYED';
    return PageScaffold(
      title: started ? 'Trip in Progress' : 'Trip Accepted', onBack: () => context.canPop() ? context.pop() : context.go('/drv'),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!started && t.status == 'ACCEPTED' || t.status == 'YET_TO_START') GoldButton(label: 'Start Trip', icon: Icons.play_arrow, expand: true, loading: _busy, onPressed: _start),
        if (started) GoldButton(label: 'Complete Trip', icon: Icons.check, color: GamyaColors.success, expand: true, loading: _busy, onPressed: _complete),
        if (t.status == 'COMPLETED') GoldButton(label: 'View Summary', expand: true, onPressed: () => context.pushReplacement('/drv/completed/${t.id}')),
        const SizedBox(height: 8),
        OutlineButton(label: _details ? 'Hide Details' : 'View Details', expand: true, onPressed: () => setState(() => _details = !_details)),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        SuccessHeader(title: started ? 'Trip in Progress' : 'Trip Accepted!', subtitle: 'Please perform this trip in\n${t.platformName} app.', icon: started ? Icons.navigation : Icons.check),
        const SizedBox(height: 18),
        InfoCard(children: [
          Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: GamyaColors.successBg, borderRadius: BorderRadius.circular(6)), child: Text(Fmt.title(t.status), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: GamyaColors.success))), const Spacer(), Text('#${t.code}', style: const TextStyle(fontWeight: FontWeight.w800))]),
          const SizedBox(height: 10),
          OutlineButton(label: 'Open in ${t.platformName}', icon: Icons.open_in_new, expand: true, onPressed: _openPlatform),
          const SizedBox(height: 10),
          InfoRow('Trip ID', '#${t.code}', icon: Icons.confirmation_number_outlined), InfoRow('Date', Fmt.date(t.scheduledStart), icon: Icons.calendar_today_outlined), InfoRow('Login Time', Fmt.time24(t.loginTime), icon: Icons.schedule), InfoRow('Reporting Time', Fmt.time24(t.reportingTime), icon: Icons.schedule), InfoRow('Pickup', t.fromLocation, icon: Icons.trip_origin), InfoRow('Drop', t.toLocation, icon: Icons.location_on_outlined), InfoRow('Platform', null, icon: Icons.hub_outlined, valueWidget: Align(alignment: Alignment.centerRight, child: PlatformChip(name: t.platformName, color: t.platform?.color, compact: true))),
          if (_details) ...[const Divider(height: 20), InfoRow('Vehicle', '${t.vehicle['number']} · ${Fmt.vehicleType(t.vehicleType)}'), InfoRow('Client', t.clientName), if (t.supervisor != null) InfoRow('Supervisor', '${t.supervisor!['fullName']} (${t.supervisor!['mobile'] ?? ''})'), InfoRow('Passengers', '${t.passengers}'), InfoRow('Amount', Fmt.inr(t.amount), bold: true), if (t.specialInstructions != null) InfoRow('Instructions', t.specialInstructions), const SizedBox(height: 8), TrackingTimeline(steps: TrackingTimeline.fromTrip(events: t.events, status: t.status, platformName: t.platformName, createdAt: t.raw['createdAt']))],
        ]),
        NoteBox('Trip has been assigned to you. You will now see this trip in the ${t.platformName} app.', color: GamyaColors.gold, icon: Icons.star_outline),
      ]),
    );
  }

}
