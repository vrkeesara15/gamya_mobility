import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../core/providers.dart';

/// Top-bar global search with a results dropdown (drivers, supervisors, vehicles, bookings, ad-hoc).
class GlobalSearchField extends ConsumerStatefulWidget {
  const GlobalSearchField({super.key});
  @override
  ConsumerState<GlobalSearchField> createState() => _GlobalSearchFieldState();
}

class _GlobalSearchFieldState extends ConsumerState<GlobalSearchField> {
  final _ctrl = TextEditingController();
  final _link = LayerLink();
  OverlayEntry? _overlay;
  Timer? _debounce;
  Map<String, dynamic> _results = {};

  @override
  void dispose() { _hide(); _debounce?.cancel(); _ctrl.dispose(); super.dispose(); }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) { _hide(); return; }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try { final r = await ref.read(apiProvider).get('/dashboard/search', query: {'q': q.trim()}); _results = ref.read(apiProvider).data(r); _show(); } catch (_) {}
    });
  }

  void _hide() { _overlay?.remove(); _overlay = null; }
  void _show() {
    _hide();
    _overlay = OverlayEntry(builder: (_) => Positioned(width: 420, child: CompositedTransformFollower(link: _link, offset: const Offset(0, 44), child: Material(elevation: 6, borderRadius: BorderRadius.circular(10), child: _ResultsList(results: _results, onPick: (route, id) { _hide(); _ctrl.clear(); context.go('$route?id=$id'); })))));
    Overlay.of(context).insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(link: _link, child: TapRegion(onTapOutside: (_) => _hide(), child: SearchField(controller: _ctrl, dark: true, hint: 'Search (Driver, Supervisor, Booking, Vehicle...)', onChanged: _onChanged)));
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results, required this.onPick});
  final Map<String, dynamic> results; final void Function(String route, String id) onPick;
  @override
  Widget build(BuildContext context) {
    final groups = {'drivers': ('Drivers', Icons.person_outline), 'supervisors': ('Supervisors', Icons.supervisor_account_outlined), 'vehicles': ('Vehicles', Icons.directions_car_outlined), 'bookings': ('Bookings', Icons.event_note_outlined), 'adhoc': ('Ad-hoc Requests', Icons.add_box_outlined)};
    final children = <Widget>[];
    groups.forEach((k, v) {
      final list = (results[k] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (list.isEmpty) return;
      children.add(Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 4), child: Text(v.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: GamyaColors.textMuted))));
      for (final r in list) {
        children.add(ListTile(dense: true, leading: Icon(v.$2, size: 18, color: GamyaColors.gold), title: Text(r['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)), subtitle: Text([r['code'], r['number'], r['mobile']].where((x) => x != null).join(' · '), style: const TextStyle(fontSize: 11.5)), onTap: () => onPick(r['route'] as String, r['id'] as String)));
      }
    });
    if (children.isEmpty) children.add(const Padding(padding: EdgeInsets.all(16), child: Text('No results', style: TextStyle(color: GamyaColors.textMuted))));
    return ConstrainedBox(constraints: const BoxConstraints(maxHeight: 420), child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 8), children: children));
  }
}
