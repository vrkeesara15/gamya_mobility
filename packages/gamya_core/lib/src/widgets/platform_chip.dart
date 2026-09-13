import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Coloured square icon + platform name (Routematic, MoveInSync …).
class PlatformChip extends StatelessWidget {
  const PlatformChip({super.key, required this.name, this.color, this.code, this.compact = false});
  final String name; final String? color; final String? code; final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = color != null ? GamyaColors.fromHex(color) : (GamyaColors.platform[code ?? name.toUpperCase().replaceAll(' ', '_')] ?? GamyaColors.neutral);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      PlatformIcon(color: c, size: compact ? 16 : 20),
      const SizedBox(width: 6),
      Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 12 : 13, color: GamyaColors.textPrimary))),
    ]);
  }
}

class PlatformIcon extends StatelessWidget {
  const PlatformIcon({super.key, required this.color, this.size = 20});
  final Color color; final double size;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.22)), child: Icon(Icons.near_me, size: size * 0.6, color: Colors.white));
}
