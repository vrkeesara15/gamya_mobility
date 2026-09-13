import 'package:flutter/material.dart';
import 'package:gamya_core/gamya_core.dart';

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String confirmLabel = 'Confirm', bool danger = false}) async {
  final r = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), content: Text(message),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: GamyaColors.textSecondary))), FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: danger ? GamyaColors.danger : GamyaColors.gold), child: Text(confirmLabel))],
  ));
  return r ?? false;
}

/// Confirm with an optional text reason / remarks.
Future<String?> reasonDialog(BuildContext context, {required String title, String label = 'Reason', String confirmLabel = 'Confirm', bool danger = false, bool required = false, String? hint}) async {
  final c = TextEditingController();
  return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
    title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
    content: SizedBox(width: 400, child: TextField(controller: c, maxLines: 3, decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: true))),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: GamyaColors.textSecondary))), FilledButton(onPressed: () { if (required && c.text.trim().isEmpty) return; Navigator.pop(ctx, c.text.trim()); }, style: FilledButton.styleFrom(backgroundColor: danger ? GamyaColors.danger : GamyaColors.gold), child: Text(confirmLabel))],
  ));
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? GamyaColors.danger : GamyaColors.dark, width: 420));
}

/// Generic form dialog scaffold with title, body and Save/Cancel.
class FormDialog extends StatelessWidget {
  const FormDialog({super.key, required this.title, required this.child, required this.onSave, this.saveLabel = 'Save', this.busy = false, this.width = 560});
  final String title; final Widget child; final VoidCallback onSave; final String saveLabel; final bool busy; final double width;
  @override
  Widget build(BuildContext context) => Dialog(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width, maxHeight: MediaQuery.sizeOf(context).height * 0.9), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 16, 12, 8), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20))])),
    const Divider(),
    Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: child)),
    const Divider(),
    Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 14), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [OutlineButton(label: 'Cancel', onPressed: () => Navigator.pop(context)), const SizedBox(width: 8), GoldButton(label: saveLabel, onPressed: onSave, loading: busy)])),
  ])));
}

/// Two fields side by side inside forms.
class FieldRow extends StatelessWidget {
  const FieldRow(this.children, {super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i = 0; i < children.length; i++) ...[Expanded(child: children[i]), if (i < children.length - 1) const SizedBox(width: 12)]]);
}

/// Shows an image in a lightbox.
void showImageDialog(BuildContext context, String? url, {String? title}) {
  if (url == null || url.isEmpty) return;
  showDialog(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 10, 8, 4), child: Row(children: [Expanded(child: Text(title ?? 'Preview', style: const TextStyle(fontWeight: FontWeight.w600))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))])),
    Flexible(child: InteractiveViewer(child: url.toLowerCase().endsWith('.pdf') ? const Padding(padding: EdgeInsets.all(40), child: Text('PDF document – open in a new tab to view.')) : Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(40), child: Text('Could not load image'))))),
    const SizedBox(height: 12),
  ]))));
}
