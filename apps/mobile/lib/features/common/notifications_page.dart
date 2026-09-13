import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int _tab = 0; List<AppNotification> _items = []; bool _loading = true; String? _error; int _tripRequests = 0;
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final r = await api.get('/notifications', query: {'pageSize': 50}); final d = api.data(r); if (mounted) setState(() { _items = (d['items'] as List).cast<Map<String, dynamic>>().map(AppNotification.new).toList(); _tripRequests = _items.where((n) => n.type == 'TRIP_REQUEST').length; _loading = false; }); }
    catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); }
  }
  void _open(AppNotification n) async {
    if (!n.read) { try { await api.patch('/notifications/${n.id}/read'); } catch (_) {} }
    final u = ref.read(sessionProvider)!; final d = n.data;
    if (!mounted) return;
    if (u.isDriver) { if (d['tripId'] != null) { context.push('/drv/trip/${d['tripId']}'); } else if (d['adhocId'] != null) { context.push('/drv/trip/${d['adhocId']}?adhoc=1'); } else if (n.type == 'PAYMENT') { context.push('/drv/earnings'); } else if (n.type == 'APPROVAL' || n.type == 'ACCOUNT') { context.go('/drv'); } }
    else if (u.isSupervisor) { if (d['adhocId'] != null) { context.push('/sup/track/${d['adhocId']}'); } else if (d['tripId'] != null) { context.push('/sup/bookings'); } }
    _load();
  }
  IconData _icon(String t) => switch (t) { 'TRIP_REQUEST' => Icons.add_road, 'TRIP_UPDATE' => Icons.navigation_outlined, 'APPROVAL' => Icons.verified_user_outlined, 'PAYMENT' => Icons.currency_rupee, 'ACCOUNT' => Icons.person_outline, _ => Icons.notifications_outlined };
  Color _color(String t) => switch (t) { 'TRIP_REQUEST' => GamyaColors.gold, 'TRIP_UPDATE' => GamyaColors.success, 'APPROVAL' => GamyaColors.info, 'PAYMENT' => GamyaColors.success, 'ACCOUNT' => GamyaColors.info, _ => GamyaColors.textMuted };

  @override
  Widget build(BuildContext context) {
    final list = _tab == 0 ? _items : _tab == 1 ? _items.where((n) => n.type == 'TRIP_REQUEST').toList() : _items.where((n) => n.type != 'TRIP_REQUEST').toList();
    return PageScaffold(title: 'Notifications', padding: const EdgeInsets.all(14), actions: [IconButton(onPressed: () async { await api.post('/notifications/read-all'); _load(); }, icon: const Icon(Icons.done_all), tooltip: 'Mark all read')], child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PillTabs(tabs: ['All', 'Trip Requests ($_tripRequests)', 'Updates'], selected: _tab, onChanged: (i) => setState(() => _tab = i)), const SizedBox(height: 12),
      if (_loading) const LoadingState() else if (_error != null) ErrorState(message: _error!, onRetry: _load) else if (list.isEmpty) const EmptyState(icon: Icons.notifications_none, title: 'No notifications')
      else for (final n in list) InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _open(n), child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: n.read ? Colors.white : GamyaColors.goldPale.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: _color(n.type), shape: BoxShape.circle), child: Icon(_icon(n.type), color: Colors.white, size: 18)), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800, fontSize: 13.5)), const SizedBox(height: 2), Text(n.body, style: const TextStyle(fontSize: 12.5, color: GamyaColors.textSecondary)), const SizedBox(height: 4), Align(alignment: Alignment.centerRight, child: Text(Fmt.ago(n.createdAt), style: const TextStyle(fontSize: 11, color: GamyaColors.textMuted)))])),
      ]))),
    ]));
  }
}
