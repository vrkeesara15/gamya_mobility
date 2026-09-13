import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../core/pick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

/// Driver onboarding: 1 Vehicle Details → 2 Upload Documents → 3 Submit.
class VehicleDocumentsPage extends ConsumerStatefulWidget {
  const VehicleDocumentsPage({super.key});
  @override
  ConsumerState<VehicleDocumentsPage> createState() => _VehicleDocumentsPageState();
}

class _VehicleDocumentsPageState extends ConsumerState<VehicleDocumentsPage> {
  int _step = 0; bool _busy = false;
  final _number = TextEditingController(); final _make = TextEditingController(); final _model = TextEditingController(); int _year = DateTime.now().year - 1; String _type = 'SEDAN';
  List<String> _photos = []; final Map<String, Map<String, dynamic>?> _docs = {'RC': null, 'PERMIT': null, 'INSURANCE': null, 'DRIVING_LICENCE': null};
  List<PlatformInfo> _platforms = []; final Set<String> _plat = {};
  ApiClient get api => ref.read(apiProvider);

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await Future.wait([api.get('/driver/profile'), api.get('/platforms')]);
      final p = api.data(r[0]); final vehicles = (p['vehicles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (vehicles.isNotEmpty) { final v = vehicles.first; _number.text = (v['number'] as String).startsWith('TEMP-') ? '' : v['number'] as String; _make.text = v['make'] as String; _model.text = v['model'] as String; _year = v['year'] as int; _type = v['type'] as String; _photos = (v['photos'] as List).cast<String>(); for (final d in (v['documents'] as List).cast<Map<String, dynamic>>()) { if (_docs.containsKey(d['type'])) _docs[d['type'] as String] = d; } }
      for (final d in (p['documents'] as List).cast<Map<String, dynamic>>()) { if (_docs.containsKey(d['type'])) _docs[d['type'] as String] = d; }
      _platforms = api.list(r[1]).map(PlatformInfo.new).toList(); _plat.addAll(((p['platforms'] as List?) ?? []).map((x) => x['id'] as String));
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveVehicle() async {
    if (_make.text.trim().isEmpty) { toast(context, 'Enter vehicle make', error: true); return; }
    setState(() => _busy = true);
    try { await api.post('/driver/vehicle', body: {'number': _number.text.trim().isEmpty ? null : _number.text.trim(), 'make': _make.text.trim(), 'model': _model.text.trim().isEmpty ? null : _model.text.trim(), 'year': _year, 'type': _type, 'platformIds': _plat.toList()}); setState(() => _step = 1); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }
  Future<Uint8List?> _pickImage() async {
    final src = await showModalBottomSheet<ImageSource>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Take photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)), ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery))])));
    if (src == null) return null;
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 85); return x == null ? null : await x.readAsBytes();
  }
  Future<void> _addPhoto() async { final b = await _pickImage(); if (b == null) return; setState(() => _busy = true); try { final r = await api.upload('/driver/vehicle/photos', files: {'photos': [UploadFile(name: 'vehicle.jpg', bytes: b)]}); setState(() => _photos = api.list(r).cast<String>()); } catch (e) { if (mounted) toast(context, e.msg, error: true); } if (mounted) setState(() => _busy = false); }
  Future<void> _uploadDoc(String type) async {
    final choice = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Take photo'), onTap: () => Navigator.pop(ctx, 'camera')), ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose image'), onTap: () => Navigator.pop(ctx, 'gallery')), ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('Choose PDF / file'), onTap: () => Navigator.pop(ctx, 'file'))])));
    if (choice == null) return;
    Uint8List bytes; String name = '$type.jpg';
    if (choice == 'file') { final files = await pickUploadFiles(type: FileType.custom, extensions: ['pdf', 'jpg', 'jpeg', 'png']); if (files.isEmpty) return; bytes = files.first.bytes; name = files.first.name; }
    else { final x = await ImagePicker().pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1800, imageQuality: 88); if (x == null) return; bytes = await x.readAsBytes(); }

    setState(() => _busy = true);
    try { final r = await api.upload('/driver/documents', files: {'file': [UploadFile(name: name, bytes: bytes)]}, fields: {'type': type}); setState(() => _docs[type] = api.data(r)); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }
  Future<void> _submit() async {
    setState(() => _busy = true);
    try { await api.post('/driver/submit'); await refreshSession(ref); if (mounted) context.go('/pending'); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final docsOk = _docs.values.every((d) => d != null) && _photos.length >= 2;
    return PageScaffold(
      title: 'Vehicle & Documents', onBack: _step == 0 ? () => context.canPop() ? context.pop() : ref.read(sessionProvider.notifier).logout() : () => setState(() => _step--),
      bottom: _step == 0 ? GoldButton(label: 'Save & Continue', expand: true, loading: _busy, onPressed: _saveVehicle) : _step == 1 ? GoldButton(label: 'Continue', expand: true, loading: _busy, onPressed: docsOk ? () => setState(() => _step = 2) : () => toast(context, 'Upload 2 vehicle photos and all 4 documents', error: true)) : GoldButton(label: 'Submit for Approval', expand: true, loading: _busy, onPressed: _submit),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _stepper(), const SizedBox(height: 18),
        if (_step == 0) ...[
          const Text('Vehicle Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 10),
          Row(children: [Expanded(child: LabeledField(label: 'Vehicle Make', required: true, child: TextField(controller: _make, decoration: const InputDecoration(hintText: 'Toyota')))), const SizedBox(width: 10), Expanded(child: LabeledField(label: 'Model Year', child: DropdownButtonFormField<int>(initialValue: _year, items: [for (var y = DateTime.now().year; y >= 2012; y--) DropdownMenuItem(value: y, child: Text('$y'))], onChanged: (v) => setState(() => _year = v ?? _year))))]),
          Row(children: [Expanded(child: LabeledField(label: 'Model', child: TextField(controller: _model, decoration: const InputDecoration(hintText: 'Etios')))), const SizedBox(width: 10), Expanded(child: LabeledField(label: 'Vehicle Type', child: DropdownButtonFormField<String>(initialValue: _type, items: const [DropdownMenuItem(value: 'SEDAN', child: Text('Sedan')), DropdownMenuItem(value: 'SUV', child: Text('SUV')), DropdownMenuItem(value: 'INNOVA', child: Text('Innova')), DropdownMenuItem(value: 'TEMPO_TRAVELLER', child: Text('Tempo Traveller')), DropdownMenuItem(value: 'TEMPO', child: Text('Tempo')), DropdownMenuItem(value: 'OTHER', child: Text('Other'))], onChanged: (v) => setState(() => _type = v ?? 'SEDAN'))))]),
          LabeledField(label: 'Vehicle Number', required: true, child: TextField(controller: _number, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'TS07AB1234'))),
          const Text('Platforms you can drive on', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final p in _platforms) FilterChip(avatar: PlatformIcon(color: GamyaColors.fromHex(p.color), size: 16), label: Text(p.name), selected: _plat.contains(p.id), selectedColor: GamyaColors.goldPale, checkmarkColor: GamyaColors.gold, onSelected: (v) => setState(() => v ? _plat.add(p.id) : _plat.remove(p.id)))]),
        ] else if (_step == 1) ...[
          const Text('Vehicle Photos (2 Required)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [for (final p in _photos) NetImage(p, width: 150, height: 96), InkWell(onTap: _busy ? null : _addPhoto, child: Container(width: 150, height: 96, decoration: BoxDecoration(border: Border.all(color: GamyaColors.gold), borderRadius: BorderRadius.circular(8), color: GamyaColors.goldPale), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: GamyaColors.goldDark), SizedBox(height: 4), Text('Add Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))])))]),
          const SizedBox(height: 18), const Text('Upload Documents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 8),
          for (final e in {'RC': 'RC (Registration Certificate)', 'PERMIT': 'Permit', 'INSURANCE': 'Insurance', 'DRIVING_LICENCE': 'Driving Licence'}.entries) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: GamyaColors.border)), child: Row(children: [Icon(_docs[e.key] == null ? Icons.description_outlined : Icons.task_alt, color: _docs[e.key] == null ? GamyaColors.textMuted : GamyaColors.success), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)), if (_docs[e.key] != null) StatusChip(_docs[e.key]!['status'] as String?, small: true, dot: false)])), GoldButton(label: _docs[e.key] == null ? 'Upload' : 'Replace', dense: true, onPressed: _busy ? null : () => _uploadDoc(e.key))])),
        ] else ...[
          const Text('Review & Submit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 10),
          InfoCard(children: [InfoRow('Vehicle', '${_make.text} ${_model.text} ($_year)'), InfoRow('Number', _number.text), InfoRow('Type', Fmt.vehicleType(_type)), InfoRow('Photos', '${_photos.length} uploaded'), InfoRow('Documents', '${_docs.values.where((d) => d != null).length}/4 uploaded'), InfoRow('Face Verification', ref.watch(sessionProvider)?.faceVerified == true ? 'Completed' : 'Pending')]),
          const NoteBox('After submission, Gamya Mobility admin will verify your details and documents. You will be notified once approved.', color: GamyaColors.gold, icon: Icons.check_circle_outline),
        ],
      ]),
    );
  }

  Widget _stepper() => Row(children: [for (var i = 0; i < 3; i++) ...[Column(children: [Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: i <= _step ? GamyaColors.gold : Colors.white, border: Border.all(color: i <= _step ? GamyaColors.gold : GamyaColors.border)), child: Center(child: i < _step ? const Icon(Icons.check, size: 16, color: Colors.white) : Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: i <= _step ? Colors.white : GamyaColors.textMuted)))), const SizedBox(height: 4), Text(['Vehicle Details', 'Upload Documents', 'Submit'][i], style: TextStyle(fontSize: 10.5, fontWeight: i == _step ? FontWeight.w700 : FontWeight.w400))]), if (i < 2) Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 16), color: i < _step ? GamyaColors.gold : GamyaColors.border))]]);
}
