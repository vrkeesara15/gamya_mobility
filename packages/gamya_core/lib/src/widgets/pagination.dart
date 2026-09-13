import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../models/models.dart';

/// "Showing 1 to 10 of 318 drivers   < 1 2 3 4 5 … 32 >   10 / page"
class PaginationBar extends StatelessWidget {
  const PaginationBar({super.key, required this.paged, required this.onPage, this.onPageSize, this.noun = 'items'});
  final Paged paged; final ValueChanged<int> onPage; final ValueChanged<int>? onPageSize; final String noun;

  List<int?> _pages() {
    final t = paged.totalPages, c = paged.page;
    if (t <= 7) return List.generate(t, (i) => i + 1);
    final s = <int?>{1, 2, 3, 4, 5, t, c - 1, c, c + 1}.where((p) => p! >= 1 && p <= t).toList()..sort((a, b) => a!.compareTo(b!));
    final out = <int?>[];
    for (var i = 0; i < s.length; i++) { if (i > 0 && s[i]! - s[i - 1]! > 1) out.add(null); out.add(s[i]); }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final pages = _pages();
    final pager = Row(mainAxisSize: MainAxisSize.min, children: [
      _btn(const Icon(Icons.chevron_left, size: 18), paged.page > 1 ? () => onPage(paged.page - 1) : null),
      for (final p in pages) p == null ? const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('…', style: TextStyle(color: GamyaColors.textMuted))) : _btn(Text('$p', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p == paged.page ? Colors.white : GamyaColors.textPrimary)), () => onPage(p), active: p == paged.page),
      _btn(const Icon(Icons.chevron_right, size: 18), paged.page < paged.totalPages ? () => onPage(paged.page + 1) : null),
    ]);
    final sizes = onPageSize == null ? const SizedBox.shrink() : DropdownButtonHideUnderline(child: DropdownButton<int>(value: paged.pageSize, isDense: true, style: const TextStyle(fontSize: 12.5, color: GamyaColors.textPrimary), items: const [10, 20, 50, 100].map((n) => DropdownMenuItem(value: n, child: Text('$n / page'))).toList(), onChanged: (v) => v == null ? null : onPageSize!(v)));
    final info = Text('Showing ${paged.from} to ${paged.to} of ${paged.total} $noun', style: const TextStyle(fontSize: 12.5, color: GamyaColors.textSecondary));
    if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 8), Row(children: [Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: pager)), sizes])]);
    return Row(children: [info, const Spacer(), pager, const SizedBox(width: 16), sizes]);
  }

  Widget _btn(Widget child, VoidCallback? onTap, {bool active = false}) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: InkWell(borderRadius: BorderRadius.circular(6), onTap: onTap, child: Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: active ? GamyaColors.gold : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: active ? GamyaColors.gold : GamyaColors.border)), child: Opacity(opacity: onTap == null && !active ? 0.4 : 1, child: child))));
}
