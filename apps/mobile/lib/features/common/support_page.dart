import 'package:flutter/material.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/mobile_widgets.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(title: 'Help & Support', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Center(child: GamyaLogo(size: 70, onDark: false, showTagline: true)), const SizedBox(height: 20),
    MenuTile(icon: Icons.call_outlined, label: 'Call Support', subtitle: GamyaBrand.supportPhone, onTap: () => launchUrl(Uri.parse('tel:${GamyaBrand.supportPhone.replaceAll(' ', '')}'))),
    MenuTile(icon: Icons.chat_outlined, label: 'WhatsApp Support', subtitle: 'Chat with our operations desk', onTap: () => launchUrl(Uri.parse('https://wa.me/${GamyaBrand.supportPhone.replaceAll(RegExp(r'[^0-9]'), '')}'), mode: LaunchMode.externalApplication)),
    MenuTile(icon: Icons.mail_outline, label: 'Email Support', subtitle: GamyaBrand.supportEmail, onTap: () => launchUrl(Uri.parse('mailto:${GamyaBrand.supportEmail}'))),
    const SizedBox(height: 10),
    const InfoCard(title: 'Frequently Asked Questions', children: [
      _Faq('How do I accept a trip?', 'Open Available Trips or the notification, review the details and tap Accept. The trip must then be performed in the selected tracking platform (Routematic, MoveInSync, etc.).'),
      _Faq('When do I get paid?', 'Completed trip amounts are added to your earnings immediately and settled by Gamya Mobility in weekly batches.'),
      _Faq('My documents are expiring', 'Upload the renewed document from Documents. It will be verified by the admin team.'),
      _Faq('How do I post a requirement?', 'Supervisors tap Post Your Requirement, choose the vehicle, timings, locations and tracking platform, then confirm the booking.'),
    ]),
    const SizedBox(height: 8), const Center(child: Text('${GamyaBrand.company}\n${GamyaBrand.reliable}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: GamyaColors.textMuted))),
  ]));
}

class _Faq extends StatelessWidget {
  const _Faq(this.q, this.a);
  final String q; final String a;
  @override
  Widget build(BuildContext context) => ExpansionTile(tilePadding: EdgeInsets.zero, childrenPadding: const EdgeInsets.only(bottom: 10), title: Text(q, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)), children: [Text(a, style: const TextStyle(fontSize: 12.5, color: GamyaColors.textSecondary, height: 1.4))]);
}
