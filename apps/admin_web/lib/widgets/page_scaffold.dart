import 'package:flutter/material.dart';
import 'package:gamya_core/gamya_core.dart';

/// Breadcrumb + title + subtitle + primary actions, matching the admin screenshots.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const [], this.breadcrumb});
  final String title; final String? subtitle; final List<Widget> actions; final String? breadcrumb;
  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 800;
    final titleCol = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.home_outlined, size: 14, color: GamyaColors.textMuted), const SizedBox(width: 4), const Text('Dashboard', style: TextStyle(fontSize: 12, color: GamyaColors.textMuted)), if (breadcrumb != null) ...[const Text('  ›  ', style: TextStyle(fontSize: 12, color: GamyaColors.textMuted)), Text(breadcrumb!, style: const TextStyle(fontSize: 12, color: GamyaColors.textSecondary))]]),
      const SizedBox(height: 4),
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: const TextStyle(fontSize: 13, color: GamyaColors.textSecondary))),
    ]);
    if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleCol, if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 8, runSpacing: 8, children: actions))]);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: titleCol), Wrap(spacing: 8, children: actions)]);
  }
}

/// Scrollable page body with consistent padding.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.controller});
  final List<Widget> children; final ScrollController? controller;
  @override
  Widget build(BuildContext context) => Scrollbar(controller: controller, child: SingleChildScrollView(controller: controller, padding: const EdgeInsets.fromLTRB(18, 14, 18, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)));
}

/// Responsive grid of stat cards.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.cards, this.minWidth = 190});
  final List<Widget> cards; final double minWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
    final cols = (c.maxWidth / minWidth).floor().clamp(1, cards.length);
    final w = (c.maxWidth - (cols - 1) * 12) / cols;
    return Wrap(spacing: 12, runSpacing: 12, children: [for (final card in cards) SizedBox(width: w, child: card)]);
  });
}

/// Two-column responsive layout: main content + right detail panel.
class MasterDetail extends StatelessWidget {
  const MasterDetail({super.key, required this.master, this.detail, this.detailWidth = 360});
  final Widget master; final Widget? detail; final double detailWidth;
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1250;
    if (detail == null) return master;
    if (!wide) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [detail!, const SizedBox(height: 12), master]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: master), const SizedBox(width: 12), SizedBox(width: detailWidth, child: detail)]);
  }
}

/// Responsive row of cards: wraps onto multiple lines when narrow.
class CardRow extends StatelessWidget {
  const CardRow({super.key, required this.children, this.minWidth = 320, this.flex});
  final List<Widget> children; final double minWidth; final List<int>? flex;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
    final fits = c.maxWidth >= minWidth * children.length + 12 * (children.length - 1);
    if (!fits) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < children.length; i++) Padding(padding: EdgeInsets.only(bottom: i == children.length - 1 ? 0 : 12), child: children[i])]);
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < children.length; i++) ...[Expanded(flex: flex?[i] ?? 1, child: children[i]), if (i < children.length - 1) const SizedBox(width: 12)]]));
  });
}

/// Filter bar container (search + dropdowns + Apply/Reset).
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.children, this.onApply, this.onReset, this.leading});
  final List<Widget> children; final VoidCallback? onApply; final VoidCallback? onReset; final Widget? leading;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(10), child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
    if (leading != null) leading!,
    ...children,
    if (onReset != null) OutlineButton(label: 'Reset', onPressed: onReset, dense: true),
    if (onApply != null) GoldButton(label: 'Apply', onPressed: onApply, dense: true),
  ])));
}

/// Detail side panel with close button + tabs.
class DetailPanel extends StatelessWidget {
  const DetailPanel({super.key, required this.title, required this.onClose, this.header, this.tabs, this.tabViews, required this.child, this.footer});
  final String title; final VoidCallback onClose; final Widget? header; final List<String>? tabs; final List<Widget>? tabViews; final Widget child; final Widget? footer;
  @override
  Widget build(BuildContext context) {
    Widget body = child;
    if (tabs != null && tabViews != null) {
      body = DefaultTabController(length: tabs!.length, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TabBar(isScrollable: true, tabAlignment: TabAlignment.start, padding: EdgeInsets.zero, labelPadding: const EdgeInsets.symmetric(horizontal: 12), tabs: [for (final t in tabs!) Tab(text: t, height: 38)]),
        const SizedBox(height: 10),
        _TabBodies(views: tabViews!),
      ]));
    }
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))), IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28))]),
      if (header != null) ...[const SizedBox(height: 6), header!],
      const SizedBox(height: 10),
      body,
      if (footer != null) ...[const SizedBox(height: 14), footer!],
    ])));
  }
}

class _TabBodies extends StatefulWidget {
  const _TabBodies({required this.views});
  final List<Widget> views;
  @override
  State<_TabBodies> createState() => _TabBodiesState();
}

class _TabBodiesState extends State<_TabBodies> {
  TabController? _c; int _i = 0;
  @override
  void didChangeDependencies() { super.didChangeDependencies(); final c = DefaultTabController.of(context); if (c != _c) { _c?.removeListener(_l); _c = c; _c!.addListener(_l); } }
  void _l() { if (mounted) setState(() => _i = _c!.index); }
  @override
  void dispose() { _c?.removeListener(_l); super.dispose(); }
  @override
  Widget build(BuildContext context) => widget.views[_i.clamp(0, widget.views.length - 1)];
}

/// Section title within a detail panel ("Driver Information   [Edit]").
class PanelSection extends StatelessWidget {
  const PanelSection({super.key, required this.title, this.trailing, required this.child});
  final String title; final Widget? trailing; final Widget child;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))), if (trailing != null) trailing!]),
    const Divider(height: 14), child,
  ]));
}

/// Document rows for detail panels: name + Verified chip + View.
class DocumentRow extends StatelessWidget {
  const DocumentRow({super.key, required this.label, required this.status, this.url, this.onView, this.onVerify, this.onReject});
  final String label; final String status; final String? url; final VoidCallback? onView; final VoidCallback? onVerify; final VoidCallback? onReject;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
    const Icon(Icons.description_outlined, size: 16, color: GamyaColors.textMuted), const SizedBox(width: 6),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
    StatusChip(status, small: true, dot: false),
    if (onView != null) IconButton(onPressed: onView, icon: const Icon(Icons.visibility_outlined, size: 16), tooltip: 'View', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 26, minHeight: 26)),
    if (onVerify != null && status != 'VERIFIED') IconButton(onPressed: onVerify, icon: const Icon(Icons.check_circle_outline, size: 16, color: GamyaColors.success), tooltip: 'Verify', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 26, minHeight: 26)),
    if (onReject != null && status != 'REJECTED') IconButton(onPressed: onReject, icon: const Icon(Icons.cancel_outlined, size: 16, color: GamyaColors.danger), tooltip: 'Reject', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 26, minHeight: 26)),
  ]));
}

/// Simple activity list (time · actor · action · details).
class ActivityList extends StatelessWidget {
  const ActivityList({super.key, required this.items, this.compact = false});
  final List<Map<String, dynamic>> items; final bool compact;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const EmptyState(icon: Icons.history, title: 'No activity yet');
    return Column(children: [for (final a in items) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: compact ? 110 : 150, child: Text(Fmt.dateTimeShort(a['createdAt']), style: const TextStyle(fontSize: 11.5, color: GamyaColors.textSecondary))),
      if (!compact) SizedBox(width: 130, child: Text(a['actorName']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      Expanded(child: Text([Fmt.title(a['action']?.toString()), if ((a['details'] ?? '').toString().isNotEmpty) a['details']].join(' – '), style: const TextStyle(fontSize: 12))),
    ]))]);
  }
}
