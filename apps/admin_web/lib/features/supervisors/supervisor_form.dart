import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/providers.dart';
import '../../widgets/dialogs.dart';

class SupervisorFormDialog extends ConsumerStatefulWidget {
  const SupervisorFormDialog({super.key, this.existing, required this.locations});
  final Supervisor? existing; final List<Map<String, dynamic>> locations;
  @override
  ConsumerState<SupervisorFormDialog> createState() => _SupervisorFormDialogState();
}

class _SupervisorFormDialogState extends ConsumerState<SupervisorFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.fullName);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _mobile = TextEditingController(text: widget.existing?.mobile);
  late final _emp = TextEditingController(text: widget.existing?.employeeId);
  late final _company = TextEditingController(text: widget.existing?.companyName);
  late final _designation = TextEditingController(text: widget.existing?.designation ?? 'Supervisor');
  final _password = TextEditingController();
  late String _status = widget.existing?.status ?? 'ACTIVE';
  late final Set<String> _locs = widget.existing?.locations.map((l) => l['id'] as String).toSet() ?? {};
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final body = {'fullName': _name.text.trim(), 'email': _email.text.trim(), 'mobile': _mobile.text.trim(), 'employeeId': _emp.text.trim(), 'companyName': _company.text.trim(), 'designation': _designation.text.trim(), 'status': _status, 'locationIds': _locs.toList(), if (_password.text.isNotEmpty) 'password': _password.text};
      final api = ref.read(apiProvider);
      if (widget.existing == null) { await api.post('/supervisors', body: body); } else { await api.put('/supervisors/${widget.existing!.id}', body: body); }
      if (mounted) { toast(context, widget.existing == null ? 'Supervisor added' : 'Supervisor updated'); Navigator.pop(context, true); }
    } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => FormDialog(
    title: widget.existing == null ? 'Add Supervisor' : 'Edit Supervisor', onSave: _save, busy: _busy,
    child: Form(key: _form, child: Column(children: [
      FieldRow([TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name *'), validator: (v) => v!.trim().length < 2 ? 'Required' : null), TextFormField(controller: _company, decoration: const InputDecoration(labelText: 'Company / Client *'), validator: (v) => v!.trim().isEmpty ? 'Required' : null)]),
      const SizedBox(height: 12),
      FieldRow([TextFormField(controller: _emp, decoration: const InputDecoration(labelText: 'Employee ID')), TextFormField(controller: _designation, decoration: const InputDecoration(labelText: 'Designation'))]),
      const SizedBox(height: 12),
      FieldRow([TextFormField(controller: _mobile, decoration: const InputDecoration(labelText: 'Mobile Number *'), validator: (v) => v!.trim().length < 10 ? 'Enter 10 digit mobile' : null), TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email ID *'), validator: (v) => !v!.contains('@') ? 'Invalid email' : null)]),
      const SizedBox(height: 12),
      FieldRow([TextFormField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: widget.existing == null ? 'Password (default Gamya@123)' : 'New Password (leave blank to keep)')), DropdownButtonFormField<String>(initialValue: _status, decoration: const InputDecoration(labelText: 'Status'), items: const [DropdownMenuItem(value: 'ACTIVE', child: Text('Active')), DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')), DropdownMenuItem(value: 'PENDING', child: Text('Pending'))], onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'))]),
      const SizedBox(height: 16),
      Align(alignment: Alignment.centerLeft, child: Text('Assigned Locations', style: TextStyle(fontWeight: FontWeight.w600, color: GamyaColors.textPrimary.withValues(alpha: 0.9)))),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [for (final l in widget.locations) FilterChip(label: Text(l['name'] as String), selected: _locs.contains(l['id']), selectedColor: GamyaColors.goldPale, checkmarkColor: GamyaColors.gold, onSelected: (v) => setState(() => v ? _locs.add(l['id'] as String) : _locs.remove(l['id'])))]),
      if (widget.locations.isEmpty) const Text('No locations configured yet – add them in Settings.', style: TextStyle(color: GamyaColors.textMuted, fontSize: 12)),
    ])),
  );
}
