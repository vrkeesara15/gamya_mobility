import 'package:flutter/material.dart';
import 'package:gamya_core/gamya_core.dart';

/// Screen with dark top area (logo) and a white rounded content sheet – used for auth screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.headerHeight = 190, this.showTagline = true, this.scroll = true});
  final Widget child; final double headerHeight; final bool showTagline; final bool scroll;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GamyaColors.black,
    body: Column(children: [
      GamyaHeroHeader(height: headerHeight, showTagline: showTagline),
      Expanded(child: Container(
        width: double.infinity, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: scroll ? SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 28), child: child) : Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 20), child: child),
      )),
    ]),
  );
}

/// Standard inner page: dark app bar with back button and title.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.title, required this.child, this.actions, this.bottom, this.padding = const EdgeInsets.all(16), this.scroll = true, this.onBack, this.backgroundColor});
  final String title; final Widget child; final List<Widget>? actions; final Widget? bottom; final EdgeInsets padding; final bool scroll; final VoidCallback? onBack; final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: backgroundColor ?? GamyaColors.surface,
    appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), leading: onBack == null && !Navigator.canPop(context) ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack ?? () => Navigator.maybePop(context)), actions: actions),
    body: SafeArea(child: scroll ? SingleChildScrollView(padding: padding, child: child) : Padding(padding: padding, child: child)),
    bottomNavigationBar: bottom == null ? null : SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: bottom)),
  );
}

/// Dashboard header: hamburger/menu, logo, bell; then greeting row.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.name, required this.subtitle, this.avatarUrl, this.avatarName, this.unread = 0, this.onBell, this.onMenu, this.onAvatar, this.trailing});
  final String name; final String? avatarName; final String subtitle; final String? avatarUrl; final int unread; final VoidCallback? onBell; final VoidCallback? onMenu; final VoidCallback? onAvatar; final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [GamyaColors.black, GamyaColors.dark], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
    child: SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 18), child: Column(children: [
      Row(children: [
        IconButton(onPressed: onMenu, icon: const Icon(Icons.menu, color: Colors.white)),
        const Spacer(), const GamyaLogo(size: 44), const Spacer(),
        Stack(clipBehavior: Clip.none, children: [IconButton(onPressed: onBell, icon: const Icon(Icons.notifications_outlined, color: Colors.white)), if (unread > 0) Positioned(right: 6, top: 6, child: CountBadge(unread))]),
      ]),
      const SizedBox(height: 6),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)), Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12.5))])),
        if (trailing != null) trailing!,
        const SizedBox(width: 8),
        InkWell(onTap: onAvatar, child: GamyaAvatar(url: avatarUrl, name: avatarName ?? name, size: 46, borderColor: GamyaColors.gold)),
      ])),
    ]))),
  );
}

/// Big square action tile ("Post Your Requirement").
class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.icon, required this.label, required this.onTap, this.badge});
  final IconData icon; final String label; final VoidCallback onTap; final int? badge;
  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: Container(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: GamyaColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))]),
    child: Column(children: [Stack(clipBehavior: Clip.none, children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: GamyaColors.goldPale, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: GamyaColors.goldDark, size: 26)), if ((badge ?? 0) > 0) Positioned(right: -6, top: -6, child: CountBadge(badge!))]), const SizedBox(height: 10), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))]),
  ));
}

/// Menu row with icon, label, optional badge, chevron.
class MenuTile extends StatelessWidget {
  const MenuTile({super.key, required this.icon, required this.label, required this.onTap, this.badge, this.subtitle});
  final IconData icon; final String label; final VoidCallback onTap; final int? badge; final String? subtitle;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.border)),
    child: ListTile(onTap: onTap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: GamyaColors.goldPale, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: GamyaColors.goldDark, size: 20)), title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(fontSize: 12)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [if ((badge ?? 0) > 0) CountBadge(badge!), const SizedBox(width: 6), const Icon(Icons.chevron_right, color: GamyaColors.textMuted)])),
  );
}

/// Promo banner at the bottom of dashboards ("Drive Safe / Earn Better / Grow Together").
class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key, required this.lines, this.footer});
  final List<String> lines; final String? footer;
  @override
  Widget build(BuildContext context) => Container(
    height: 120, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: [GamyaColors.black, Color(0xFF2C2410)], begin: Alignment.centerLeft, end: Alignment.centerRight)),
    child: Stack(children: [
      Positioned(right: -10, bottom: -20, child: Icon(Icons.airport_shuttle, size: 120, color: GamyaColors.gold.withValues(alpha: 0.25))),
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < lines.length; i++) Text(lines[i], style: TextStyle(color: i == 0 ? GamyaColors.goldLight : Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.25)), if (footer != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(footer!, style: const TextStyle(color: Colors.white70, fontSize: 12)))])),
    ]),
  );
}

/// Info card with key/value rows used on summary/detail screens.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, this.title, required this.children, this.padding = const EdgeInsets.all(14)});
  final String? title; final List<Widget> children; final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: padding, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (title != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))), ...children]),
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.icon, this.valueWidget, this.bold = false});
  final String label; final String? value; final IconData? icon; final Widget? valueWidget; final bool bold;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (icon != null) ...[Icon(icon, size: 16, color: GamyaColors.textMuted), const SizedBox(width: 8)],
    SizedBox(width: 118, child: Text(label, style: const TextStyle(fontSize: 13, color: GamyaColors.textSecondary))),
    Expanded(child: valueWidget ?? Text(value == null || value!.isEmpty ? '—' : value!, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600))),
  ]));
}

/// Green check success header.
class SuccessHeader extends StatelessWidget {
  const SuccessHeader({super.key, required this.title, this.subtitle, this.icon = Icons.check, this.color = GamyaColors.success});
  final String title; final String? subtitle; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(width: 84, height: 84, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))]), child: Icon(icon, color: Colors.white, size: 44)),
    const SizedBox(height: 16),
    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: GamyaColors.textSecondary))),
  ]);
}

/// Yellow / gold info note box.
class NoteBox extends StatelessWidget {
  const NoteBox(this.text, {super.key, this.icon = Icons.info_outline, this.color = GamyaColors.warning});
  final String text; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.35)))]));
}

/// App drawer shared by both roles.
class GamyaDrawer extends StatelessWidget {
  const GamyaDrawer({super.key, required this.name, required this.subtitle, this.avatarUrl, required this.items, required this.onLogout});
  final String name; final String subtitle; final String? avatarUrl; final List<(IconData, String, VoidCallback)> items; final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Drawer(backgroundColor: GamyaColors.dark, child: SafeArea(child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 14), child: Row(children: [GamyaAvatar(url: avatarUrl, name: name, size: 52, borderColor: GamyaColors.gold), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)), Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12))]))])),
    const Divider(color: GamyaColors.darkBorder),
    Expanded(child: ListView(children: [for (final it in items) ListTile(leading: Icon(it.$1, color: GamyaColors.goldLight, size: 20), title: Text(it.$2, style: const TextStyle(color: Colors.white, fontSize: 14)), onTap: () { Navigator.pop(context); it.$3(); })])),
    const Divider(color: GamyaColors.darkBorder),
    ListTile(leading: const Icon(Icons.logout, color: GamyaColors.danger, size: 20), title: const Text('Logout', style: TextStyle(color: Colors.white, fontSize: 14)), onTap: onLogout),
    const Padding(padding: EdgeInsets.all(12), child: Text('${GamyaBrand.company}\n${GamyaBrand.tagline}', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11))),
  ])));
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? GamyaColors.danger : GamyaColors.dark));
}

Future<bool> confirm(BuildContext context, {required String title, required String message, String confirmLabel = 'Confirm', bool danger = false}) async {
  final r = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: GamyaColors.textSecondary))), FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: danger ? GamyaColors.danger : GamyaColors.gold), child: Text(confirmLabel))]));
  return r ?? false;
}
