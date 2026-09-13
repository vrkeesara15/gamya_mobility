import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/providers.dart';
import '../../widgets/data_table.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/page_scaffold.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _tab = 0; Map<String, dynamic> _settings = {}; List<Map<String, dynamic>> _tariffs = []; List<Map<String, dynamic>> _locations = []; List<Map<String, dynamic>> _clients = []; bool _loading = true; String? _error;
  final Map<String, TextEditingController> _company = {}; final Map<String, TextEditingController> _docs = {}; final Map<String, bool> _notif = {};
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([api.get('/settings'), api.get('/settings/tariffs'), api.get('/locations', query: {'all': '1'}), api.get('/clients', query: {'all': '1'})]);
      _settings = api.data(r[0]); _tariffs = api.list(r[1]); _locations = api.list(r[2]); _clients = api.list(r[3]);
      final c = (_settings['company'] as Map?)?.cast<String, dynamic>() ?? {}; for (final k in ['name', 'tagline', 'email', 'phone', 'address', 'gstin']) { _company[k] = TextEditingController(text: c[k]?.toString() ?? ''); }
      final d = (_settings['documents'] as Map?)?.cast<String, dynamic>() ?? {}; for (final k in ['renewalReminderDays', 'reVerificationMonths']) { _docs[k] = TextEditingController(text: d[k]?.toString() ?? ''); }
      final nf = (_settings['notifications'] as Map?)?.cast<String, dynamic>() ?? {}; for (final k in ['pushEnabled', 'emailEnabled', 'smsEnabled']) { _notif[k] = nf[k] == true; }
      if (mounted) setState(() => _loading = false);
    } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); }
  }
  Future<void> _saveSetting(String key, Map<String, dynamic> value) async { try { await api.put('/settings/$key', body: {'value': value}); if (mounted) toast(context, 'Settings saved'); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }
  Future<void> _saveTariff(Map<String, dynamic> t) async {
    final base = TextEditingController(text: '${t['baseAmount']}'); final km = TextEditingController(text: '${t['perKm']}'); final hr = TextEditingController(text: '${t['perHour'] ?? ''}');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => FormDialog(title: 'Tariff – ${Fmt.vehicleType(t['vehicleType'] as String?)}', width: 460, onSave: () => Navigator.pop(ctx, true), child: FieldRow([TextField(controller: base, decoration: const InputDecoration(labelText: 'Base amount (₹)'), keyboardType: TextInputType.number), TextField(controller: km, decoration: const InputDecoration(labelText: 'Per km (₹)'), keyboardType: TextInputType.number), TextField(controller: hr, decoration: const InputDecoration(labelText: 'Per hour (₹)'), keyboardType: TextInputType.number)])));
    if (ok != true) return;
    try { await api.put('/settings/tariffs/${t['vehicleType']}', body: {'baseAmount': num.tryParse(base.text) ?? 0, 'perKm': num.tryParse(km.text) ?? 0, 'perHour': num.tryParse(hr.text)}); _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }
  Future<void> _editLocation([Map<String, dynamic>? l]) async {
    final name = TextEditingController(text: l?['name'] as String?); final city = TextEditingController(text: l?['city'] as String? ?? 'Hyderabad'); final area = TextEditingController(text: l?['area'] as String?);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => FormDialog(title: l == null ? 'Add Location' : 'Edit Location', width: 460, onSave: () => Navigator.pop(ctx, true), child: Column(children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Location name *')), const SizedBox(height: 12), FieldRow([TextField(controller: city, decoration: const InputDecoration(labelText: 'City')), TextField(controller: area, decoration: const InputDecoration(labelText: 'Area / Landmark'))])])));
    if (ok != true || name.text.trim().isEmpty) return;
    try { final body = {'name': name.text.trim(), 'city': city.text.trim(), 'area': area.text.trim()}; if (l == null) { await api.post('/locations', body: body); } else { await api.put('/locations/${l['id']}', body: body); } _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }
  Future<void> _editClient([Map<String, dynamic>? c]) async {
    final name = TextEditingController(text: c?['name'] as String?); final contact = TextEditingController(text: c?['contactName'] as String?); final mobile = TextEditingController(text: c?['contactMobile'] as String?); final email = TextEditingController(text: c?['email'] as String?); final address = TextEditingController(text: c?['address'] as String?);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => FormDialog(title: c == null ? 'Add Client' : 'Edit Client', width: 500, onSave: () => Navigator.pop(ctx, true), child: Column(children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Client / Company name *')), const SizedBox(height: 12), FieldRow([TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact person')), TextField(controller: mobile, decoration: const InputDecoration(labelText: 'Contact mobile'))]), const SizedBox(height: 12), FieldRow([TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')), TextField(controller: address, decoration: const InputDecoration(labelText: 'Address'))])])));
    if (ok != true || name.text.trim().isEmpty) return;
    try { final body = {'name': name.text.trim(), 'contactName': contact.text.trim(), 'contactMobile': mobile.text.trim(), if (email.text.trim().isNotEmpty) 'email': email.text.trim(), 'address': address.text.trim()}; if (c == null) { await api.post('/clients', body: body); } else { await api.put('/clients/${c['id']}', body: body); } _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
    const PageHeader(title: 'Settings', breadcrumb: 'Settings', subtitle: 'Company profile, tariffs, document rules, locations, clients and notification channels.'),
    const SizedBox(height: 14),
    Align(alignment: Alignment.centerLeft, child: PillTabs(tabs: const ['Company', 'Tariffs', 'Documents', 'Locations', 'Clients', 'Notifications'], selected: _tab, onChanged: (i) => setState(() => _tab = i))),
    const SizedBox(height: 12),
    if (_loading) const Card(child: LoadingState()) else if (_error != null) Card(child: ErrorState(message: _error!, onRetry: _load)) else [
      SectionCard(title: 'Company Profile', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FieldRow([TextField(controller: _company['name'], decoration: const InputDecoration(labelText: 'Company name')), TextField(controller: _company['tagline'], decoration: const InputDecoration(labelText: 'Tagline'))]), const SizedBox(height: 12),
        FieldRow([TextField(controller: _company['email'], decoration: const InputDecoration(labelText: 'Support email')), TextField(controller: _company['phone'], decoration: const InputDecoration(labelText: 'Support phone')), TextField(controller: _company['gstin'], decoration: const InputDecoration(labelText: 'GSTIN'))]), const SizedBox(height: 12),
        TextField(controller: _company['address'], decoration: const InputDecoration(labelText: 'Address')), const SizedBox(height: 14),
        GoldButton(label: 'Save Company Profile', onPressed: () => _saveSetting('company', {for (final e in _company.entries) e.key: e.value.text.trim(), 'currency': 'INR'})),
      ])),
      SectionCard(title: 'Tariffs (used for estimated amounts)', padding: const EdgeInsets.all(12), child: GTable<Map<String, dynamic>>(minWidth: 600, columns: const [GColumn('Vehicle Type', width: 160), GColumn('Base Amount', width: 120, numeric: true), GColumn('Per Km', width: 100, numeric: true), GColumn('Per Hour', width: 100, numeric: true), GColumn('Updated', width: 150), GColumn('Actions', flex: 1)], rows: _tariffs, cells: (t, i) => [CellText(Fmt.vehicleType(t['vehicleType'] as String?), bold: true), CellText(Fmt.inr(t['baseAmount'] as num?)), CellText(Fmt.inr(t['perKm'] as num?)), CellText(Fmt.inr(t['perHour'] as num?)), CellText(Fmt.date(t['updatedAt'])), OutlineButton(label: 'Edit', dense: true, icon: Icons.edit_outlined, onPressed: () => _saveTariff(t))])),
      SectionCard(title: 'Document Rules', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Required driver documents: RC, Permit, Insurance, Driving Licence, Vehicle Photo 1, Vehicle Photo 2, Face Verification (7).', style: TextStyle(fontSize: 12.5)), const SizedBox(height: 4), const Text('Required vehicle documents: RC, Permit, Insurance, PUC, Fitness, Vehicle Photo 1, Vehicle Photo 2 (7).', style: TextStyle(fontSize: 12.5)), const SizedBox(height: 14),
        FieldRow([TextField(controller: _docs['renewalReminderDays'], decoration: const InputDecoration(labelText: 'Renewal reminder (days before expiry)'), keyboardType: TextInputType.number), TextField(controller: _docs['reVerificationMonths'], decoration: const InputDecoration(labelText: 'Driver re-verification interval (months)'), keyboardType: TextInputType.number)]), const SizedBox(height: 14),
        GoldButton(label: 'Save Document Rules', onPressed: () => _saveSetting('documents', {...((_settings['documents'] as Map?)?.cast<String, dynamic>() ?? {}), 'renewalReminderDays': int.tryParse(_docs['renewalReminderDays']!.text) ?? 30, 'reVerificationMonths': int.tryParse(_docs['reVerificationMonths']!.text) ?? 12})),
      ])),
      SectionCard(title: 'Locations Master', trailing: GoldButton(label: 'Add Location', icon: Icons.add, dense: true, onPressed: () => _editLocation()), padding: const EdgeInsets.all(12), child: GTable<Map<String, dynamic>>(minWidth: 600, columns: const [GColumn('Name', width: 200), GColumn('City', width: 120), GColumn('Area', flex: 1), GColumn('Status', width: 90), GColumn('Actions', width: 120)], rows: _locations, cells: (l, i) => [CellText(l['name'] as String?, bold: true), CellText(l['city'] as String?), CellText(l['area'] as String?), StatusChip(l['active'] == false ? 'INACTIVE' : 'ACTIVE', small: true), RowActions(onEdit: () => _editLocation(l), extra: [const SizedBox(width: 4), TableIconButton(icon: l['active'] == false ? Icons.toggle_off : Icons.toggle_on, color: l['active'] == false ? GamyaColors.textMuted : GamyaColors.success, tooltip: 'Toggle', onPressed: () async { await api.put('/locations/${l['id']}', body: {'active': l['active'] == false}); _load(); })])])),
      SectionCard(title: 'Clients Master', trailing: GoldButton(label: 'Add Client', icon: Icons.add, dense: true, onPressed: () => _editClient()), padding: const EdgeInsets.all(12), child: GTable<Map<String, dynamic>>(minWidth: 800, columns: const [GColumn('Client', width: 160), GColumn('Contact', width: 140), GColumn('Mobile', width: 110), GColumn('Email', flex: 1), GColumn('Supervisors', width: 90, numeric: true), GColumn('Bookings', width: 80, numeric: true), GColumn('Status', width: 90), GColumn('Actions', width: 120)], rows: _clients, cells: (c, i) => [CellText(c['name'] as String?, bold: true), CellText(c['contactName'] as String?), CellText(c['contactMobile'] as String?), CellText(c['email'] as String?), CellText('${c['supervisors']}'), CellText('${c['bookings']}'), StatusChip(c['active'] == false ? 'INACTIVE' : 'ACTIVE', small: true), RowActions(onEdit: () => _editClient(c), extra: [const SizedBox(width: 4), TableIconButton(icon: c['active'] == false ? Icons.toggle_off : Icons.toggle_on, color: c['active'] == false ? GamyaColors.textMuted : GamyaColors.success, tooltip: 'Toggle', onPressed: () async { await api.put('/clients/${c['id']}', body: {'active': c['active'] == false}); _load(); })])])),
      SectionCard(title: 'Notification Channels', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in {'pushEnabled': 'Push notifications (Firebase Cloud Messaging)', 'emailEnabled': 'Email notifications', 'smsEnabled': 'SMS notifications'}.entries) SwitchListTile(contentPadding: EdgeInsets.zero, value: _notif[e.key] ?? false, onChanged: (v) => setState(() => _notif[e.key] = v), title: Text(e.value, style: const TextStyle(fontSize: 13.5))),
        const SizedBox(height: 8), const Text('Push delivery requires FCM_ENABLED and a Firebase service account on the backend. In-app notifications always work.', style: TextStyle(fontSize: 12, color: GamyaColors.textMuted)), const SizedBox(height: 12),
        GoldButton(label: 'Save Notification Settings', onPressed: () => _saveSetting('notifications', Map<String, dynamic>.from(_notif))),
      ])),
    ][_tab],
  ]);
}
