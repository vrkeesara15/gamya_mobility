import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

/// Step 1: Post Your Requirement · Step 2: Select Trip Tracking Platform.
class PostRequirementPage extends ConsumerStatefulWidget {
  const PostRequirementPage({super.key});
  @override
  ConsumerState<PostRequirementPage> createState() => _PostRequirementPageState();
}

class _PostRequirementPageState extends ConsumerState<PostRequirementPage> {
  int _step = 0;
  String _type = 'SEDAN'; int _year = 2022; int _vehicles = 1; TimeOfDay _login = const TimeOfDay(hour: 9, minute: 0); TimeOfDay _reporting = const TimeOfDay(hour: 8, minute: 30);
  final _pickup = TextEditingController(text: 'Mindspace, Hitech City, Hyderabad'); final _drop = TextEditingController(); DateTime _date = DateTime.now().add(const Duration(days: 1)); String _bookingType = 'INSTANT'; int _pax = 1; final _notes = TextEditingController();
  List<PlatformInfo> _platforms = []; String? _platformId; final _other = TextEditingController(); List<String> _locations = [];
  ApiClient get api => ref.read(apiProvider);

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final r = await Future.wait([api.get('/platforms'), api.get('/locations')]); if (mounted) setState(() { _platforms = api.list(r[0]).map(PlatformInfo.new).toList(); _platformId ??= _platforms.isEmpty ? null : _platforms.first.id; _locations = api.list(r[1]).map((l) => '${l['name']}, Hyderabad').toList(); }); } catch (_) {} }

  String _t(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  Future<void> _pickTime(bool login) async { final t = await showTimePicker(context: context, initialTime: login ? _login : _reporting); if (t != null) setState(() => login ? _login = t : _reporting = t); }

  void _next() {
    if (_step == 0) {
      if (_pickup.text.trim().length < 2 || _drop.text.trim().length < 2) { toast(context, 'Enter pickup and drop locations', error: true); return; }
      setState(() => _step = 1); return;
    }
    final p = _platforms.where((x) => x.id == _platformId).firstOrNull;
    if (p == null) { toast(context, 'Select a trip tracking platform', error: true); return; }
    if (p.code == 'OTHER' && _other.text.trim().isEmpty) { toast(context, 'Please specify the platform', error: true); return; }
    final scheduled = DateTime(_date.year, _date.month, _date.day, _login.hour, _login.minute);
    context.push('/sup/summary', extra: {'vehicleType': _type, 'modelYearMin': _year, 'numberOfVehicles': _vehicles, 'loginTime': _t(_login), 'reportingTime': _t(_reporting), 'fromLocation': _pickup.text.trim(), 'toLocation': _drop.text.trim(), 'scheduledAt': scheduled.toUtc().toIso8601String(), 'scheduledLocal': scheduled.toIso8601String(), 'bookingType': _bookingType, 'passengers': _pax, 'platformId': p.id, 'platformName': p.name, 'platformColor': p.color, 'platformCode': p.code, 'otherPlatformName': _other.text.trim(), 'specialInstructions': _notes.text.trim()});
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: _step == 0 ? 'Post Your Requirement' : 'Trip Tracking Platform', onBack: _step == 0 ? () => context.pop() : () => setState(() => _step = 0),
    bottom: GoldButton(label: 'Next', expand: true, onPressed: _next),
    child: _step == 0 ? _form() : _platformStep(),
  );

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    LabeledField(label: 'Vehicle Requirement', required: true, child: DropdownButtonFormField<String>(initialValue: _type, items: const [DropdownMenuItem(value: 'SEDAN', child: Text('Sedan')), DropdownMenuItem(value: 'SUV', child: Text('SUV')), DropdownMenuItem(value: 'INNOVA', child: Text('Innova')), DropdownMenuItem(value: 'TEMPO_TRAVELLER', child: Text('Tempo Traveller')), DropdownMenuItem(value: 'TEMPO', child: Text('Tempo')), DropdownMenuItem(value: 'OTHER', child: Text('Other'))], onChanged: (v) => setState(() => _type = v ?? 'SEDAN'))),
    LabeledField(label: 'Model Year', child: DropdownButtonFormField<int>(initialValue: _year, items: [for (final y in [2018, 2019, 2020, 2021, 2022, 2023, 2024]) DropdownMenuItem(value: y, child: Text('$y & Above'))], onChanged: (v) => setState(() => _year = v ?? 2022))),
    Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [const Expanded(child: Text('Number of Vehicles', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))), Stepper2(value: _vehicles, onChanged: (v) => setState(() => _vehicles = v))])),
    Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [const Expanded(child: Text('Number of Passengers', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))), Stepper2(value: _pax, max: 60, onChanged: (v) => setState(() => _pax = v))])),
    Row(children: [Expanded(child: LabeledField(label: 'Date of Travel', child: InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180))); if (d != null) setState(() => _date = d); }, child: InputDecorator(decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today_outlined, size: 18)), child: Text(Fmt.date(_date), style: const TextStyle(fontSize: 14)))))), const SizedBox(width: 10), Expanded(child: LabeledField(label: 'Login Time', child: InkWell(onTap: () => _pickTime(true), child: InputDecorator(decoration: const InputDecoration(prefixIcon: Icon(Icons.schedule, size: 18)), child: Text(_login.format(context), style: const TextStyle(fontSize: 14))))))]),
    LabeledField(label: 'Reporting Time', child: InkWell(onTap: () => _pickTime(false), child: InputDecorator(decoration: const InputDecoration(prefixIcon: Icon(Icons.schedule, size: 18)), child: Text(_reporting.format(context), style: const TextStyle(fontSize: 14))))),
    LabeledField(label: 'Pickup Location', required: true, child: _loc(_pickup, 'Mindspace, Hitech City, Hyderabad')),
    LabeledField(label: 'Drop Location', required: true, child: _loc(_drop, 'Raheja IT Park, Gachibowli, Hyderabad')),
    const Text('Booking Type', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
    OptionTile(selected: _bookingType == 'INSTANT', onTap: () => setState(() => _bookingType = 'INSTANT'), title: 'Instant Booking', subtitle: 'Need a vehicle as soon as possible', leading: const Icon(Icons.bolt, color: GamyaColors.gold)),
    OptionTile(selected: _bookingType == 'SCHEDULED', onTap: () => setState(() => _bookingType = 'SCHEDULED'), title: 'Scheduled Booking', subtitle: 'Plan for a later date & time', leading: const Icon(Icons.event, color: GamyaColors.gold)),
    const SizedBox(height: 8),
    LabeledField(label: 'Special Instructions (optional)', child: TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(hintText: 'e.g. Need before 9:30 AM sharp'))),
  ]);

  Widget _loc(TextEditingController c, String hint) => Autocomplete<String>(initialValue: TextEditingValue(text: c.text), optionsBuilder: (v) => v.text.isEmpty ? _locations : _locations.where((l) => l.toLowerCase().contains(v.text.toLowerCase())), onSelected: (v) => c.text = v, fieldViewBuilder: (ctx, tc, fn, _) { tc.addListener(() => c.text = tc.text); return TextField(controller: tc, focusNode: fn, decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.location_on_outlined, size: 18))); });

  Widget _platformStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Driver will perform the trip in the selected platform. This helps you track the trip status in the respective app.', style: TextStyle(fontSize: 12.5, color: GamyaColors.textSecondary, height: 1.4)), const SizedBox(height: 16),
    if (_platforms.isEmpty) const LoadingState(height: 80),
    for (final p in _platforms) OptionTile(selected: _platformId == p.id, onTap: () => setState(() => _platformId = p.id), title: p.code == 'OTHER' ? 'Other (Please specify)' : p.name, leading: PlatformIcon(color: GamyaColors.fromHex(p.color), size: 30)),
    if (_platforms.any((p) => p.id == _platformId && p.code == 'OTHER')) Padding(padding: const EdgeInsets.only(top: 4, bottom: 12), child: TextField(controller: _other, decoration: const InputDecoration(hintText: 'Platform name'))),
    const SizedBox(height: 8), const NoteBox('The trip will be created in the selected platform and assigned to the driver.', color: GamyaColors.info),
  ]);
}
