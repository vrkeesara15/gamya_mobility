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

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});
  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  Map<String, dynamic>? _d; String? _error; bool _busy = false;
  ApiClient get api => ref.read(apiProvider);
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final r = await api.get('/driver/documents'); if (mounted) setState(() => _d = api.data(r)); } catch (e) { if (mounted) setState(() => _error = e.msg); } }
  Future<void> _upload(String type) async {
    if (type == 'FACE_VERIFICATION') { context.push('/face'); return; }
    if (type.startsWith('VEHICLE_PHOTO')) { final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85); if (x == null) return; setState(() => _busy = true); try { await api.upload('/driver/vehicle/photos', files: {'photos': [UploadFile(name: 'vehicle.jpg', bytes: await x.readAsBytes())]}); await _load(); } catch (e) { if (mounted) toast(context, e.msg, error: true); } if (mounted) setState(() => _busy = false); return; }
    final choice = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Take photo'), onTap: () => Navigator.pop(ctx, 'camera')), ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose image'), onTap: () => Navigator.pop(ctx, 'gallery')), ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('Choose PDF / file'), onTap: () => Navigator.pop(ctx, 'file'))])));
    if (choice == null) return;
    Uint8List bytes; String name = '$type.jpg';
    if (choice == 'file') { final files = await pickUploadFiles(type: FileType.custom, extensions: ['pdf', 'jpg', 'jpeg', 'png']); if (files.isEmpty) return; bytes = files.first.bytes; name = files.first.name; }
    else { final x = await ImagePicker().pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1800, imageQuality: 88); if (x == null) return; bytes = await x.readAsBytes(); }
    setState(() => _busy = true);
    try { await api.upload('/driver/documents', files: {'file': [UploadFile(name: name, bytes: bytes)]}, fields: {'type': type}); await _load(); if (mounted) toast(context, 'Uploaded – pending verification'); } catch (e) { if (mounted) toast(context, e.msg, error: true); }
    if (mounted) setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) {
    final d = _d;
    return PageScaffold(title: 'Documents', child: _error != null ? ErrorState(message: _error!, onRetry: _load) : d == null ? const LoadingState(height: 300) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [const Expanded(child: Text('Required documents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))), FractionChip(done: (d['summary']['verified'] as num).toInt(), total: (d['summary']['required'] as num).toInt())]), const SizedBox(height: 10),
      for (final x in (d['required'] as List).cast<Map<String, dynamic>>()) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GamyaColors.border)), child: Row(children: [
        Icon(x['status'] == 'VERIFIED' ? Icons.task_alt : x['status'] == 'MISSING' ? Icons.upload_file_outlined : Icons.description_outlined, color: GamyaColors.status(x['status'] as String?)), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)), const SizedBox(height: 3), Row(children: [StatusChip(x['status'] as String?, small: true, dot: false), if (x['validTill'] != null) Padding(padding: const EdgeInsets.only(left: 6), child: Text('till ${Fmt.date(x['validTill'])}', style: const TextStyle(fontSize: 11, color: GamyaColors.textMuted)))]), if (x['remarks'] != null) Text(x['remarks'] as String, style: const TextStyle(fontSize: 11.5, color: GamyaColors.danger))])),
        OutlineButton(label: x['status'] == 'MISSING' ? 'Upload' : 'Renew', dense: true, onPressed: _busy ? null : () => _upload(x['type'] as String)),
      ])),
      const SizedBox(height: 8), const NoteBox('Uploaded documents are verified by the Gamya Mobility admin team. Keep permits and insurance renewed to stay active.', color: GamyaColors.info),
    ]));
  }
}
