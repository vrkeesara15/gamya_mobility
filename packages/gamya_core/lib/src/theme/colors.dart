import 'package:flutter/material.dart';

/// Brand palette extracted from the Gamya Mobility design screenshots.
class GamyaColors {
  GamyaColors._();

  static const Color gold = Color(0xFFB8862B);
  static const Color goldLight = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFF8C6A1E);
  static const Color goldPale = Color(0xFFF7EFDD);

  static const Color black = Color(0xFF0E0E0E);
  static const Color dark = Color(0xFF151515);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF2A2A2A);

  static const Color surface = Color(0xFFF5F5F7);
  static const Color white = Color(0xFFFFFFFF);
  static const Color cream = Color(0xFFF5F0E6);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFEEF0F3);

  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFF9FAFB);

  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color neutral = Color(0xFF9CA3AF);
  static const Color neutralBg = Color(0xFFF3F4F6);
  static const Color purple = Color(0xFF7C3AED);

  /// Platform brand colours (Routematic, MoveInSync, WhistleDrive, Uber for Business, Other).
  static const Map<String, Color> platform = {
    'ROUTEMATIC': Color(0xFF16A34A),
    'MOVEINSYNC': Color(0xFF2563EB),
    'WHISTLEDRIVE': Color(0xFFF59E0B),
    'UBER_BUSINESS': Color(0xFF111111),
    'OTHER': Color(0xFF9CA3AF),
  };

  static Color fromHex(String? hex, [Color fallback = neutral]) {
    if (hex == null || hex.isEmpty) return fallback;
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(v);
  }

  /// Colour for any status token used across the product.
  static Color status(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'ACTIVE':
      case 'CONFIRMED':
      case 'COMPLETED':
      case 'APPROVED':
      case 'VERIFIED':
      case 'ASSIGNED':
      case 'ON_TRIP':
      case 'ON TIME':
      case 'ONTIME':
      case 'PAID':
      case 'SETTLED':
      case 'FULLY_COMPLIANT':
      case 'OPEN':
      case 'SUBMITTED':
      case 'ACCEPTED':
        return success;
      case 'PENDING':
      case 'UNDER_REVIEW':
      case 'UNDER_VERIFICATION':
      case 'YET_TO_START':
      case 'SCHEDULED':
      case 'RESCHEDULED':
      case 'DUE_FOR_RENEWAL':
      case 'SENT':
      case 'DRAFT':
        return warning;
      case 'INACTIVE':
      case 'CANCELLED':
      case 'REJECTED':
      case 'BLACKLISTED':
      case 'DELAYED':
      case 'EXPIRED':
      case 'NON_COMPLIANT':
      case 'OVERDUE':
      case 'MISSING':
        return danger;
      case 'IN_PROGRESS':
      case 'PROCESSING':
        return info;
      default:
        return neutral;
    }
  }

  static Color statusBg(String? s) {
    final c = status(s);
    if (c == success) return successBg;
    if (c == warning) return warningBg;
    if (c == danger) return dangerBg;
    if (c == info) return infoBg;
    return neutralBg;
  }
}
