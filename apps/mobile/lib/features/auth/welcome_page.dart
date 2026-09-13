import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';

/// Role selection: Driver or Supervisor.
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    Widget card(String r, IconData icon, String title, String sub) => InkWell(borderRadius: BorderRadius.circular(14), onTap: () => ref.read(roleProvider.notifier).state = r, child: Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: role == r ? GamyaColors.goldPale : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: role == r ? GamyaColors.gold : GamyaColors.border, width: role == r ? 1.6 : 1)),
      child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: GamyaColors.dark, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: GamyaColors.goldLight)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), Text(sub, style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))])), Icon(role == r ? Icons.radio_button_checked : Icons.radio_button_off, color: role == r ? GamyaColors.gold : GamyaColors.textMuted)]),
    ));
    return Scaffold(backgroundColor: GamyaColors.black, body: Column(children: [
      const Expanded(child: Center(child: GamyaLogo(size: 110, showTagline: true))),
      Container(width: double.infinity, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))), padding: const EdgeInsets.fromLTRB(20, 24, 20, 28), child: SafeArea(top: false, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        const Text('Welcome to Gamya Mobility', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 4),
        const Text('Choose how you want to continue', style: TextStyle(color: GamyaColors.textSecondary, fontSize: 13)), const SizedBox(height: 16),
        card('DRIVER', Icons.local_taxi, 'I am a Driver', 'Drive · Earn · Grow with Gamya'), const SizedBox(height: 10),
        card('SUPERVISOR', Icons.business_center, 'I am a Supervisor', 'Raise ad-hoc transport requirements'), const SizedBox(height: 20),
        GoldButton(label: 'Login', expand: true, onPressed: () => context.go('/login')), const SizedBox(height: 10),
        OutlineButton(label: role == 'DRIVER' ? 'Register as Driver' : 'Register as Supervisor', expand: true, onPressed: () => context.go('/register')),
        const SizedBox(height: 14),
        const Center(child: Text('${GamyaBrand.company} · ${GamyaBrand.tagline}', style: TextStyle(fontSize: 11, color: GamyaColors.textMuted))),
      ]))),
    ]));
  }
}
