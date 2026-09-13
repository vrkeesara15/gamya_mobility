import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class MyTripsPage extends ConsumerStatefulWidget {
  const MyTripsPage({super.key, this.initialTab});
  final String? initialTab;
  @override
  ConsumerState<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends ConsumerState<MyTripsPage> {
  late int _tab = widget.initialTab == 'completed' ? 1 : widget.initialTab == 'cancelled' ? 2 : 0;
  List<Trip> _items = []; bool _loading = true; String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() { _loading = true; _error = null; }); try { final d = await ref.read(apiProvider).paged('/trips', Trip.new, query: {'pageSize': 100}); if (mounted) setState(() { _items = d.items; _loading = false; }); } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); } }
  @override
  Widget build(BuildContext context) {
    final ongoing = _items.where((t) => ['ASSIGNED', 'ACCEPTED', 'YET_TO_START', 'ON_TRIP', 'DELAYED'].contains(t.status)).toList();
    final list = _tab == 0 ? ongoing : _tab == 1 ? _items.where((t) => t.status == 'COMPLETED').toList() : _items.where((t) => t.status == 'CANCELLED').toList();
    final now = DateTime.now();
    final current = ongoing.where((t) => t.status != 'ASSIGNED' && (Fmt.parse(t.scheduledStart)?.isBefore(now.add(const Duration(hours: 3))) ?? false)).toList();
    final upcoming = ongoing.where((t) => !current.contains(t)).toList();
    return PageScaffold(title: 'My Trips', padding: const EdgeInsets.all(14), onBack: () => context.canPop() ? context.pop() : context.go('/drv'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PillTabs(tabs: ['Ongoing (${ongoing.length})', 'Completed', 'Cancelled'], selected: _tab, onChanged: (i) => setState(() => _tab = i)), const SizedBox(height: 12),
      if (_loading) const LoadingState() else if (_error != null) ErrorState(message: _error!, onRetry: _load)
      else if (_tab == 0) ...[
        if (current.isEmpty && upcoming.isEmpty) const EmptyState(icon: Icons.route_outlined, title: 'No ongoing trips'),
        for (final t in current) _ongoingCard(t),
        const SizedBox(height: 6), const Text('Upcoming Trips', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 8),
        if (upcoming.isEmpty) Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.border)), child: const Center(child: Text('No upcoming trips', style: TextStyle(color: GamyaColors.textMuted)))),
        for (final t in upcoming) _row(t),
      ] else if (list.isEmpty) EmptyState(icon: Icons.inbox_outlined, title: _tab == 1 ? 'No completed trips yet' : 'No cancelled trips')
      else for (final t in list) _row(t),
    ]));
  }

  Widget _ongoingCard(Trip t) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.gold)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: GamyaColors.success, borderRadius: BorderRadius.circular(6)), child: Text(t.status == 'ON_TRIP' || t.status == 'DELAYED' ? 'Trip in Progress' : Fmt.title(t.status), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))), const Spacer(), IconButton(onPressed: () => context.push('/drv/accepted/${t.id}').then((_) => _load()), icon: const Icon(Icons.more_vert))]),
    Text('#${t.code}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 8),
    OutlineButton(label: 'Open in ${t.platformName}', icon: Icons.person_pin_circle_outlined, expand: true, dense: true, onPressed: () async { final p = t.platform; if (p?.websiteUrl != null) await launchUrl(Uri.parse(p!.websiteUrl!), mode: LaunchMode.externalApplication); }),
    const SizedBox(height: 8),
    InfoRow('Vehicle', '${Fmt.vehicleType(t.vehicleType)} | ${Fmt.date(t.scheduledStart)}', icon: Icons.directions_car_outlined), InfoRow('Pickup', t.fromLocation, icon: Icons.trip_origin), InfoRow('Drop', t.toLocation, icon: Icons.location_on_outlined), InfoRow('Platform', null, icon: Icons.hub_outlined, valueWidget: Align(alignment: Alignment.centerRight, child: PlatformChip(name: t.platformName, color: t.platform?.color, compact: true))),
    const SizedBox(height: 6), GoldButton(label: t.status == 'ON_TRIP' || t.status == 'DELAYED' ? 'Complete Trip' : 'Start Trip', expand: true, dense: true, onPressed: () => context.push('/drv/accepted/${t.id}').then((_) => _load())),
  ]));

  Widget _row(Trip t) => InkWell(borderRadius: BorderRadius.circular(12), onTap: () => context.push(t.status == 'COMPLETED' ? '/drv/completed/${t.id}' : t.status == 'ASSIGNED' ? '/drv/trip/${t.id}' : '/drv/accepted/${t.id}').then((_) => _load()), child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.border)), child: Row(children: [
    Container(width: 40, height: 40, decoration: BoxDecoration(color: GamyaColors.goldPale, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.local_taxi, color: GamyaColors.goldDark)), const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('#${t.code} · ${Fmt.vehicleType(t.vehicleType)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text('${t.fromLocation} → ${t.toLocation}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary)), Text('${Fmt.dateTimeShort(t.scheduledStart)} · ${t.platformName}', style: const TextStyle(fontSize: 11.5, color: GamyaColors.textMuted))])),
    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [StatusChip(t.status, small: true), if (t.amount != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(Fmt.inr(t.amount), style: const TextStyle(fontWeight: FontWeight.w700, color: GamyaColors.goldDark, fontSize: 12.5)))]),
  ])));
}
