import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../utils/format.dart';

class TimelineStep {
  const TimelineStep({required this.title, this.subtitle, required this.state});
  final String title; final String? subtitle; final TimelineState state;
}

enum TimelineState { done, active, pending }

/// Vertical booking tracking timeline (Requirement Posted → … → Trip Completed).
class TrackingTimeline extends StatelessWidget {
  const TrackingTimeline({super.key, required this.steps});
  final List<TimelineStep> steps;

  /// Builds the standard 6-step ad-hoc lifecycle from trip events + status.
  static List<TimelineStep> fromTrip({required List<Map<String, dynamic>> events, required String status, String platformName = 'Platform', dynamic createdAt}) {
    DateTime? at(String type) { final e = events.where((x) => x['type'] == type).toList(); return e.isEmpty ? null : Fmt.parse(e.last['at']); }
    final cancelled = status == 'CANCELLED';
    final order = [
      ('Requirement Posted', 'REQUIREMENT_POSTED'), ('Vendor Assigned', 'VENDOR_ASSIGNED'), ('Driver Accepted', 'DRIVER_ACCEPTED'), ('Trip Created in $platformName', 'TRIP_CREATED_IN_PLATFORM'), ('Driver Started', 'DRIVER_STARTED'), ('Trip Completed', 'TRIP_COMPLETED'),
    ];
    final out = <TimelineStep>[];
    var reachedPending = false;
    for (final (title, type) in order) {
      var t = at(type);
      if (type == 'REQUIREMENT_POSTED' && t == null) t = Fmt.parse(createdAt);
      if (t != null && !reachedPending) { out.add(TimelineStep(title: title, subtitle: Fmt.dateTimeShort(t), state: TimelineState.done)); continue; }
      if (!reachedPending) {
        reachedPending = true;
        out.add(TimelineStep(title: title, subtitle: cancelled ? 'Cancelled' : 'In Progress', state: cancelled ? TimelineState.pending : TimelineState.active));
      } else {
        out.add(TimelineStep(title: title, subtitle: 'Pending', state: TimelineState.pending));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    for (var i = 0; i < steps.length; i++) _row(steps[i], i == steps.length - 1),
  ]);

  Widget _row(TimelineStep s, bool last) {
    final color = s.state == TimelineState.done ? GamyaColors.success : s.state == TimelineState.active ? GamyaColors.info : GamyaColors.textMuted;
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Column(children: [
        Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: s.state == TimelineState.pending ? Colors.white : color, border: Border.all(color: color, width: 2)), child: s.state == TimelineState.done ? const Icon(Icons.check, size: 14, color: Colors.white) : s.state == TimelineState.active ? const Icon(Icons.circle, size: 8, color: Colors.white) : null),
        if (!last) Expanded(child: Container(width: 2, color: s.state == TimelineState.done ? GamyaColors.success : GamyaColors.border)),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Padding(padding: EdgeInsets.only(bottom: last ? 0 : 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: s.state == TimelineState.pending ? GamyaColors.textMuted : GamyaColors.textPrimary)),
        if (s.subtitle != null) Text(s.subtitle!, style: TextStyle(fontSize: 12, color: s.state == TimelineState.active ? GamyaColors.info : GamyaColors.textSecondary)),
      ]))),
    ]));
  }
}
