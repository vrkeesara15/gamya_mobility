import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/list_helpers.dart';

class AdhocFormDialog extends ConsumerStatefulWidget {
  const AdhocFormDialog({super.key, this.existing, required this.clients, required this.locations});
  final AdhocRequest? existing; final List<Map<String, dynamic>> clients; final List<Map<String, dynamic>> locations;
  @override
  ConsumerState<AdhocFormDialog> createState() => _AdhocFormDialogState();
}

class _AdhocFormDialogState extends ConsumerState<AdhocFormDialog> {
  final _form = GlobalKey<FormState>();
  AdhocRequest? get e => widget.existing;
  late String? _clientId = e?.raw['clientId'] as String?;
  late final _contact = TextEditingController(text: e?.contactName); late final _mobile = TextEditingController(text: e?.contactMobile);
  late final _from = TextEditingController(text: e?.fromLocation); late final _to = TextEditingController(text: e?.toLocation);
  late DateTime _date = Fmt.parse(e?.scheduledAt) ?? DateTime.now().add(const Duration(hours: 2));
  late final _login = TextEditingController(text: e?.loginTime ?? '09:00'); late final _reporting = TextEditingController(text: e?.reportingTime ?? '08:30');
  late int _pax = e?.passengers ?? 1; late int _vehicles = e?.numberOfVehicles ?? 1; late String _type = e?.vehicleType ?? 'SEDAN'; late int _year = e?.modelYearMin ?? 2022; late String _bookingType = e?.bookingType ?? 'INSTANT';
  late String? _platformId = e?.platform?.id; late final _other = TextEditingController(text: e?.raw['otherPlatformName'] as String?); late final _notes = TextEditingController(text: e?.specialInstructions); late final _amount = TextEditingController(text: e?.estimatedAmount?.toString() ?? '');
  List<PlatformInfo> _platforms = []; bool _busy = false;

  @override
  void initState() { super.initState(); _loadPlatforms(); if (e == null) _estimate(); }
  Future<void> _loadPlatforms() async { try { final api = ref.read(apiProvider); final r = await api.get('/platforms'); if (mounted) setState(() { _platforms = api.list(r).map(PlatformInfo.new).toList(); _platformId ??= _platforms.isEmpty ? null : _platforms.first.id; }); } catch (_) {} }
  Future<void> _estimate() async { try { final api = ref.read(apiProvider); final r = await api.post('/adhoc/estimate', body: {'vehicleType': _type, 'numberOfVehicles': _vehicles, 'passengers': _pax}); if (mounted) setState(() => _amount.text = '${api.data(r)['estimatedAmount']}'); } catch (_) {} }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final body = {'clientId': _clientId, 'contactName': _contact.text.trim(), 'contactMobile': _mobile.text.trim(), 'fromLocation': _from.text.trim(), 'toLocation': _to.text.trim(), 'scheduledAt': _date.toUtc().toIso8601String(), 'loginTime': _login.text.trim(), 'reportingTime': _reporting.text.trim(), 'passengers': _pax, 'vehicleType': _type, 'modelYearMin': _year, 'numberOfVehicles': _vehicles, 'bookingType': _bookingType, 'platformId': _platformId, 'otherPlatformName': _other.text.trim(), 'specialInstructions': _notes.text.trim(), if (_amount.text.isNotEmpty) 'estimatedAmount': num.tryParse(_amount.text)};
      final api = ref.read(apiProvider);
      if (e == null) { await api.post('/adhoc', body: body); } else { await api.put('/adhoc/${e!.id}', body: body); }
      if (mounted) { toast(context, e == null ? 'Request created' : 'Request updated'); Navigator.pop(context, true); }
    } catch (err) { if (mounted) toast(context, err.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickTime(TextEditingController c) async { final parts = c.text.split(':'); final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0)); if (t != null) setState(() => c.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'); }

  @override
  Widget build(BuildContext context) => FormDialog(
    title: e == null ? 'New Ad-hoc Request' : 'Edit ${e!.code}', onSave: _save, busy: _busy, width: 680,
    child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldRow([DropdownButtonFormField<String?>(initialValue: _clientId, decoration: const InputDecoration(labelText: 'Client'), items: [const DropdownMenuItem(value: null, child: Text('— Select client —')), for (final c in widget.clients) DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))], onChanged: (v) => setState(() => _clientId = v)), TextFormField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact Person')), TextFormField(controller: _mobile, decoration: const InputDecoration(labelText: 'Contact Mobile'))]),
      const SizedBox(height: 12),
      FieldRow([_locField(_from, 'Pickup Location *'), _locField(_to, 'Drop Location *')]),
      const SizedBox(height: 12),
      FieldRow([
        InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 180))); if (d == null || !context.mounted) return; final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date)); if (t != null) setState(() => _date = DateTime(d.year, d.month, d.day, t.hour, t.minute)); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'Date & Time *', suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)), child: Text(Fmt.dateTime(_date)))),
        TextFormField(controller: _login, readOnly: true, decoration: const InputDecoration(labelText: 'Login Time', suffixIcon: Icon(Icons.schedule, size: 16)), onTap: () => _pickTime(_login)),
        TextFormField(controller: _reporting, readOnly: true, decoration: const InputDecoration(labelText: 'Reporting Time', suffixIcon: Icon(Icons.schedule, size: 16)), onTap: () => _pickTime(_reporting)),
      ]),
      const SizedBox(height: 12),
      FieldRow([
        DropdownButtonFormField<String>(initialValue: _type, decoration: const InputDecoration(labelText: 'Vehicle Type *'), items: [for (final t in vehicleTypeItems) DropdownMenuItem(value: t.$1, child: Text(t.$2))], onChanged: (v) { setState(() => _type = v ?? 'SEDAN'); _estimate(); }),
        DropdownButtonFormField<int>(initialValue: _year, decoration: const InputDecoration(labelText: 'Model Year (min)'), items: [for (final y in [2018, 2019, 2020, 2021, 2022, 2023, 2024]) DropdownMenuItem(value: y, child: Text('$y & Above'))], onChanged: (v) => setState(() => _year = v ?? 2022)),
        InputDecorator(decoration: const InputDecoration(labelText: 'No. of Vehicles'), child: Row(children: [IconButton(onPressed: _vehicles > 1 ? () { setState(() => _vehicles--); _estimate(); } : null, icon: const Icon(Icons.remove, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 20)), Text('$_vehicles', style: const TextStyle(fontWeight: FontWeight.w700)), IconButton(onPressed: () { setState(() => _vehicles++); _estimate(); }, icon: const Icon(Icons.add, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 20))])),
        InputDecorator(decoration: const InputDecoration(labelText: 'Passengers'), child: Row(children: [IconButton(onPressed: _pax > 1 ? () => setState(() => _pax--) : null, icon: const Icon(Icons.remove, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 20)), Text('$_pax', style: const TextStyle(fontWeight: FontWeight.w700)), IconButton(onPressed: () => setState(() => _pax++), icon: const Icon(Icons.add, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 20))])),
      ]),
      const SizedBox(height: 12),
      FieldRow([
        DropdownButtonFormField<String>(initialValue: _bookingType, decoration: const InputDecoration(labelText: 'Booking Type'), items: const [DropdownMenuItem(value: 'INSTANT', child: Text('Instant Booking')), DropdownMenuItem(value: 'SCHEDULED', child: Text('Scheduled Booking'))], onChanged: (v) => setState(() => _bookingType = v ?? 'INSTANT')),
        DropdownButtonFormField<String?>(key: ValueKey(_platforms.length), initialValue: _platformId, decoration: const InputDecoration(labelText: 'Trip Tracking Platform'), items: [for (final p in _platforms) DropdownMenuItem(value: p.id, child: Row(children: [PlatformIcon(color: GamyaColors.fromHex(p.color), size: 16), const SizedBox(width: 8), Text(p.name)]))], onChanged: (v) => setState(() => _platformId = v)),
        TextFormField(controller: _amount, decoration: const InputDecoration(labelText: 'Estimated Amount (₹)'), keyboardType: TextInputType.number),
      ]),
      if (_platforms.any((p) => p.id == _platformId && p.code == 'OTHER')) Padding(padding: const EdgeInsets.only(top: 12), child: TextFormField(controller: _other, decoration: const InputDecoration(labelText: 'Other platform (please specify)'))),
      const SizedBox(height: 12),
      TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Special Instructions')),
    ])),
  );

  Widget _locField(TextEditingController c, String label) => Autocomplete<String>(
    initialValue: TextEditingValue(text: c.text),
    optionsBuilder: (v) => widget.locations.map((l) => l['name'] as String).where((n) => n.toLowerCase().contains(v.text.toLowerCase())),
    onSelected: (v) => c.text = v,
    fieldViewBuilder: (ctx, tc, fn, onSubmit) { tc.addListener(() => c.text = tc.text); return TextFormField(controller: tc, focusNode: fn, decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.location_on_outlined, size: 18)), validator: (v) => v!.trim().length < 2 ? 'Required' : null); },
  );
}
