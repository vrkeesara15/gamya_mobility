import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/data_table.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/list_helpers.dart';
import '../../widgets/page_scaffold.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int _tab = 0; final _q = ListQuery(pageSize: 20); final _qs = ListQuery(pageSize: 20);
  Paged<AppNotification> _inbox = Paged.empty(); Paged<Map<String, dynamic>> _sent = Paged.empty(); bool _loading = true; String? _error; int _unread = 0;
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final r = await Future.wait([api.get('/notifications', query: _q.toQuery()), api.paged('/notifications/all', (j) => j, query: _qs.toQuery())]); final d = api.data(r[0] as Map<String, dynamic>); if (mounted) setState(() { _inbox = Paged.fromJson(d, AppNotification.new); _unread = (d['unreadCount'] as num?)?.toInt() ?? 0; _sent = r[1] as Paged<Map<String, dynamic>>; _loading = false; }); ref.read(badgesProvider.notifier).state = Badges(pendingApprovals: ref.read(badgesProvider).pendingApprovals, unread: _unread); }
    catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); }
  }
  Future<void> _send() async {
    final t = TextEditingController(); final b = TextEditingController(); String audience = 'DRIVERS';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => FormDialog(title: 'Send Notification', width: 480, saveLabel: 'Send', onSave: () => Navigator.pop(ctx, true), child: Column(children: [DropdownButtonFormField<String>(initialValue: audience, decoration: const InputDecoration(labelText: 'Audience'), items: const [DropdownMenuItem(value: 'DRIVERS', child: Text('All Drivers')), DropdownMenuItem(value: 'SUPERVISORS', child: Text('All Supervisors')), DropdownMenuItem(value: 'ADMINS', child: Text('All Admins')), DropdownMenuItem(value: 'ALL', child: Text('Everyone'))], onChanged: (v) => setS(() => audience = v ?? 'DRIVERS')), const SizedBox(height: 12), TextField(controller: t, decoration: const InputDecoration(labelText: 'Title')), const SizedBox(height: 12), TextField(controller: b, maxLines: 4, decoration: const InputDecoration(labelText: 'Message'))]))));
    if (ok != true || t.text.trim().isEmpty) return;
    try { final r = await api.post('/notifications/send', body: {'title': t.text.trim(), 'body': b.text.trim(), 'audience': audience}); if (mounted) toast(context, 'Sent to ${api.data(r)['recipients']} recipients'); _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }
  void _openTarget(AppNotification n) {
    final d = n.data;
    if (d['adhocId'] != null) { context.go('/adhoc?id=${d['adhocId']}'); } else if (d['tripId'] != null) { context.go('/live-trips?id=${d['tripId']}'); } else if (d['approvalId'] != null) { context.go('/approvals?id=${d['approvalId']}'); } else if (d['driverId'] != null) { context.go('/approvals?tab=drivers'); } else if (d['supervisorId'] != null) { context.go('/approvals?tab=supervisors'); } else if (d['bookingId'] != null) { context.go('/bookings?id=${d['bookingId']}'); }
  }
  IconData _icon(String t) => switch (t) { 'TRIP_REQUEST' => Icons.add_road, 'TRIP_UPDATE' => Icons.navigation_outlined, 'APPROVAL' => Icons.verified_user_outlined, 'PAYMENT' => Icons.currency_rupee, 'ACCOUNT' => Icons.person_outline, _ => Icons.notifications_outlined };

  @override
  Widget build(BuildContext context) => PageBody(children: [
    PageHeader(title: 'Notifications', breadcrumb: 'Notifications', subtitle: 'System alerts for approvals, trips and payments. Broadcast messages to drivers and supervisors.', actions: [OutlineButton(label: 'Mark all read', icon: Icons.done_all, onPressed: () async { await api.post('/notifications/read-all'); _load(); }), GoldButton(label: 'Send Notification', icon: Icons.send_outlined, onPressed: _send)]),
    const SizedBox(height: 14),
    Align(alignment: Alignment.centerLeft, child: PillTabs(tabs: ['Inbox ($_unread unread)', 'Sent / All'], selected: _tab, onChanged: (i) => setState(() => _tab = i))),
    const SizedBox(height: 12),
    if (_loading) const Card(child: LoadingState()) else if (_error != null) Card(child: ErrorState(message: _error!, onRetry: _load)) else if (_tab == 0) Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
      if (_inbox.items.isEmpty) const EmptyState(icon: Icons.notifications_none, title: 'No notifications'),
      for (final n in _inbox.items) ListTile(
        leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: n.read ? GamyaColors.neutralBg : GamyaColors.goldPale, borderRadius: BorderRadius.circular(10)), child: Icon(_icon(n.type), color: n.read ? GamyaColors.textMuted : GamyaColors.gold, size: 20)),
        title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700, fontSize: 13.5)), subtitle: Text(n.body, style: const TextStyle(fontSize: 12.5)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(Fmt.ago(n.createdAt), style: const TextStyle(fontSize: 11, color: GamyaColors.textMuted)), if (!n.read) Container(margin: const EdgeInsets.only(top: 4), width: 8, height: 8, decoration: const BoxDecoration(color: GamyaColors.danger, shape: BoxShape.circle))]),
        onTap: () async { if (!n.read) { await api.patch('/notifications/${n.id}/read'); _load(); } if (mounted) _openTarget(n); },
      ),
      const SizedBox(height: 8), PaginationBar(paged: _inbox, noun: 'notifications', onPage: (p) { _q.page = p; _load(); }),
    ]))) else Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GTable<Map<String, dynamic>>(minWidth: 800, columns: const [GColumn('Sent', width: 150), GColumn('Recipient', width: 160), GColumn('Role', width: 90), GColumn('Type', width: 110), GColumn('Title', width: 200), GColumn('Message', flex: 2), GColumn('Read', width: 60)], rows: _sent.items, cells: (n, i) => [CellText(Fmt.dateTimeShort(n['createdAt'])), CellText(n['recipient'] as String?), CellText(Fmt.title(n['recipientRole'] as String?)), CellText(Fmt.title(n['type'] as String?)), CellText(n['title'] as String?, bold: true), CellText(n['body'] as String?, maxLines: 2), Icon(n['read'] == true ? Icons.done_all : Icons.schedule, size: 16, color: n['read'] == true ? GamyaColors.success : GamyaColors.textMuted)]),
      const SizedBox(height: 10), PaginationBar(paged: _sent, noun: 'notifications', onPage: (p) { _qs.page = p; _load(); }),
    ]))),
  ]);
}
