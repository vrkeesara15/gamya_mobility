import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

/// My Bookings (all) / Ongoing Trips / Booking History.
class MyBookingsPage extends ConsumerStatefulWidget {
  const MyBookingsPage({super.key, this.initialTab});
  final String? initialTab;
  @override
  ConsumerState<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends ConsumerState<MyBookingsPage> {
  late int _tab = widget.initialTab == 'ongoing' ? 1 : widget.initialTab == 'history' ? 2 : 0;
  List<AdhocRequest> _items = []; bool _loading = true; String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() { _loading = true; _error = null; }); try { final d = await ref.read(apiProvider).paged('/adhoc', AdhocRequest.new, query: {'pageSize': 100}); if (mounted) setState(() { _items = d.items; _loading = false; }); } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); } }
  @override
  Widget build(BuildContext context) {
    final list = _tab == 0 ? _items : _tab == 1 ? _items.where((a) => ['PENDING', 'ASSIGNED', 'ACCEPTED', 'IN_PROGRESS'].contains(a.status)).toList() : _items.where((a) => ['COMPLETED', 'CANCELLED'].contains(a.status)).toList();
    return PageScaffold(title: _tab == 1 ? 'Ongoing Trips' : _tab == 2 ? 'Booking History' : 'My Bookings', padding: const EdgeInsets.all(14), onBack: () => context.canPop() ? context.pop() : context.go('/sup'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PillTabs(tabs: const ['All', 'Ongoing', 'History'], selected: _tab, onChanged: (i) => setState(() => _tab = i)), const SizedBox(height: 12),
      if (_loading) const LoadingState() else if (_error != null) ErrorState(message: _error!, onRetry: _load) else if (list.isEmpty) EmptyState(icon: Icons.event_busy, title: 'No bookings here', action: GoldButton(label: 'Post Requirement', dense: true, onPressed: () => context.push('/sup/post')))
      else for (final a in list) InkWell(borderRadius: BorderRadius.circular(12), onTap: () => context.push('/sup/track/${a.id}').then((_) => _load()), child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text('#${a.code}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)), const Spacer(), StatusChip(a.status, small: true)]), const SizedBox(height: 6),
        Row(children: [const Icon(Icons.directions_car_outlined, size: 15, color: GamyaColors.textMuted), const SizedBox(width: 6), Text('${Fmt.vehicleType(a.vehicleType)} · ${Fmt.dateTime(a.scheduledAt)}', style: const TextStyle(fontSize: 12.5))]), const SizedBox(height: 4),
        Row(children: [const Icon(Icons.trip_origin, size: 15, color: GamyaColors.info), const SizedBox(width: 6), Expanded(child: Text(a.fromLocation, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)))]), const SizedBox(height: 2),
        Row(children: [const Icon(Icons.location_on, size: 15, color: GamyaColors.danger), const SizedBox(width: 6), Expanded(child: Text(a.toLocation, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)))]), const SizedBox(height: 6),
        Row(children: [PlatformChip(name: a.platformName, color: a.platform?.color, compact: true), const Spacer(), if (a.assignedDriver != null) Text(a.assignedDriver!['fullName'] as String, style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary)), const SizedBox(width: 8), Text(Fmt.inr(a.estimatedAmount), style: const TextStyle(fontWeight: FontWeight.w700, color: GamyaColors.goldDark))]),
      ]))),
    ]));
  }
}
