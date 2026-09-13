import 'package:intl/intl.dart';

class Fmt {
  Fmt._();
  static final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _inr2 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _num = NumberFormat.decimalPattern('en_IN');

  static String inr(num? v, {bool decimals = false}) => v == null ? '—' : (decimals ? _inr2 : _inr).format(v);
  static String number(num? v) => v == null ? '—' : _num.format(v);
  static String pct(num? v) => v == null ? '—' : '${v.round()}%';

  static DateTime? parse(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  static String date(dynamic v) { final d = parse(v); return d == null ? '—' : DateFormat('dd MMM yyyy').format(d); }
  static String dateShort(dynamic v) { final d = parse(v); return d == null ? '—' : DateFormat('dd MMM').format(d); }
  static String time(dynamic v) { final d = parse(v); return d == null ? '—' : DateFormat('hh:mm a').format(d); }
  static String dateTime(dynamic v) { final d = parse(v); return d == null ? '—' : DateFormat('dd MMM yyyy | hh:mm a').format(d); }
  static String dateTimeShort(dynamic v) { final d = parse(v); return d == null ? '—' : DateFormat('dd MMM yyyy hh:mm a').format(d); }
  static String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static String isoDateTime(DateTime d) => d.toUtc().toIso8601String();
  static String time24(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return '—';
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = p.length > 1 ? p[1] : '00';
    final ap = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2, '0')}:$m $ap';
  }

  static String ago(dynamic v) {
    final d = parse(v);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return date(d);
  }

  static String title(String? s) {
    if (s == null || s.isEmpty) return '—';
    return s.toLowerCase().split(RegExp(r'[_\s]+')).map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  static String vehicleType(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'SUV': return 'SUV';
      case 'TEMPO_TRAVELLER': return 'Tempo Traveller';
      default: return title(s);
    }
  }

  static String initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final p = name.trim().split(RegExp(r'\s+'));
    return (p.length == 1 ? p[0].substring(0, 1) : p[0][0] + p[1][0]).toUpperCase();
  }
}
