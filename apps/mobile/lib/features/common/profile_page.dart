import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Map<String, dynamic>? _p; bool _loading = true;
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final u = ref.read(sessionProvider)!; try { final r = await api.get(u.isDriver ? '/driver/profile' : '/supervisor/profile'); if (mounted) setState(() { _p = api.data(r); _loading = false; }); } catch (e) { if (mounted) { setState(() => _loading = false); toast(context, e.msg, error: true); } } }
  Future<void> _edit() async {
    final u = ref.read(sessionProvider)!; final p = _p ?? {};
    final name = TextEditingController(text: p['fullName'] as String?); final email = TextEditingController(text: p['email'] as String?); final address = TextEditingController(text: p['address'] as String?); final emp = TextEditingController(text: p['employeeId'] as String?);
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (ctx) => Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Edit Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 14), TextField(controller: name, decoration: const InputDecoration(labelText: 'Full Name')), const SizedBox(height: 10), TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')), const SizedBox(height: 10), if (u.isDriver) TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')) else TextField(controller: emp, decoration: const InputDecoration(labelText: 'Employee ID')), const SizedBox(height: 16), GoldButton(label: 'Save', expand: true, onPressed: () => Navigator.pop(ctx, true))])));
    if (ok != true) return;
    try { await api.put(u.isDriver ? '/driver/profile' : '/supervisor/profile', body: {'fullName': name.text.trim(), 'email': email.text.trim(), if (u.isDriver) 'address': address.text.trim() else 'employeeId': emp.text.trim()}); await refreshSession(ref); _load(); if (mounted) toast(context, 'Profile updated'); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }
  Future<void> _changePassword() async {
    final cur = TextEditingController(); final nw = TextEditingController();
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (ctx) => Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Change Password', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 14), TextField(controller: cur, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')), const SizedBox(height: 10), TextField(controller: nw, obscureText: true, decoration: const InputDecoration(labelText: 'New password')), const SizedBox(height: 16), GoldButton(label: 'Update', expand: true, onPressed: () => Navigator.pop(ctx, true))])));
    if (ok != true) return;
    try { await api.post('/auth/change-password', body: {'currentPassword': cur.text, 'newPassword': nw.text}); if (mounted) toast(context, 'Password changed'); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
  }
  @override
  Widget build(BuildContext context) {
    final u = ref.watch(sessionProvider)!; final p = _p ?? {};
    return PageScaffold(title: 'My Profile', child: _loading ? const LoadingState() : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Column(children: [GamyaAvatar(url: p['avatarUrl'] as String?, name: u.fullName, size: 92, borderColor: GamyaColors.gold), const SizedBox(height: 10), Text(p['fullName'] as String? ?? u.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(u.isDriver ? 'Driver ID : ${p['code'] ?? ''}' : '${p['designation'] ?? 'Supervisor'} - ${p['companyName'] ?? ''}', style: const TextStyle(color: GamyaColors.textSecondary, fontSize: 12.5)), const SizedBox(height: 6), StatusChip(p['status'] as String? ?? u.status, small: true)])),
      const SizedBox(height: 18),
      InfoCard(title: 'Personal Information', children: [InfoRow('Mobile', p['mobile'] as String?, icon: Icons.phone_android_outlined), InfoRow('Email', p['email'] as String?, icon: Icons.mail_outline), if (u.isDriver) ...[InfoRow('Date of Birth', Fmt.date(p['dateOfBirth']), icon: Icons.cake_outlined), InfoRow('Address', p['address'] as String?, icon: Icons.location_on_outlined), InfoRow('Joined', Fmt.date(p['joiningDate']), icon: Icons.calendar_today_outlined), InfoRow('Rating', '${p['rating'] ?? '—'} ★', icon: Icons.star_outline)] else ...[InfoRow('Company', p['companyName'] as String?, icon: Icons.business_outlined), InfoRow('Employee ID', p['employeeId'] as String?, icon: Icons.badge_outlined), InfoRow('Locations', ((p['locations'] as List?) ?? []).join(', '), icon: Icons.location_on_outlined), InfoRow('Total Requests', '${p['totalRequests'] ?? 0}', icon: Icons.list_alt)], InfoRow('Face Verified', p['faceVerified'] == true ? 'Yes' : 'No', icon: Icons.face)]),
      if (u.isDriver && (p['vehicles'] as List?)?.isNotEmpty == true) InfoCard(title: 'Vehicle', children: [for (final v in (p['vehicles'] as List).cast<Map<String, dynamic>>()) ...[InfoRow('Vehicle Number', v['number'] as String?, icon: Icons.directions_car_outlined), InfoRow('Make & Model', '${v['make']} ${v['model']} (${v['year']})', icon: Icons.info_outline), InfoRow('Type', Fmt.vehicleType(v['type'] as String?), icon: Icons.category_outlined), InfoRow('Status', null, icon: Icons.verified_outlined, valueWidget: Align(alignment: Alignment.centerRight, child: StatusChip(v['status'] as String?, small: true)))]]),
      if (u.isDriver) InfoCard(title: 'Platforms', children: [Wrap(spacing: 6, runSpacing: 6, children: [for (final pl in ((p['platforms'] as List?) ?? []).cast<Map<String, dynamic>>()) PlatformChip(name: pl['name'] as String, color: pl['color'] as String?), if (((p['platforms'] as List?) ?? []).isEmpty) const Text('No platform access yet', style: TextStyle(fontSize: 12.5, color: GamyaColors.textMuted))])]),
      GoldButton(label: 'Edit Profile', icon: Icons.edit_outlined, expand: true, onPressed: _edit), const SizedBox(height: 8),
      OutlineButton(label: 'Change Password', icon: Icons.lock_outline, expand: true, onPressed: _changePassword), const SizedBox(height: 8),
      OutlineButton(label: 'Logout', icon: Icons.logout, color: GamyaColors.danger, expand: true, onPressed: () async { if (await confirm(context, title: 'Logout', message: 'Are you sure you want to logout?', confirmLabel: 'Logout', danger: true)) { try { await api.post('/auth/logout'); } catch (_) {} await ref.read(sessionProvider.notifier).logout(); if (context.mounted) context.go('/welcome'); } }),
    ]));
  }
}
