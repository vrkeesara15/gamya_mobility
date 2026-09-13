import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../utils/format.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label, this.dot = true, this.small = false});
  final String? status;
  final String? label;
  final bool dot;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = GamyaColors.status(status);
    final bg = GamyaColors.statusBg(status);
    final text = label ?? _label(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 7 : 9, vertical: small ? 2 : 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 5)],
        Text(text, style: TextStyle(color: c, fontSize: small ? 10.5 : 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  static String _label(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'ON_TRIP': return 'On Trip';
      case 'YET_TO_START': return 'Yet to Start';
      case 'UNDER_REVIEW': return 'Under Review';
      case 'IN_PROGRESS': return 'In Progress';
      case 'FULLY_COMPLIANT': return 'Fully Compliant';
      case 'NON_COMPLIANT': return 'Non-Compliant';
      case 'DUE_FOR_RENEWAL': return 'Due for Renewal';
      case 'UNDER_VERIFICATION': return 'Under Verification';
      default: return Fmt.title(s);
    }
  }
}

/// Coloured count badge (e.g. sidebar "28").
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.color = GamyaColors.danger});
  final int count; final Color color;
  @override
  Widget build(BuildContext context) => count <= 0 ? const SizedBox.shrink() : Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), constraints: const BoxConstraints(minWidth: 20),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
    child: Text('$count', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

/// "7/7" style document fraction, red when incomplete.
class FractionChip extends StatelessWidget {
  const FractionChip({super.key, required this.done, required this.total});
  final int done; final int total;
  @override
  Widget build(BuildContext context) {
    final ok = done >= total;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: ok ? GamyaColors.successBg : GamyaColors.dangerBg, borderRadius: BorderRadius.circular(6)), child: Text('$done/$total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ok ? GamyaColors.success : GamyaColors.danger)));
  }
}
