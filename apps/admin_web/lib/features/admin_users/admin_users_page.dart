import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/providers.dart';
import '../../widgets/data_table.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/page_scaffold.dart';

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});
  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  Paged<Map<String, dynamic>> _data = Paged.empty(); bool _loading = true; String? _error;
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() { _loading = true; _error = null; }); try { final d = await api.paged('/admin-users', (j) => j, query: {'pageSize': 50}); if (mounted) setState(() { _data = d; _loading = false; }); } catch (e) { if (mounted) setState(() { _error = e.msg; _loading = false; }); } }

  Future<void> _edit([Map<String, dynamic>? a]) async {
    final name = TextEditingController(text: a?['fullName'] as String?); final email = TextEditingController(text: a?['email'] as String?); final mobile = TextEditingController(text: a?['mobile'] as String?); final pw = TextEditingController(); final desig = TextEditingController(text: a?['designation'] as String?); String role = a?['adminRole'] as String? ?? 'ADMIN'; String status = a?['status'] as String? ?? 'ACTIVE';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => FormDialog(title: a == null ? 'Add Admin User' : 'Edit ${a['fullName']}', width: 520, onSave: () => Navigator.pop(ctx, true), child: Column(children: [
      FieldRow([TextField(controller: name, decoration: const InputDecoration(labelText: 'Full Name *')), TextField(controller: email, decoration: const InputDecoration(labelText: 'Email *'))]), const SizedBox(height: 12),
      FieldRow([TextField(controller: mobile, decoration: const InputDecoration(labelText: 'Mobile')), TextField(controller: pw, obscureText: true, decoration: InputDecoration(labelText: a == null ? 'Password (default Gamya@123)' : 'New Password (optional)'))]), const SizedBox(height: 12),
      FieldRow([DropdownButtonFormField<String>(initialValue: role, decoration: const InputDecoration(labelText: 'Role'), items: const [DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin')), DropdownMenuItem(value: 'ADMIN', child: Text('Admin')), DropdownMenuItem(value: 'OPS', child: Text('Operations'))], onChanged: (v) => setS(() => role = v ?? 'ADMIN')), TextField(controller: desig, decoration: const InputDecoration(labelText: 'Designation')), DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Status'), items: const [DropdownMenuItem(value: 'ACTIVE', child: Text('Active')), DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive'))], onChanged: (v) => setS(() => status = v ?? 'ACTIVE'))]),
    ]))));
    if (ok != true || name.text.trim().isEmpty) return;
    try { final body = {'fullName': name.text.trim(), 'email': email.text.trim(), 'mobile': mobile.text.trim().isEmpty ? null : mobile.text.trim(), 'adminRole': role, 'designation': desig.text.trim(), 'status': status, if (pw.text.isNotEmpty) 'password': pw.text}; if (a == null) { await api.post('/admin-users', body: body); } else { await api.put('/admin-users/${a['id']}', body: body); } if (mounted) toast(context, 'Admin user saved'); _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }
  Future<void> _delete(Map<String, dynamic> a) async { if (!await confirmDialog(context, title: 'Delete admin', message: 'Delete ${a['fullName']}? This cannot be undone.', confirmLabel: 'Delete', danger: true)) return; try { await api.delete('/admin-users/${a['id']}'); _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); } }
  Future<void> _changeMyPassword() async {
    final cur = TextEditingController(); final nw = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => FormDialog(title: 'Change My Password', width: 420, onSave: () => Navigator.pop(ctx, true), child: Column(children: [TextField(controller: cur, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')), const SizedBox(height: 12), TextField(controller: nw, obscureText: true, decoration: const InputDecoration(labelText: 'New password (min 6 chars)'))])));
    if (ok != true) return;
    try { await api.post('/auth/change-password', body: {'currentPassword': cur.text, 'newPassword': nw.text}); if (mounted) toast(context, 'Password changed'); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider); final isSuper = me?.adminRole == 'SUPER_ADMIN';
    return PageBody(children: [
      PageHeader(title: 'Admin Users', breadcrumb: 'Admin Users', subtitle: 'Manage admin panel users and their roles.', actions: [OutlineButton(label: 'Change My Password', icon: Icons.lock_outline, onPressed: _changeMyPassword), if (isSuper) GoldButton(label: 'Add Admin User', icon: Icons.add, onPressed: () => _edit())]),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: GTable<Map<String, dynamic>>(minWidth: 800, loading: _loading, error: _error, onRetry: _load, columns: const [GColumn('Name', width: 200), GColumn('Email', flex: 1), GColumn('Mobile', width: 110), GColumn('Role', width: 110), GColumn('Designation', width: 130), GColumn('Last Login', width: 150), GColumn('Status', width: 90), GColumn('Actions', width: 100)], rows: _data.items, rowId: (a) => a['id'] as String, cells: (a, i) => [PersonCell(name: a['fullName'] as String? ?? '', avatarUrl: a['avatarUrl'] as String?), CellText(a['email'] as String?), CellText(a['mobile'] as String?), CellText(a['adminRole'] == 'SUPER_ADMIN' ? 'Super Admin' : Fmt.title(a['adminRole'] as String?)), CellText(a['designation'] as String?), CellText(Fmt.dateTime(a['lastLoginAt'])), StatusChip(a['status'] as String?, small: true), isSuper ? RowActions(onEdit: () => _edit(a), extra: [const SizedBox(width: 4), if (a['userId'] != me?.id) TableIconButton(icon: Icons.delete_outline, color: GamyaColors.danger, tooltip: 'Delete', onPressed: () => _delete(a))]) : const SizedBox()]))),
      const SizedBox(height: 12),
      const Text('Roles: Super Admin – full access incl. admin users & settings · Admin – operations, approvals, bookings · Operations – day-to-day trip management.', style: TextStyle(fontSize: 12, color: GamyaColors.textMuted)),
    ]);
  }
}
