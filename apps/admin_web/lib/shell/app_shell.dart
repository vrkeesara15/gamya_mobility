import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../app.dart';
import '../core/providers.dart';
import 'global_search.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location; final Widget child;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _collapsed = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() { super.initState(); _loadBadges(); }

  Future<void> _loadBadges() async {
    try {
      final api = ref.read(apiProvider);
      final a = await api.get('/approvals/stats'); final n = await api.get('/notifications/unread-count');
      if (mounted) ref.read(badgesProvider.notifier).state = Badges(pendingApprovals: (api.data(a)['total'] as num?)?.toInt() ?? 0, unread: (api.data(n)['count'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant AppShell old) { super.didUpdateWidget(old); if (old.location != widget.location) _loadBadges(); }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1100;
    final sidebar = _Sidebar(location: widget.location, collapsed: !compact && _collapsed, onNavigate: (p) { if (compact) _scaffoldKey.currentState?.closeDrawer(); context.go(p); });
    return Scaffold(
      key: _scaffoldKey,
      drawer: compact ? Drawer(width: 250, child: sidebar) : null,
      body: Row(children: [
        if (!compact) sidebar,
        Expanded(child: Column(children: [
          _TopBar(onMenu: () { if (compact) { _scaffoldKey.currentState?.openDrawer(); } else { setState(() => _collapsed = !_collapsed); } }, compact: compact),
          Expanded(child: widget.child),
          const _Footer(),
        ])),
      ]),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.location, required this.collapsed, required this.onNavigate});
  final String location; final bool collapsed; final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgesProvider);
    final w = collapsed ? 68.0 : 236.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180), width: w, color: GamyaColors.dark,
      child: Column(children: [
        Padding(padding: EdgeInsets.symmetric(vertical: collapsed ? 12 : 16), child: collapsed ? const GamyaMark(size: 40) : const GamyaLogo(size: 60)),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 8), children: [
          for (final n in navItems) _navTile(n, location == n.path || (n.path != '/dashboard' && location.startsWith(n.path)), badges, collapsed),
        ])),
        if (!collapsed) _promo(),
      ]),
    );
  }

  Widget _navTile(NavItem n, bool active, Badges b, bool collapsed) {
    final tile = InkWell(
      borderRadius: BorderRadius.circular(8), onTap: () => onNavigate(n.path),
      child: Container(
        margin: const EdgeInsets.only(bottom: 3), padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12, vertical: 10),
        decoration: BoxDecoration(color: active ? GamyaColors.gold : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
          Icon(n.icon, size: 19, color: active ? Colors.white : GamyaColors.goldLight),
          if (!collapsed) ...[const SizedBox(width: 12), Expanded(child: Text(n.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.white : Colors.white.withValues(alpha: 0.86), fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400))), if (n.badge && b.pendingApprovals > 0) CountBadge(b.pendingApprovals)],
        ]),
      ),
    );
    return collapsed ? Tooltip(message: n.label, child: tile) : tile;
  }

  Widget _promo() => Container(
    height: 220, width: double.infinity,
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [GamyaColors.dark, Color(0xFF2A2210), Color(0xFF3A2F14)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
    child: Stack(children: [
      Positioned(right: -30, bottom: -30, child: Icon(Icons.airport_shuttle, size: 140, color: GamyaColors.gold.withValues(alpha: 0.18))),
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
        const Text('Moving\nPeople\nForward', style: TextStyle(color: GamyaColors.goldLight, fontSize: 20, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, height: 1.15)),
        const SizedBox(height: 16),
        Text(GamyaBrand.company, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
        const Text(GamyaBrand.tagline, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ])),
    ]),
  );
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.onMenu, required this.compact});
  final VoidCallback onMenu; final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    final badges = ref.watch(badgesProvider);
    return Container(
      height: 62, color: GamyaColors.dark, padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        IconButton(onPressed: onMenu, icon: const Icon(Icons.menu, color: Colors.white)),
        const SizedBox(width: 6),
        if (!compact) Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: const [Text(GamyaBrand.company, style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3)), Text(GamyaBrand.tagline, style: TextStyle(color: Colors.white70, fontSize: 11))]),
        const Spacer(),
        if (MediaQuery.sizeOf(context).width > 760) ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: const GlobalSearchField()),
        const SizedBox(width: 10),
        Stack(clipBehavior: Clip.none, children: [
          IconButton(onPressed: () => context.go('/notifications'), icon: const Icon(Icons.notifications_outlined, color: Colors.white), tooltip: 'Notifications'),
          if (badges.unread > 0) Positioned(right: 4, top: 4, child: CountBadge(badges.unread)),
        ]),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          tooltip: 'Account', offset: const Offset(0, 46),
          onSelected: (v) { if (v == 'logout') ref.read(sessionProvider.notifier).logout(); if (v == 'settings') context.go('/settings'); if (v == 'profile') context.go('/admin-users'); },
          itemBuilder: (_) => const [PopupMenuItem(value: 'profile', child: Text('My Profile')), PopupMenuItem(value: 'settings', child: Text('Settings')), PopupMenuDivider(), PopupMenuItem(value: 'logout', child: Text('Logout'))],
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            GamyaAvatar(url: user?.avatarUrl, name: user?.fullName, size: 36, borderColor: GamyaColors.gold),
            if (!compact) ...[const SizedBox(width: 10), Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user?.fullName ?? 'Admin', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)), Text(user?.adminRoleLabel ?? 'Admin', style: const TextStyle(color: Colors.white70, fontSize: 11))]), const Icon(Icons.keyboard_arrow_down, color: Colors.white70)],
          ]),
        ),
        if (MediaQuery.sizeOf(context).width > 1350) ...[
          const SizedBox(width: 18),
          ClipPath(clipper: _SlantClipper(), child: Container(height: 62, padding: const EdgeInsets.fromLTRB(34, 0, 18, 0), color: GamyaColors.goldDark.withValues(alpha: 0.9), alignment: Alignment.center, child: const Text('Safe Rides\nBetter Tomorrow', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)))),
        ],
      ]),
    );
  }
}

class _SlantClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()..moveTo(22, 0)..lineTo(s.width, 0)..lineTo(s.width, s.height)..lineTo(0, s.height)..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => Container(
    height: 40, color: GamyaColors.cream, padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: [
      const Text('${GamyaBrand.company}   |   ${GamyaBrand.tagline}', style: TextStyle(fontSize: 12, color: GamyaColors.textSecondary)),
      const Spacer(),
      if (MediaQuery.sizeOf(context).width > 900) const Text('${GamyaBrand.reliable}   ·   Admin Panel   ·   ${GamyaBrand.version}', style: TextStyle(fontSize: 12, color: GamyaColors.textSecondary)),
    ]),
  );
}
