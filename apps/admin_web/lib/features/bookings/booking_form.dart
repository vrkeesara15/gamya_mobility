import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/list_helpers.dart';

class BookingFormDialog extends ConsumerStatefulWidget {
  const BookingFormDialog({super.key, this.existing, required this.clients, required this.locations});
  final Booking? existing; final List<Map<String, dynamic>> clients; final List<Map<String, dynamic>> locations;
  @override
  ConsumerState<BookingFormDialog> createState() => _BookingFormDialogState();
}

class _BookingFormDialogState extends ConsumerState<BookingFormDialog> {
  final _form = GlobalKey<FormState>();
  Booking? get e => widget.existing;
  late final _emp = TextEditingController(text: e?.employeeName); late final _mobile = TextEditingController(text: e?.employeeMobile); late final _email = TextEditingController(text: e?.employeeEmail);
  late String? _clientId = e?.clientId; late final _from = TextEditingController(text: e?.fromLocation); late final _to = TextEditingController(text: e?.toLocation);
  late DateTime _date = Fmt.parse(e?.date) ?? DateTime.now().add(const Duration(hours: 3)); late int _pax = e?.passengers ?? 1; late String _type = e?.vehicleType ?? 'SEDAN'; late String _tripType = e?.tripType ?? 'REGULAR'; late String _status = e?.status ?? 'PENDING';
  late final _amount = TextEditingController(text: e?.estimatedAmount?.toString() ?? ''); late final _notes = TextEditingController(text: e?.notes);
  late String? _vehicleId = e?.vehicle?['id'] as String?; late String _vehicleLabel = e?.vehicle == null ? '' : '${e!.vehicle!['number']} · ${(e!.driver?['fullName']) ?? ''}';
  bool _busy = false;

  Future<void> _pickVehicle() async {
    final api = ref.read(apiProvider);
    final v = await pickFromList(context, title: 'Select Vehicle', fetch: (q) async => (api.data(await api.get('/vehicles', query: {'q': q, 'pageSize': 40, 'status': 'ACTIVE'}))['items'] as List).cast<Map<String, dynamic>>(), tile: (v) => Row(children: [NetImage(v['photoUrl'] as String?, width: 56, height: 36, placeholderIcon: Icons.directions_car), const SizedBox(width: 10), Expanded(child: Text('${v['number']}  ·  ${v['makeModel']}  ·  ${(v['driver'] as Map?)?['fullName'] ?? 'No driver'}'))]));
    if (v != null) setState(() { _vehicleId = v['id'] as String; _vehicleLabel = '${v['number']} · ${(v['driver'] as Map?)?['fullName'] ?? 'No driver'}'; });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final body = {'date': _date.toUtc().toIso8601String(), 'employeeName': _emp.text.trim(), 'employeeMobile': _mobile.text.trim(), if (_email.text.trim().isNotEmpty) 'employeeEmail': _email.text.trim(), 'clientId': _clientId, 'tripType': _tripType, 'fromLocation': _from.text.trim(), 'toLocation': _to.text.trim(), 'passengers': _pax, 'vehicleType': _type, 'status': _status, 'notes': _notes.text.trim(), if (_amount.text.isNotEmpty) 'estimatedAmount': num.tryParse(_amount.text), if (_vehicleId != null) 'vehicleId': _vehicleId};
      final api = ref.read(apiProvider);
      if (e == null) { await api.post('/bookings', body: body); } else { await api.put('/bookings/${e!.id}', body: body); }
      if (mounted) { toast(context, e == null ? 'Booking created' : 'Booking updated'); Navigator.pop(context, true); }
    } catch (err) { if (mounted) toast(context, err.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => FormDialog(
    title: e == null ? 'New Booking' : 'Edit ${e!.code}', onSave: _save, busy: _busy, width: 660,
    child: Form(key: _form, child: Column(children: [
      FieldRow([TextFormField(controller: _emp, decoration: const InputDecoration(labelText: 'Employee Name *'), validator: (v) => v!.trim().isEmpty ? 'Required' : null), TextFormField(controller: _mobile, decoration: const InputDecoration(labelText: 'Employee Mobile')), TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Employee Email'))]),
      const SizedBox(height: 12),
      FieldRow([DropdownButtonFormField<String?>(initialValue: _clientId, decoration: const InputDecoration(labelText: 'Client'), items: [const DropdownMenuItem(value: null, child: Text('— Select client —')), for (final c in widget.clients) DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))], onChanged: (v) => setState(() => _clientId = v)), DropdownButtonFormField<String>(initialValue: _tripType, decoration: const InputDecoration(labelText: 'Trip Type'), items: const [DropdownMenuItem(value: 'REGULAR', child: Text('Regular')), DropdownMenuItem(value: 'ADHOC', child: Text('Ad-hoc'))], onChanged: (v) => setState(() => _tripType = v ?? 'REGULAR'))]),
      const SizedBox(height: 12),
      FieldRow([_loc(_from, 'From *'), _loc(_to, 'To *')]),
      const SizedBox(height: 12),
      FieldRow([
        InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365))); if (d == null || !context.mounted) return; final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date)); if (t != null) setState(() => _date = DateTime(d.year, d.month, d.day, t.hour, t.minute)); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'Date & Time *', suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)), child: Text(Fmt.dateTime(_date)))),
        DropdownButtonFormField<String>(initialValue: _type, decoration: const InputDecoration(labelText: 'Vehicle Type'), items: [for (final t in vehicleTypeItems) DropdownMenuItem(value: t.$1, child: Text(t.$2))], onChanged: (v) => setState(() => _type = v ?? 'SEDAN')),
        InputDecorator(decoration: const InputDecoration(labelText: 'Passengers'), child: Row(children: [IconButton(onPressed: _pax > 1 ? () => setState(() => _pax--) : null, icon: const Icon(Icons.remove, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 20)), Text('$_pax', style: const TextStyle(fontWeight: FontWeight.w700)), IconButton(onPressed: () => setState(() => _pax++), icon: const Icon(Icons.add, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 20))])),
      ]),
      const SizedBox(height: 12),
      FieldRow([
        InkWell(onTap: _pickVehicle, child: InputDecorator(decoration: const InputDecoration(labelText: 'Vehicle / Driver', suffixIcon: Icon(Icons.search, size: 18)), child: Text(_vehicleLabel.isEmpty ? 'Select vehicle' : _vehicleLabel, style: TextStyle(color: _vehicleLabel.isEmpty ? GamyaColors.textMuted : GamyaColors.textPrimary)))),
        DropdownButtonFormField<String>(initialValue: _status, decoration: const InputDecoration(labelText: 'Status'), items: const [DropdownMenuItem(value: 'PENDING', child: Text('Pending')), DropdownMenuItem(value: 'CONFIRMED', child: Text('Confirmed')), DropdownMenuItem(value: 'RESCHEDULED', child: Text('Rescheduled'))], onChanged: (v) => setState(() => _status = v ?? 'PENDING')),
        TextFormField(controller: _amount, decoration: const InputDecoration(labelText: 'Estimated Amount (₹)'), keyboardType: TextInputType.number),
      ]),
      const SizedBox(height: 12),
      TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
    ])),
  );

  Widget _loc(TextEditingController c, String label) => Autocomplete<String>(initialValue: TextEditingValue(text: c.text), optionsBuilder: (v) => widget.locations.map((l) => l['name'] as String).where((n) => n.toLowerCase().contains(v.text.toLowerCase())), onSelected: (v) => c.text = v, fieldViewBuilder: (ctx, tc, fn, _) { tc.addListener(() => c.text = tc.text); return TextFormField(controller: tc, focusNode: fn, decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.location_on_outlined, size: 18)), validator: (v) => v!.trim().isEmpty ? 'Required' : null); });
}
