import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/list_helpers.dart';

class DriverFormDialog extends ConsumerStatefulWidget {
  const DriverFormDialog({super.key, this.existing, required this.platforms});
  final Driver? existing; final List<PlatformInfo> platforms;
  @override
  ConsumerState<DriverFormDialog> createState() => _DriverFormDialogState();
}

class _DriverFormDialogState extends ConsumerState<DriverFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.fullName);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _mobile = TextEditingController(text: widget.existing?.mobile);
  late final _address = TextEditingController(text: widget.existing?.address);
  late final _dob = TextEditingController(text: widget.existing?.dateOfBirth == null ? '' : Fmt.iso(Fmt.parse(widget.existing!.dateOfBirth)!));
  late final _licence = TextEditingController(text: widget.existing?.raw['licenceNumber'] as String?);
  final _password = TextEditingController();
  late String _status = widget.existing?.status ?? 'ACTIVE';
  late final Set<String> _plat = widget.existing?.platforms.map((p) => p.id).toSet() ?? {};
  // vehicle (only when creating)
  final _vNumber = TextEditingController(); final _vMake = TextEditingController(); final _vModel = TextEditingController(); final _vYear = TextEditingController(text: '${DateTime.now().year}'); String _vType = 'SEDAN';
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{'fullName': _name.text.trim(), if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(), 'mobile': _mobile.text.trim(), 'address': _address.text.trim(), if (_dob.text.isNotEmpty) 'dateOfBirth': _dob.text, 'licenceNumber': _licence.text.trim(), 'status': _status, 'platformIds': _plat.toList(), if (_password.text.isNotEmpty) 'password': _password.text};
      if (widget.existing == null && _vNumber.text.trim().isNotEmpty) body['vehicle'] = {'number': _vNumber.text.trim(), 'make': _vMake.text.trim(), 'model': _vModel.text.trim(), 'year': int.tryParse(_vYear.text) ?? DateTime.now().year, 'type': _vType};
      final api = ref.read(apiProvider);
      if (widget.existing == null) { await api.post('/drivers', body: body); } else { await api.put('/drivers/${widget.existing!.id}', body: body); }
      if (mounted) { toast(context, widget.existing == null ? 'Driver added' : 'Driver updated'); Navigator.pop(context, true); }
    } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => FormDialog(
    title: widget.existing == null ? 'Add Driver' : 'Edit Driver', onSave: _save, busy: _busy, width: 620,
    child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldRow([TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name *'), validator: (v) => v!.trim().length < 2 ? 'Required' : null), TextFormField(controller: _mobile, decoration: const InputDecoration(labelText: 'Mobile Number *'), validator: (v) => v!.trim().length < 10 ? 'Enter 10 digit mobile' : null)]),
      const SizedBox(height: 12),
      FieldRow([TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email ID')), TextFormField(controller: _dob, readOnly: true, decoration: const InputDecoration(labelText: 'Date of Birth', suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)), onTap: () async { final p = await showDatePicker(context: context, initialDate: DateTime(1990), firstDate: DateTime(1950), lastDate: DateTime.now()); if (p != null) _dob.text = Fmt.iso(p); })]),
      const SizedBox(height: 12),
      FieldRow([TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address')), TextFormField(controller: _licence, decoration: const InputDecoration(labelText: 'Driving Licence No.'))]),
      const SizedBox(height: 12),
      FieldRow([TextFormField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: widget.existing == null ? 'Password (default Gamya@123)' : 'New Password (optional)')), DropdownButtonFormField<String>(initialValue: _status, decoration: const InputDecoration(labelText: 'Status'), items: const [DropdownMenuItem(value: 'ACTIVE', child: Text('Active')), DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')), DropdownMenuItem(value: 'PENDING', child: Text('Pending'))], onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'))]),
      const SizedBox(height: 14),
      const Text('Platform Access', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [for (final p in widget.platforms) FilterChip(avatar: PlatformIcon(color: GamyaColors.fromHex(p.color), size: 16), label: Text(p.name), selected: _plat.contains(p.id), selectedColor: GamyaColors.goldPale, checkmarkColor: GamyaColors.gold, onSelected: (v) => setState(() => v ? _plat.add(p.id) : _plat.remove(p.id)))]),
      if (widget.existing == null) ...[
        const SizedBox(height: 16), const Text('Vehicle (optional)', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8),
        FieldRow([TextFormField(controller: _vNumber, decoration: const InputDecoration(labelText: 'Vehicle Number'), textCapitalization: TextCapitalization.characters), DropdownButtonFormField<String>(initialValue: _vType, decoration: const InputDecoration(labelText: 'Vehicle Type'), items: [for (final t in vehicleTypeItems) DropdownMenuItem(value: t.$1, child: Text(t.$2))], onChanged: (v) => setState(() => _vType = v ?? 'SEDAN'))]),
        const SizedBox(height: 12),
        FieldRow([TextFormField(controller: _vMake, decoration: const InputDecoration(labelText: 'Make')), TextFormField(controller: _vModel, decoration: const InputDecoration(labelText: 'Model')), TextFormField(controller: _vYear, decoration: const InputDecoration(labelText: 'Model Year'), keyboardType: TextInputType.number)]),
      ],
    ])),
  );
}
