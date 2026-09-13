import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gamya_core/gamya_core.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../app.dart';
import '../../core/providers.dart';
import '../../widgets/mobile_widgets.dart';

/// Facial Identification: live front-camera preview in a circular frame, capture & verify.
class FacePage extends ConsumerStatefulWidget {
  const FacePage({super.key});
  @override
  ConsumerState<FacePage> createState() => _FacePageState();
}

class _FacePageState extends ConsumerState<FacePage> {
  CameraController? _cam; bool _camError = false; Uint8List? _captured; bool _busy = false; Map<String, dynamic>? _result;

  @override
  void initState() { super.initState(); _initCamera(); }
  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cams.first);
      final c = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await c.initialize();
      if (mounted) { setState(() => _cam = c); } else { await c.dispose(); }
    } catch (_) { if (mounted) setState(() => _camError = true); }
  }
  @override
  void dispose() { _cam?.dispose(); super.dispose(); }

  Future<void> _capture() async {
    Uint8List? bytes;
    try {
      if (_cam != null && _cam!.value.isInitialized) { final x = await _cam!.takePicture(); bytes = await x.readAsBytes(); }
      else { final x = await ImagePicker().pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, maxWidth: 1024, imageQuality: 85); if (x != null) bytes = await x.readAsBytes(); }
    } catch (e) { if (mounted) toast(context, 'Could not capture photo: ${e.msg}', error: true); return; }
    if (bytes == null) return;
    setState(() { _captured = bytes; _busy = true; });
    try {
      final api = ref.read(apiProvider);
      final r = await api.upload('/auth/face-verify', files: {'selfie': [UploadFile(name: 'selfie.jpg', bytes: bytes)]});
      _result = api.data(r);
      final u = await refreshSession(ref);
      if (mounted) setState(() => _busy = false);
      if (_result!['matched'] == true && u != null && mounted) { await Future.delayed(const Duration(milliseconds: 900)); if (mounted) context.go(u.isSupervisor ? '/pending' : '/drv/onboarding'); }
    } catch (e) { if (mounted) { toast(context, e.msg, error: true); setState(() { _busy = false; _captured = null; }); } }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ClipOval(child: SizedBox(width: 220, height: 220, child: _captured != null ? Image.memory(_captured!, fit: BoxFit.cover) : _cam != null ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _cam!.value.previewSize?.height ?? 220, height: _cam!.value.previewSize?.width ?? 220, child: CameraPreview(_cam!))) : Container(color: GamyaColors.neutralBg, child: Icon(_camError ? Icons.no_photography_outlined : Icons.face, size: 90, color: GamyaColors.textMuted))));
    final matched = _result?['matched'] == true;
    return AuthScaffold(headerHeight: 150, showTagline: false, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Center(child: Text('Facial Identification', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))), const SizedBox(height: 18),
      Center(child: Stack(alignment: Alignment.center, children: [Container(width: 244, height: 244, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: matched ? GamyaColors.success : GamyaColors.gold, width: 3))), preview, if (_busy) const CircularProgressIndicator(color: Colors.white)])),
      const SizedBox(height: 16),
      Center(child: Text(_result == null ? 'Look into the camera and\nfollow the instructions' : matched ? 'Face matched (${((_result!['score'] as num) * 100).round()}%)' : 'Face not verified – please retake', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _result == null ? GamyaColors.textPrimary : matched ? GamyaColors.success : GamyaColors.danger))),
      const SizedBox(height: 18),
      for (final t in ['Position your face in the frame', 'Ensure good lighting', 'Do not wear sunglasses or mask']) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Container(width: 24, height: 24, decoration: const BoxDecoration(color: GamyaColors.gold, shape: BoxShape.circle), child: const Icon(Icons.check, size: 15, color: Colors.white)), const SizedBox(width: 12), Text(t, style: const TextStyle(fontSize: 13.5))])),
      const SizedBox(height: 12),
      GoldButton(label: _captured == null ? 'Capture & Verify' : matched ? 'Continue' : 'Retake', expand: true, loading: _busy, onPressed: matched ? () { final u = ref.read(sessionProvider)!; context.go(homeFor(u)); } : () { setState(() { _captured = null; _result = null; }); _capture(); }),
      if (_camError) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Camera preview unavailable – the system camera will open when you tap Capture.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: GamyaColors.textMuted))),
      TextButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: const Text('Cancel and logout', style: TextStyle(color: GamyaColors.textSecondary))),
    ]));
  }
}
