import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

/// Driver Registration / Supervisor Registration (fields differ by role).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(); final _company = TextEditingController(); final _emp = TextEditingController(); final _mobile = TextEditingController(); final _email = TextEditingController(); final _pw = TextEditingController(); final _dob = TextEditingController(); final _address = TextEditingController();
  bool _terms = true; bool _busy = false; bool _hide = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_terms) { toast(context, 'Please accept the Terms & Conditions', error: true); return; }
    setState(() => _busy = true);
    final role = ref.read(roleProvider);
    try {
      final api = ref.read(apiProvider);
      final body = role == 'DRIVER'
          ? {'fullName': _name.text.trim(), 'mobile': _mobile.text.trim(), 'email': _email.text.trim(), 'password': _pw.text, 'dateOfBirth': _dob.text, 'address': _address.text.trim(), 'acceptTerms': true}
          : {'fullName': _name.text.trim(), 'companyName': _company.text.trim(), 'employeeId': _emp.text.trim(), 'mobile': _mobile.text.trim(), 'email': _email.text.trim(), 'password': _pw.text, 'acceptTerms': true};
      final r = await api.post(role == 'DRIVER' ? '/auth/register/driver' : '/auth/register/supervisor', body: body);
      final d = api.data(r);
      await ref.read(sessionProvider.notifier).login(d['token'] as String, AuthUser.fromJson(d['user'] as Map<String, dynamic>));
      if (mounted) context.go('/face');
    } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(roleProvider) == 'DRIVER';
    return AuthScaffold(headerHeight: 170, child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [IconButton(onPressed: () => context.go('/welcome'), icon: const Icon(Icons.arrow_back), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32))]),
      Center(child: Text(driver ? 'Driver Registration' : 'Supervisor Registration', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
      Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(driver ? 'Join Gamya Mobility and be a part of a reliable transport network' : 'Create your account to raise ad-hoc transport requirements', textAlign: TextAlign.center, style: const TextStyle(color: GamyaColors.textSecondary, fontSize: 12.5)))),
      const SizedBox(height: 18),
      TextFormField(controller: _name, decoration: const InputDecoration(hintText: 'Full Name', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v!.trim().length < 2 ? 'Enter your full name' : null), const SizedBox(height: 12),
      if (!driver) ...[TextFormField(controller: _company, decoration: const InputDecoration(hintText: 'Company Name', prefixIcon: Icon(Icons.business_outlined)), validator: (v) => v!.trim().isEmpty ? 'Enter company name' : null), const SizedBox(height: 12), TextFormField(controller: _emp, decoration: const InputDecoration(hintText: 'Employee ID', prefixIcon: Icon(Icons.badge_outlined)), validator: (v) => v!.trim().isEmpty ? 'Enter employee ID' : null), const SizedBox(height: 12)],
      TextFormField(controller: _mobile, keyboardType: TextInputType.phone, maxLength: 10, decoration: const InputDecoration(hintText: 'Mobile Number', prefixIcon: Icon(Icons.phone_android_outlined), counterText: ''), validator: (v) => !RegExp(r'^[6-9]\d{9}$').hasMatch(v!.trim()) ? 'Enter a valid 10 digit mobile number' : null), const SizedBox(height: 12),
      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email ID', prefixIcon: Icon(Icons.mail_outline)), validator: (v) => !v!.contains('@') ? 'Enter a valid email' : null), const SizedBox(height: 12),
      if (driver) ...[TextFormField(controller: _dob, readOnly: true, decoration: const InputDecoration(hintText: 'Date of Birth', prefixIcon: Icon(Icons.calendar_today_outlined)), onTap: () async { final p = await showDatePicker(context: context, initialDate: DateTime(1995), firstDate: DateTime(1950), lastDate: DateTime.now().subtract(const Duration(days: 365 * 18))); if (p != null) _dob.text = Fmt.iso(p); }), const SizedBox(height: 12), TextFormField(controller: _address, decoration: const InputDecoration(hintText: 'Address', prefixIcon: Icon(Icons.location_on_outlined))), const SizedBox(height: 12)],
      TextFormField(controller: _pw, obscureText: _hide, decoration: InputDecoration(hintText: 'Create Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide))), validator: (v) => v!.length < 6 ? 'Minimum 6 characters' : null), const SizedBox(height: 6),
      CheckboxListTile(value: _terms, onChanged: (v) => setState(() => _terms = v ?? false), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, dense: true, title: RichText(text: const TextSpan(style: TextStyle(fontSize: 12.5, color: GamyaColors.textPrimary), children: [TextSpan(text: 'I agree to the '), TextSpan(text: 'Terms & Conditions', style: TextStyle(color: GamyaColors.info, fontWeight: FontWeight.w600))]))),
      const SizedBox(height: 6),
      GoldButton(label: 'Sign Up', expand: true, loading: _busy, onPressed: _submit), const SizedBox(height: 14),
      Center(child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [const Text('Already have an account? ', style: TextStyle(fontSize: 12.5, color: GamyaColors.textSecondary)), InkWell(onTap: () => context.go('/login'), child: const Text('Login', style: TextStyle(fontSize: 12.5, color: GamyaColors.goldDark, fontWeight: FontWeight.w700)))])),
    ])));
  }
}
