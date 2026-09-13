import 'package:flutter/material.dart';
import 'package:gamya_core/gamya_core.dart';

class GColumn { const GColumn(this.label, {this.width, this.numeric = false, this.flex}); final String label; final double? width; final bool numeric; final int? flex; }

/// Table with checkbox column, zebra hover, and a horizontal scroller for narrow screens.
class GTable<T> extends StatelessWidget {
  const GTable({super.key, required this.columns, required this.rows, required this.cells, this.selected = const {}, this.onSelect, this.onSelectAll, this.onRowTap, this.selectedRow, this.loading = false, this.error, this.onRetry, this.emptyText = 'No records found', this.minWidth = 900, this.rowId});
  final List<GColumn> columns; final List<T> rows; final List<Widget> Function(T row, int index) cells;
  final Set<String> selected; final void Function(String id, bool sel)? onSelect; final void Function(bool all)? onSelectAll; final void Function(T row)? onRowTap; final T? selectedRow;
  final bool loading; final String? error; final VoidCallback? onRetry; final String emptyText; final double minWidth; final String Function(T)? rowId;

  @override
  Widget build(BuildContext context) {
    if (loading) return const LoadingState(height: 240);
    if (error != null) return ErrorState(message: error!, onRetry: onRetry);
    if (rows.isEmpty) return EmptyState(title: emptyText);
    final hasCheck = onSelect != null;
    final allSel = rows.isNotEmpty && rowId != null && rows.every((r) => selected.contains(rowId!(r)));
    return LayoutBuilder(builder: (ctx, c) {
      final table = ConstrainedBox(constraints: BoxConstraints(minWidth: c.maxWidth > minWidth ? c.maxWidth : minWidth), child: Column(children: [
        Container(color: GamyaColors.surface, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9), child: Row(children: [
          if (hasCheck) SizedBox(width: 34, child: Checkbox(value: allSel, onChanged: onSelectAll == null ? null : (v) => onSelectAll!(v ?? false), visualDensity: VisualDensity.compact)),
          const SizedBox(width: 30, child: Text('#', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GamyaColors.textSecondary))),
          for (final col in columns) _cell(col, Text(col.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GamyaColors.textSecondary))),
        ])),
        for (var i = 0; i < rows.length; i++) _row(rows[i], i, hasCheck),
      ]));
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
    });
  }

  Widget _cell(GColumn col, Widget child) => col.width != null ? SizedBox(width: col.width, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Align(alignment: col.numeric ? Alignment.centerRight : Alignment.centerLeft, child: child))) : Expanded(flex: col.flex ?? 1, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Align(alignment: col.numeric ? Alignment.centerRight : Alignment.centerLeft, child: child)));

  Widget _row(T r, int i, bool hasCheck) {
    final id = rowId?.call(r);
    final isSel = selectedRow != null && rowId != null && rowId!(selectedRow as T) == id;
    final cs = cells(r, i);
    return InkWell(onTap: onRowTap == null ? null : () => onRowTap!(r), child: Container(
      decoration: BoxDecoration(color: isSel ? GamyaColors.goldPale : Colors.white, border: const Border(bottom: BorderSide(color: GamyaColors.divider))),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), constraints: const BoxConstraints(minHeight: 46),
      child: Row(children: [
        if (hasCheck) SizedBox(width: 34, child: Checkbox(value: id != null && selected.contains(id), onChanged: id == null ? null : (v) => onSelect!(id, v ?? false), visualDensity: VisualDensity.compact)),
        SizedBox(width: 30, child: Text('${i + 1}', style: const TextStyle(fontSize: 12.5, color: GamyaColors.textSecondary))),
        for (var c = 0; c < columns.length; c++) _cell(columns[c], c < cs.length ? cs[c] : const SizedBox()),
      ]),
    ));
  }
}

class CellText extends StatelessWidget {
  const CellText(this.text, {super.key, this.bold = false, this.muted = false, this.color, this.maxLines = 1});
  final String? text; final bool bold; final bool muted; final Color? color; final int maxLines;
  @override
  Widget build(BuildContext context) => Text(text == null || text!.isEmpty ? '—' : text!, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: bold ? FontWeight.w600 : FontWeight.w400, color: color ?? (muted ? GamyaColors.textSecondary : GamyaColors.textPrimary)));
}

/// "From → To" route cell.
class RouteText extends StatelessWidget {
  const RouteText(this.from, this.to, {super.key, this.fontSize = 12.5});
  final String from; final String to; final double fontSize;
  @override
  Widget build(BuildContext context) => RichText(maxLines: 2, overflow: TextOverflow.ellipsis, text: TextSpan(style: TextStyle(fontSize: fontSize, color: GamyaColors.textPrimary), children: [TextSpan(text: from), const TextSpan(text: '  →  ', style: TextStyle(color: GamyaColors.textMuted)), TextSpan(text: to)]));
}

/// Name + avatar cell.
class PersonCell extends StatelessWidget {
  const PersonCell({super.key, required this.name, this.avatarUrl, this.subtitle, this.size = 28});
  final String name; final String? avatarUrl; final String? subtitle; final double size;
  @override
  Widget build(BuildContext context) => Row(children: [GamyaAvatar(url: avatarUrl, name: name, size: size), const SizedBox(width: 8), Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)), if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: GamyaColors.textSecondary))]))]);
}

/// Row action buttons: view / edit / more.
class RowActions extends StatelessWidget {
  const RowActions({super.key, this.onView, this.onEdit, this.more, this.extra = const []});
  final VoidCallback? onView; final VoidCallback? onEdit; final List<PopupMenuEntry<String>> Function()? more; final List<Widget> extra;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    if (onView != null) TableIconButton(icon: Icons.visibility_outlined, onPressed: onView, tooltip: 'View'),
    if (onEdit != null) ...[const SizedBox(width: 4), TableIconButton(icon: Icons.edit_outlined, onPressed: onEdit, tooltip: 'Edit')],
    ...extra,
    if (more != null) ...[const SizedBox(width: 4), SizedBox(width: 30, height: 30, child: PopupMenuButton<String>(padding: EdgeInsets.zero, itemBuilder: (_) => more!(), onSelected: (v) {}, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: GamyaColors.border)), child: const Icon(Icons.more_vert, size: 17, color: GamyaColors.textSecondary))))],
  ]);
}
