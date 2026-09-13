import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _id = TextEditingController(); final _pw = TextEditingController(); bool _hide = true; bool _busy = false;
  Future<void> _login() async {
    if (_id.text.trim().isEmpty || _pw.text.isEmpty) { toast(context, 'Enter mobile/email and password', error: true); return; }
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      final r = await api.post('/auth/login', body: {'identifier': _id.text.trim(), 'password': _pw.text, 'role': ref.read(roleProvider)});
      final d = api.data(r);
      await ref.read(sessionProvider.notifier).login(d['token'] as String, AuthUser.fromJson(d['user'] as Map<String, dynamic>));
    } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) {
    final role = ref.watch(roleProvider);
    return AuthScaffold(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [IconButton(onPressed: () => context.go('/welcome'), icon: const Icon(Icons.arrow_back), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32)), const SizedBox(width: 4), Chip(label: Text(role == 'DRIVER' ? 'Driver' : 'Supervisor'), backgroundColor: GamyaColors.goldPale, labelStyle: const TextStyle(color: GamyaColors.goldDark, fontWeight: FontWeight.w700, fontSize: 12))]),
      const SizedBox(height: 8),
      const Center(child: Text('Welcome Back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      const Center(child: Text('Login to continue', style: TextStyle(color: GamyaColors.textSecondary))), const SizedBox(height: 22),
      TextField(controller: _id, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Mobile Number / Email ID', prefixIcon: Icon(Icons.phone_android_outlined))), const SizedBox(height: 12),
      TextField(controller: _pw, obscureText: _hide, onSubmitted: (_) => _login(), decoration: InputDecoration(hintText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide)))),
      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.go('/forgot'), child: const Text('Forgot Password?', style: TextStyle(color: GamyaColors.textPrimary, fontSize: 12.5)))),
      GoldButton(label: 'Login', expand: true, loading: _busy, onPressed: _login), const SizedBox(height: 16),
      const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('OR', style: TextStyle(color: GamyaColors.textMuted, fontSize: 12))), Expanded(child: Divider())]), const SizedBox(height: 16),
      OutlineButton(label: 'Login with Face ID', icon: Icons.face_retouching_natural, expand: true, onPressed: () => toast(context, 'Face ID login uses the device biometric prompt after your first password login.')), const SizedBox(height: 22),
      Center(child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [const Text("Don't have an account? ", style: TextStyle(fontSize: 12.5, color: GamyaColors.textSecondary)), InkWell(onTap: () => context.go('/register'), child: const Text('Sign Up', style: TextStyle(fontSize: 12.5, color: GamyaColors.goldDark, fontWeight: FontWeight.w700)))])),
    ]));
  }
}
