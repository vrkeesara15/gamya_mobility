import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

class ApprovedPage extends ConsumerWidget {
  const ApprovedPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(sessionProvider)!;
    return AuthScaffold(headerHeight: 150, showTagline: false, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 30),
      SuccessHeader(title: 'Congratulations!', subtitle: u.isDriver ? 'Your account has been approved.\n\nYou can now receive and accept ad-hoc trip requests.' : 'Your account has been approved.\n\nYou can now post transport requirements.'),
      const SizedBox(height: 36),
      GoldButton(label: 'Go to Dashboard', expand: true, onPressed: () => context.go(homeFor(u))),
      const SizedBox(height: 24),
      const Center(child: Text(GamyaBrand.tagline, style: TextStyle(color: GamyaColors.textMuted, fontSize: 12))),
    ]));
  }
}
