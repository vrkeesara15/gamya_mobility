import 'package:flutter/material.dart';
import 'package:gamya_core/gamya_core.dart';

/// Minimal paging/filter holder shared by list pages.
class ListQuery {
  ListQuery({this.pageSize = 10});
  int page = 1; int pageSize; final Map<String, dynamic> filters = {};
  Map<String, dynamic> toQuery() => {'page': page, 'pageSize': pageSize, ...filters};
  void set(String k, dynamic v) { if (v == null || (v is String && v.isEmpty)) { filters.remove(k); } else { filters[k] = v; } page = 1; }
  void reset() { filters.clear(); page = 1; }
}

DropdownMenuItem<String?> ddItem(String value, String label) => DropdownMenuItem<String?>(value: value, child: Text(label, style: const TextStyle(fontSize: 12.5)));

const vehicleTypeItems = [('SEDAN', 'Sedan'), ('SUV', 'SUV'), ('INNOVA', 'Innova'), ('TEMPO_TRAVELLER', 'Tempo Traveller'), ('TEMPO', 'Tempo'), ('OTHER', 'Other')];

/// Date range picker button.
class DateRangeButton extends StatelessWidget {
  const DateRangeButton({super.key, required this.range, required this.onChanged});
  final DateTimeRange? range; final ValueChanged<DateTimeRange?> onChanged;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () async { final r = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 365)), initialDateRange: range); if (r != null) onChanged(r); },
    icon: const Icon(Icons.calendar_today_outlined, size: 15), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    label: Text(range == null ? 'All dates' : '${Fmt.date(range!.start)} - ${Fmt.date(range!.end)}', style: const TextStyle(fontSize: 12.5)),
  );
}

/// Simple picker dialog for choosing an item from an API list (vehicle, driver, client...).
Future<Map<String, dynamic>?> pickFromList(BuildContext context, {required String title, required Future<List<Map<String, dynamic>>> Function(String q) fetch, required Widget Function(Map<String, dynamic>) tile}) {
  return showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => _PickerDialog(title: title, fetch: fetch, tile: tile));
}

class _PickerDialog extends StatefulWidget {
  const _PickerDialog({required this.title, required this.fetch, required this.tile});
  final String title; final Future<List<Map<String, dynamic>>> Function(String q) fetch; final Widget Function(Map<String, dynamic>) tile;
  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
  List<Map<String, dynamic>> _items = []; bool _loading = true; final _q = TextEditingController();
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() => _loading = true); try { _items = await widget.fetch(_q.text); } catch (_) {} if (mounted) setState(() => _loading = false); }
  @override
  Widget build(BuildContext context) => Dialog(child: SizedBox(width: 520, height: 560, child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 8, 4), child: Row(children: [Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SearchField(controller: _q, hint: 'Search…', onSubmitted: (_) => _load())),
    const SizedBox(height: 8),
    Expanded(child: _loading ? const LoadingState() : _items.isEmpty ? const EmptyState(title: 'No matches') : ListView.separated(itemCount: _items.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (_, i) => InkWell(onTap: () => Navigator.pop(context, _items[i]), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: widget.tile(_items[i]))))),
  ])));
}
