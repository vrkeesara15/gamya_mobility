import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/list_helpers.dart';

class VehicleFormDialog extends ConsumerStatefulWidget {
  const VehicleFormDialog({super.key, this.existing, required this.platforms});
  final Vehicle? existing; final List<PlatformInfo> platforms;
  @override
  ConsumerState<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends ConsumerState<VehicleFormDialog> {
  final _form = GlobalKey<FormState>();
  Vehicle? get e => widget.existing;
  late final _number = TextEditingController(text: e?.number); late final _make = TextEditingController(text: e?.make); late final _model = TextEditingController(text: e?.model); late final _year = TextEditingController(text: '${e?.year ?? DateTime.now().year}');
  late final _color = TextEditingController(text: e?.color); late final _seats = TextEditingController(text: e?.seatingCapacity); late final _location = TextEditingController(text: e?.currentLocation);
  late String _type = e?.type ?? 'SEDAN'; late String _fuel = e?.fuelType ?? 'PETROL'; late String _status = e?.status ?? 'ACTIVE'; late String? _platformId = e?.platform?.id;
  late String? _driverId = e?.driver?['id'] as String?; late String _driverName = e?.driver?['fullName'] as String? ?? '';
  late final Map<String, TextEditingController> _dates = {for (final k in ['registrationDate', 'permitValidTill', 'insuranceValidTill', 'pucValidTill', 'fitnessValidTill']) k: TextEditingController(text: e?.raw[k] == null ? '' : Fmt.iso(Fmt.parse(e!.raw[k])!))};
  bool _busy = false;

  Future<void> _pickDriver() async {
    final api = ref.read(apiProvider);
    final d = await pickFromList(context, title: 'Select Driver', fetch: (q) async => (api.data(await api.get('/drivers', query: {'q': q, 'pageSize': 30, 'status': 'ACTIVE'}))['items'] as List).cast<Map<String, dynamic>>(), tile: (d) => Row(children: [GamyaAvatar(url: d['avatarUrl'] as String?, name: d['fullName'] as String?, size: 32), const SizedBox(width: 10), Expanded(child: Text('${d['fullName']}  ·  ${d['mobile']}')), Text(d['code'] as String? ?? '', style: const TextStyle(color: GamyaColors.textMuted))]));
    if (d != null) setState(() { _driverId = d['id'] as String; _driverName = d['fullName'] as String; });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{'number': _number.text.trim(), 'make': _make.text.trim(), 'model': _model.text.trim(), 'year': int.tryParse(_year.text) ?? DateTime.now().year, 'type': _type, 'color': _color.text.trim(), 'fuelType': _fuel, 'seatingCapacity': _seats.text.trim(), 'status': _status, 'platformId': _platformId, 'driverId': _driverId, 'currentLocation': _location.text.trim(), for (final d in _dates.entries) if (d.value.text.isNotEmpty) d.key: d.value.text};
      final api = ref.read(apiProvider);
      if (e == null) { await api.post('/vehicles', body: body); } else { await api.put('/vehicles/${e!.id}', body: body); }
      if (mounted) { toast(context, e == null ? 'Vehicle added' : 'Vehicle updated'); Navigator.pop(context, true); }
    } catch (err) { if (mounted) toast(context, err.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }

  Widget _date(String key, String label) => TextFormField(controller: _dates[key], readOnly: true, decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16)), onTap: () async { final p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2040)); if (p != null) setState(() => _dates[key]!.text = Fmt.iso(p)); });

  @override
  Widget build(BuildContext context) => FormDialog(
    title: e == null ? 'Add Vehicle' : 'Edit Vehicle ${e!.number}', onSave: _save, busy: _busy, width: 640,
    child: Form(key: _form, child: Column(children: [
      FieldRow([TextFormField(controller: _number, decoration: const InputDecoration(labelText: 'Vehicle Number *'), textCapitalization: TextCapitalization.characters, validator: (v) => v!.trim().length < 4 ? 'Required' : null), DropdownButtonFormField<String>(initialValue: _type, decoration: const InputDecoration(labelText: 'Vehicle Type'), items: [for (final t in vehicleTypeItems) DropdownMenuItem(value: t.$1, child: Text(t.$2))], onChanged: (v) => setState(() => _type = v ?? 'SEDAN'))]),
      const SizedBox(height: 12),
      FieldRow([TextFormField(controller: _make, decoration: const InputDecoration(labelText: 'Make *'), validator: (v) => v!.trim().isEmpty ? 'Required' : null), TextFormField(controller: _model, decoration: const InputDecoration(labelText: 'Model *'), validator: (v) => v!.trim().isEmpty ? 'Required' : null), TextFormField(controller: _year, decoration: const InputDecoration(labelText: 'Model Year *'), keyboardType: TextInputType.number, validator: (v) => int.tryParse(v!) == null ? 'Year' : null)]),
      const SizedBox(height: 12),
      FieldRow([TextFormField(controller: _color, decoration: const InputDecoration(labelText: 'Colour')), DropdownButtonFormField<String>(initialValue: _fuel, decoration: const InputDecoration(labelText: 'Fuel Type'), items: const [DropdownMenuItem(value: 'PETROL', child: Text('Petrol')), DropdownMenuItem(value: 'DIESEL', child: Text('Diesel')), DropdownMenuItem(value: 'CNG', child: Text('CNG')), DropdownMenuItem(value: 'ELECTRIC', child: Text('Electric')), DropdownMenuItem(value: 'HYBRID', child: Text('Hybrid'))], onChanged: (v) => setState(() => _fuel = v ?? 'PETROL')), TextFormField(controller: _seats, decoration: const InputDecoration(labelText: 'Seating (e.g. 4 + 1)'))]),
      const SizedBox(height: 12),
      FieldRow([
        DropdownButtonFormField<String?>(initialValue: _platformId, decoration: const InputDecoration(labelText: 'Platform'), items: [const DropdownMenuItem(value: null, child: Text('None')), for (final p in widget.platforms) DropdownMenuItem(value: p.id, child: Text(p.name))], onChanged: (v) => setState(() => _platformId = v)),
        DropdownButtonFormField<String>(initialValue: _status, decoration: const InputDecoration(labelText: 'Status'), items: const [DropdownMenuItem(value: 'ACTIVE', child: Text('Active')), DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')), DropdownMenuItem(value: 'UNDER_REVIEW', child: Text('Under Review'))], onChanged: (v) => setState(() => _status = v ?? 'ACTIVE')),
        InkWell(onTap: _pickDriver, child: InputDecorator(decoration: const InputDecoration(labelText: 'Assigned Driver', suffixIcon: Icon(Icons.search, size: 18)), child: Text(_driverName.isEmpty ? 'Select driver' : _driverName, style: TextStyle(color: _driverName.isEmpty ? GamyaColors.textMuted : GamyaColors.textPrimary)))),
      ]),
      const SizedBox(height: 12),
      FieldRow([_date('registrationDate', 'Registration Date'), _date('permitValidTill', 'Permit Valid Till'), _date('insuranceValidTill', 'Insurance Valid Till')]),
      const SizedBox(height: 12),
      FieldRow([_date('pucValidTill', 'PUC Valid Till'), _date('fitnessValidTill', 'Fitness Valid Till'), TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Current Location'))]),
    ])),
  );
}
