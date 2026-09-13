import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class BookingTrackingPage extends ConsumerStatefulWidget {
  const BookingTrackingPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<BookingTrackingPage> createState() => _BookingTrackingPageState();
}

class _BookingTrackingPageState extends ConsumerState<BookingTrackingPage> {
  AdhocRequest? _a; String? _error; int _tab = 0; Timer? _timer;
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load()); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  Future<void> _load() async { try { final r = await api.get('/adhoc/${widget.id}'); if (mounted) setState(() { _a = AdhocRequest(api.data(r)); _error = null; }); } catch (e) { if (mounted) setState(() => _error = e.msg); } }
  Future<void> _cancel() async { final ok = await confirm(context, title: 'Cancel Requirement', message: 'Cancel this requirement? The assigned driver will be notified.', confirmLabel: 'Cancel Requirement', danger: true); if (!ok) return; try { await api.post('/adhoc/${widget.id}/cancel', body: {'reason': 'Cancelled by supervisor'}); _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }
  Future<void> _openPlatform() async {
    final p = _a?.platform; if (p == null) return;
    final deep = p.deepLinkScheme; final web = p.websiteUrl;
    try { if (deep != null && deep.isNotEmpty && await canLaunchUrl(Uri.parse(deep))) { await launchUrl(Uri.parse(deep)); return; } } catch (_) {}
    if (web != null && web.isNotEmpty) { await launchUrl(Uri.parse(web), mode: LaunchMode.externalApplication); } else if (mounted) { toast(context, 'Open the ${p.name} app to track this trip.'); }
  }
  @override
  Widget build(BuildContext context) {
    final a = _a;
    if (_error != null) return PageScaffold(title: 'Booking Tracking', child: ErrorState(message: _error!, onRetry: _load));
    if (a == null) return const PageScaffold(title: 'Booking Tracking', child: LoadingState(height: 300));
    final tripStatus = a.trip?['status'] as String? ?? (a.status == 'CANCELLED' ? 'CANCELLED' : 'PENDING');
    final steps = TrackingTimeline.fromTrip(events: a.events, status: tripStatus, platformName: a.platformName, createdAt: a.createdAt);
    final open = !['COMPLETED', 'CANCELLED'].contains(a.status);
    return PageScaffold(
      title: 'Booking Tracking', onBack: () => context.canPop() ? context.pop() : context.go('/sup'),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [if (a.platform != null && a.platform!.code != 'OTHER') OutlineButton(label: 'Track in ${a.platformName}', icon: Icons.open_in_new, expand: true, onPressed: _openPlatform), if (open) ...[const SizedBox(height: 8), OutlineButton(label: 'Cancel Requirement', color: GamyaColors.danger, expand: true, onPressed: _cancel)]]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Text('#${a.code}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const Spacer(), StatusChip(a.status, small: true)]), const SizedBox(height: 10),
        PillTabs(tabs: const ['Live Status', 'Details'], selected: _tab, onChanged: (i) => setState(() => _tab = i)), const SizedBox(height: 14),
        if (_tab == 0) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.border)), child: TrackingTimeline(steps: steps))
        else ...[
          InfoCard(title: 'Trip Details', children: [InfoRow('Vehicle', '${Fmt.vehicleType(a.vehicleType)}${a.modelYearMin != null ? ' (${a.modelYearMin}+)' : ''}', icon: Icons.directions_car_outlined), InfoRow('Date', Fmt.date(a.scheduledAt), icon: Icons.calendar_today_outlined), InfoRow('Login / Reporting', '${Fmt.time24(a.loginTime)} / ${Fmt.time24(a.reportingTime)}', icon: Icons.schedule), InfoRow('Pickup', a.fromLocation, icon: Icons.trip_origin), InfoRow('Drop', a.toLocation, icon: Icons.location_on_outlined), InfoRow('Booking Type', a.bookingType == 'INSTANT' ? 'Instant' : 'Scheduled', icon: Icons.bolt), InfoRow('Platform', a.platformName, icon: Icons.hub_outlined), InfoRow('Estimated Amount', Fmt.inr(a.estimatedAmount), icon: Icons.currency_rupee, bold: true)]),
          if (a.assignedDriver != null) InfoCard(title: 'Driver & Vehicle', children: [Row(children: [GamyaAvatar(url: a.assignedDriver!['avatarUrl'] as String?, name: a.assignedDriver!['fullName'] as String?, size: 46), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.assignedDriver!['fullName'] as String, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${a.assignedVehicle?['number'] ?? ''} · ${a.assignedVehicle?['make'] ?? ''} ${a.assignedVehicle?['model'] ?? ''}', style: const TextStyle(fontSize: 12.5, color: GamyaColors.textSecondary))])), IconButton(onPressed: () => launchUrl(Uri.parse('tel:${a.assignedDriver!['mobile']}')), icon: const Icon(Icons.call, color: GamyaColors.success))])]),
          if (a.cancelReason != null) NoteBox('Cancelled: ${a.cancelReason}', color: GamyaColors.danger, icon: Icons.cancel_outlined),
        ],
      ]),
    );
  }
}
