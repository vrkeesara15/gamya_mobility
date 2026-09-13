import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import '../../core/providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false; bool _hide = true; String? _error;

  Future<void> _login() async {
    setState(() { _busy = true; _error = null; });
    try {
      final api = ref.read(apiProvider);
      final r = await api.post('/auth/login', body: {'identifier': _id.text.trim(), 'password': _pw.text, 'role': 'ADMIN'});
      final d = api.data(r);
      await ref.read(sessionProvider.notifier).login(d['token'] as String, AuthUser.fromJson(d['user'] as Map<String, dynamic>));
    } catch (e) {
      setState(() => _error = e.msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    final form = Padding(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!wide) ...[const Center(child: GamyaLogo(size: 72, onDark: false)), const SizedBox(height: 28)],
        const Text('Welcome Back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Sign in to the GAMYA MOBILITY PVT LTD admin panel', style: TextStyle(color: GamyaColors.textSecondary)),
        const SizedBox(height: 28),
        TextField(controller: _id, decoration: const InputDecoration(labelText: 'Email ID / Mobile Number', prefixIcon: Icon(Icons.person_outline)), onSubmitted: (_) => _login(), autofillHints: const [AutofillHints.username]),
        const SizedBox(height: 14),
        TextField(controller: _pw, obscureText: _hide, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide))), onSubmitted: (_) => _login(), autofillHints: const [AutofillHints.password]),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: GamyaColors.danger, fontSize: 13))),
        const SizedBox(height: 22),
        GoldButton(label: 'Login', onPressed: _login, loading: _busy, expand: true),
        const SizedBox(height: 18),
        const Center(child: Text('${GamyaBrand.company}  ·  ${GamyaBrand.tagline}', style: TextStyle(fontSize: 12, color: GamyaColors.textMuted))),
      ])),
    );
    if (!wide) return Scaffold(body: Center(child: SingleChildScrollView(child: form)));
    return Scaffold(body: Row(children: [
      Expanded(child: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [GamyaColors.black, Color(0xFF1C1C1C)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(children: [
          Positioned(right: -80, bottom: -80, child: Container(width: 380, height: 380, decoration: BoxDecoration(shape: BoxShape.circle, color: GamyaColors.gold.withValues(alpha: 0.08)))),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const GamyaLogo(size: 120, showTagline: true),
            const SizedBox(height: 40),
            const Text(GamyaBrand.movingPeople, style: TextStyle(color: GamyaColors.goldLight, fontSize: 30, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text(GamyaBrand.reliable, style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 32),
            Wrap(spacing: 22, children: [for (final p in GamyaBrand.pillars) Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.check_circle, color: GamyaColors.gold, size: 16), const SizedBox(width: 6), Text(p, style: const TextStyle(color: Colors.white, fontSize: 13))])]),
          ])),
        ]),
      )),
      SizedBox(width: 480, child: Center(child: SingleChildScrollView(child: form))),
    ]));
  }
}
