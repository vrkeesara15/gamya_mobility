// Renders the Gamya "G" mark into PNG launcher icons / favicons.
// Run:  flutter test test/gen_icons_test.dart   (from packages/gamya_core)
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamya_core/gamya_core.dart';

Future<void> _render(WidgetTester tester, double size, List<String> outputs) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(Size(size, size));
  await tester.pumpWidget(RepaintBoundary(key: key, child: Container(
    width: size, height: size,
    decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(size * 0.18)),
    child: Center(child: GamyaMark(size: size * 0.74)),
  )));
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    for (final o in outputs) { final f = File(o); await f.parent.create(recursive: true); await f.writeAsBytes(bytes); }
  });
}

void main() {
  testWidgets('generate icons', (tester) async {
    final root = Directory.current.path.replaceAll(RegExp(r'/packages/gamya_core/?$'), '');
    final mob = '$root/apps/mobile'; final web = '$root/apps/admin_web/web';
    for (final e in {'mdpi': 48.0, 'hdpi': 72.0, 'xhdpi': 96.0, 'xxhdpi': 144.0, 'xxxhdpi': 192.0}.entries) {
      await _render(tester, e.value, ['$mob/android/app/src/main/res/mipmap-${e.key}/ic_launcher.png']);
    }
    await _render(tester, 192, ['$web/icons/Icon-192.png', '$web/icons/Icon-maskable-192.png', '$mob/web/icons/Icon-192.png', '$mob/web/icons/Icon-maskable-192.png']);
    await _render(tester, 512, ['$web/icons/Icon-512.png', '$web/icons/Icon-maskable-512.png', '$mob/web/icons/Icon-512.png', '$mob/web/icons/Icon-maskable-512.png', '$root/docs/icon-512.png']);
    await _render(tester, 64, ['$web/favicon.png', '$mob/web/favicon.png']);
  });
}
