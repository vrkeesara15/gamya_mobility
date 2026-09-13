import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _id = TextEditingController(); final _code = TextEditingController(); final _pw = TextEditingController(); bool _sent = false; bool _busy = false; String? _devToken;
  Future<void> _send() async { setState(() => _busy = true); try { final r = await ref.read(apiProvider).post('/auth/forgot-password', body: {'identifier': _id.text.trim()}); _devToken = r['devToken'] as String?; if (mounted) setState(() => _sent = true); } catch (e) { if (mounted) toast(context, e.msg, error: true); } if (mounted) setState(() => _busy = false); }
  Future<void> _reset() async { setState(() => _busy = true); try { await ref.read(apiProvider).post('/auth/reset-password', body: {'token': _code.text.trim(), 'newPassword': _pw.text}); if (mounted) { toast(context, 'Password updated. Please login.'); context.go('/login'); } } catch (e) { if (mounted) toast(context, e.msg, error: true); } if (mounted) setState(() => _busy = false); }
  @override
  Widget build(BuildContext context) => AuthScaffold(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [IconButton(onPressed: () => context.go('/login'), icon: const Icon(Icons.arrow_back), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32))]),
    const Text('Forgot Password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 4),
    Text(_sent ? 'Enter the reset code and your new password.' : 'We will send a reset code to your registered mobile / email.', style: const TextStyle(color: GamyaColors.textSecondary)), const SizedBox(height: 20),
    if (!_sent) ...[TextField(controller: _id, decoration: const InputDecoration(hintText: 'Mobile Number / Email ID', prefixIcon: Icon(Icons.person_outline))), const SizedBox(height: 16), GoldButton(label: 'Send Reset Code', expand: true, loading: _busy, onPressed: _send)]
    else ...[if (_devToken != null) NoteBox('Development mode – your reset code is $_devToken', icon: Icons.developer_mode), const SizedBox(height: 12), TextField(controller: _code, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Reset code', prefixIcon: Icon(Icons.pin_outlined))), const SizedBox(height: 12), TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(hintText: 'New password', prefixIcon: Icon(Icons.lock_outline))), const SizedBox(height: 16), GoldButton(label: 'Reset Password', expand: true, loading: _busy, onPressed: _reset)],
  ]));
}
