import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../utils/format.dart';

class GamyaAvatar extends StatelessWidget {
  const GamyaAvatar({super.key, this.url, this.name, this.size = 36, this.square = false, this.borderColor});
  final String? url; final String? name; final double size; final bool square; final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(width: size, height: size, alignment: Alignment.center, color: GamyaColors.goldPale, child: Text(Fmt.initials(name), style: TextStyle(color: GamyaColors.goldDark, fontWeight: FontWeight.w700, fontSize: size * 0.36)));
    // initials underneath, photo on top – so a slow or blocked image never leaves a blank circle
    Widget child = (url == null || url!.isEmpty) ? fallback : Stack(fit: StackFit.expand, children: [fallback, Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())]);
    child = ClipRRect(borderRadius: BorderRadius.circular(square ? size * 0.2 : size), child: child);
    if (borderColor != null) child = Container(decoration: BoxDecoration(shape: square ? BoxShape.rectangle : BoxShape.circle, borderRadius: square ? BorderRadius.circular(size * 0.2 + 2) : null, border: Border.all(color: borderColor!, width: 2)), child: child);
    return SizedBox(width: size, height: size, child: child);
  }
}

class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.width, this.height, this.fit = BoxFit.cover, this.radius = 8, this.placeholderIcon = Icons.image_outlined});
  final String? url; final double? width; final double? height; final BoxFit fit; final double radius; final IconData placeholderIcon;
  @override
  Widget build(BuildContext context) {
    final ph = Container(width: width, height: height, color: GamyaColors.neutralBg, alignment: Alignment.center, child: Icon(placeholderIcon, color: GamyaColors.textMuted));
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: (url == null || url!.isEmpty) ? ph : Image.network(url!, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => ph));
  }
}
