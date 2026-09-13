import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/data_table.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/list_helpers.dart';
import '../../widgets/page_scaffold.dart';

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});
  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  int _tab = 0; Map<String, dynamic> _stats = {}; List<Map<String, dynamic>> _summary = []; Paged<Map<String, dynamic>> _earnings = Paged.empty(); Paged<Map<String, dynamic>> _settlements = Paged.empty(); Paged<Map<String, dynamic>> _invoices = Paged.empty(); List<Map<String, dynamic>> _clients = [];
  final _qe = ListQuery(pageSize: 20); final _qs = ListQuery(pageSize: 20); final _qi = ListQuery(pageSize: 20); bool _loading = true; String? _error;
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([api.get('/payments/stats'), api.get('/payments/driver-summary'), api.paged('/payments/earnings', (j) => j, query: _qe.toQuery()), api.paged('/payments/settlements', (j) => j, query: _qs.toQuery()), api.paged('/payments/invoices', (j) => j, query: _qi.toQuery()), api.get('/clients')]);
      if (mounted) setState(() { _stats = api.data(r[0] as Map<String, dynamic>); _summary = api.list(r[1] as Map<String, dynamic>); _earnings = r[2] as Paged<Map<String, dynamic>>; _settlements = r[3] as Paged<Map<String, dynamic>>; _invoices = r[4] as Paged<Map<String, dynamic>>; _clients = api.list(r[5] as Map<String, dynamic>); _loading = false; });
    } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); }
  }
  Future<void> _settle(Map<String, dynamic> d) async { if (!await confirmDialog(context, title: 'Create settlement', message: 'Create a settlement of ${Fmt.inr(d['pendingAmount'] as num?)} for ${d['fullName']} (${d['trips']} trips)?', confirmLabel: 'Create')) return; try { await api.post('/payments/settlements', body: {'driverId': d['driverId']}); if (mounted) toast(context, 'Settlement created'); _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }
  Future<void> _pay(Map<String, dynamic> s) async { final ref0 = await reasonDialog(context, title: 'Mark ${s['code']} as paid', label: 'Payment reference (UTR)', confirmLabel: 'Mark Paid'); if (ref0 == null) return; try { await api.post('/payments/settlements/${s['id']}/pay', body: {'reference': ref0}); if (mounted) toast(context, 'Settlement paid'); _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }
  Future<void> _invoice() async {
    String? clientId = _clients.isEmpty ? null : _clients.first['id'] as String; DateTimeRange range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month - 1, 1), end: DateTime(DateTime.now().year, DateTime.now().month, 0));
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => FormDialog(title: 'Generate Client Invoice', width: 460, saveLabel: 'Generate', onSave: () => Navigator.pop(ctx, true), child: Column(children: [DropdownButtonFormField<String>(initialValue: clientId, decoration: const InputDecoration(labelText: 'Client'), items: [for (final c in _clients) DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))], onChanged: (v) => setS(() => clientId = v)), const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: DateRangeButton(range: range, onChanged: (r) => setS(() => range = r ?? range)))]))));
    if (ok != true || clientId == null) return;
    try { await api.post('/payments/invoices', body: {'clientId': clientId, 'periodStart': Fmt.iso(range.start), 'periodEnd': Fmt.iso(range.end)}); if (mounted) toast(context, 'Invoice generated'); _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }
  Future<void> _invoiceStatus(Map<String, dynamic> i, String s) async { try { await api.patch('/payments/invoices/${i['id']}', body: {'status': s}); _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }

  @override
  Widget build(BuildContext context) {
    return PageBody(children: [
      PageHeader(title: 'Payments & Settlement', breadcrumb: 'Payments & Settlement', subtitle: 'Driver earnings, settlement batches and client invoices.', actions: [OutlineButton(label: 'Generate Invoice', icon: Icons.receipt_long_outlined, onPressed: _invoice), GoldButton(label: 'Refresh', icon: Icons.refresh, onPressed: _load)]),
      const SizedBox(height: 14),
      StatGrid(cards: [
        StatCard(label: 'Pending Driver Payouts', value: Fmt.inr(_stats['pendingEarnings'] as num?), icon: Icons.account_balance_wallet, iconColor: GamyaColors.warning, trend: '${_stats['pendingEarningsCount'] ?? 0} trips unsettled', trendColor: GamyaColors.warning, trendIcon: Icons.schedule),
        StatCard(label: 'Settled Payouts', value: Fmt.inr(_stats['settledEarnings'] as num?), icon: Icons.check_circle, iconColor: GamyaColors.success, trend: '${_stats['paidSettlementsCount'] ?? 0} settlements paid', trendPositive: true),
        StatCard(label: 'Settlements Pending', value: Fmt.inr(_stats['pendingSettlements'] as num?), icon: Icons.pending_actions, trend: '${_stats['pendingSettlementsCount'] ?? 0} batches', trendColor: GamyaColors.info, trendIcon: Icons.layers),
        StatCard(label: 'Earnings This Month', value: Fmt.inr(_stats['monthEarnings'] as num?), icon: Icons.currency_rupee, trend: 'Driver earnings', trendPositive: true),
        StatCard(label: 'Invoices Due', value: Fmt.inr(_stats['invoicesDue'] as num?), icon: Icons.receipt_long, iconColor: GamyaColors.danger, trend: '${_stats['invoicesDueCount'] ?? 0} invoices', trendPositive: false),
        StatCard(label: 'Invoices Paid', value: Fmt.inr(_stats['invoicesPaid'] as num?), icon: Icons.paid, iconColor: GamyaColors.success, trend: '${_stats['invoicesPaidCount'] ?? 0} invoices', trendPositive: true),
      ]),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerLeft, child: PillTabs(tabs: const ['Driver Settlement', 'Earnings Ledger', 'Settlements', 'Client Invoices'], selected: _tab, onChanged: (i) => setState(() => _tab = i))),
      const SizedBox(height: 12),
      if (_loading) const Card(child: LoadingState()) else if (_error != null) Card(child: ErrorState(message: _error!, onRetry: _load)) else Card(child: Padding(padding: const EdgeInsets.all(12), child: [
        GTable<Map<String, dynamic>>(minWidth: 700, columns: const [GColumn('Driver', width: 200), GColumn('Mobile', width: 110), GColumn('Trips', width: 70, numeric: true), GColumn('Pending Amount', width: 120, numeric: true), GColumn('Actions', flex: 1)], rows: _summary, emptyText: 'All driver earnings are settled', cells: (d, i) => [PersonCell(name: d['fullName'] as String? ?? '', avatarUrl: d['avatarUrl'] as String?, subtitle: d['code'] as String?), CellText(d['mobile'] as String?), CellText('${d['trips']}'), CellText(Fmt.inr(d['pendingAmount'] as num?), bold: true, color: GamyaColors.success), Row(children: [GoldButton(label: 'Create Settlement', dense: true, onPressed: () => _settle(d)), const SizedBox(width: 6), OutlineButton(label: 'View Driver', dense: true, onPressed: () => context.go('/drivers?id=${d['driverId']}'))])]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [GTable<Map<String, dynamic>>(minWidth: 800, columns: const [GColumn('Date', width: 110), GColumn('Driver', width: 160), GColumn('Trip', width: 120), GColumn('Route', flex: 2), GColumn('Platform', width: 110), GColumn('Amount', width: 90, numeric: true), GColumn('Status', width: 90), GColumn('Settlement', width: 140)], rows: _earnings.items, cells: (e, i) => [CellText(Fmt.date(e['date'])), CellText((e['driver'] as Map)['fullName'] as String?), CellText((e['trip'] as Map?)?['code'] as String?), (e['trip'] == null) ? const CellText('—') : RouteText((e['trip'] as Map)['fromLocation'] as String, (e['trip'] as Map)['toLocation'] as String), CellText((e['trip'] as Map?)?['platform'] as String?), CellText(Fmt.inr(e['amount'] as num?), bold: true), StatusChip(e['status'] as String?, small: true), CellText(e['settlementCode'] as String?, muted: true)]), const SizedBox(height: 10), PaginationBar(paged: _earnings, noun: 'earnings', onPage: (p) { _qe.page = p; _load(); })]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [GTable<Map<String, dynamic>>(minWidth: 800, columns: const [GColumn('Settlement', width: 150), GColumn('Driver', width: 170), GColumn('Period', width: 190), GColumn('Trips', width: 60, numeric: true), GColumn('Amount', width: 100, numeric: true), GColumn('Status', width: 90), GColumn('Reference', width: 130), GColumn('Actions', width: 120)], rows: _settlements.items, emptyText: 'No settlements yet', cells: (s, i) => [CellText(s['code'] as String?, bold: true), CellText((s['driver'] as Map)['fullName'] as String?), CellText('${Fmt.date(s['periodStart'])} – ${Fmt.date(s['periodEnd'])}'), CellText('${s['trips']}'), CellText(Fmt.inr(s['totalAmount'] as num?), bold: true), StatusChip(s['status'] as String?, small: true), CellText(s['reference'] as String? ?? (s['paidAt'] != null ? Fmt.date(s['paidAt']) : null), muted: true), s['status'] == 'PAID' ? const SizedBox() : GoldButton(label: 'Mark Paid', dense: true, onPressed: () => _pay(s))]), const SizedBox(height: 10), PaginationBar(paged: _settlements, noun: 'settlements', onPage: (p) { _qs.page = p; _load(); })]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [GTable<Map<String, dynamic>>(minWidth: 800, columns: const [GColumn('Invoice', width: 150), GColumn('Client', width: 150), GColumn('Period', width: 190), GColumn('Trips', width: 60, numeric: true), GColumn('Amount', width: 110, numeric: true), GColumn('Due Date', width: 100), GColumn('Status', width: 90), GColumn('Actions', width: 200)], rows: _invoices.items, emptyText: 'No invoices yet', cells: (v, i) => [CellText(v['code'] as String?, bold: true), CellText(v['clientName'] as String?), CellText('${Fmt.date(v['periodStart'])} – ${Fmt.date(v['periodEnd'])}'), CellText('${v['tripCount']}'), CellText(Fmt.inr(v['amount'] as num?), bold: true), CellText(Fmt.date(v['dueDate'])), StatusChip(v['status'] as String?, small: true), Row(children: [if (v['status'] == 'DRAFT') OutlineButton(label: 'Mark Sent', dense: true, onPressed: () => _invoiceStatus(v, 'SENT')), if (v['status'] != 'PAID') ...[const SizedBox(width: 6), GoldButton(label: 'Mark Paid', dense: true, onPressed: () => _invoiceStatus(v, 'PAID'))]])]), const SizedBox(height: 10), PaginationBar(paged: _invoices, noun: 'invoices', onPage: (p) { _qi.page = p; _load(); })]),
      ][_tab])),
    ]);
  }
}
