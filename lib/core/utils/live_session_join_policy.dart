import 'package:high_school/core/utils/app_date_format.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';

/// When a student may open the Zoom/Meet link for a live session.
class LiveSessionJoinPolicy {
  LiveSessionJoinPolicy._();

  static const defaultMinutesBefore = 5;

  static DateTime? scheduledStart(LiveSessionEntity s) {
    final dateRaw = s.date.trim();
    if (dateRaw.length < 10) return null;
    final hm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s.time.trim());
    if (hm == null) return DateTime.tryParse(dateRaw.substring(0, 10));
    final parts = dateRaw.substring(0, 10).split('-');
    if (parts.length != 3) return null;
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      int.parse(hm.group(1)!),
      int.parse(hm.group(2)!),
    );
  }

  static DateTime? joinOpensAt(
    LiveSessionEntity s, {
    int minutesBefore = defaultMinutesBefore,
  }) {
    final start = scheduledStart(s);
    if (start == null) return null;
    return start.subtract(Duration(minutes: minutesBefore));
  }

  static DateTime? estimatedEnd(LiveSessionEntity s) {
    final start = scheduledStart(s);
    if (start == null) return null;
    final dur = s.durationMinutes ?? 90;
    return start.add(Duration(minutes: dur));
  }

  /// True when the student should see an enabled Join button.
  static bool canJoinNow(
    LiveSessionEntity s, {
    int minutesBefore = defaultMinutesBefore,
  }) {
    if (s.isCompleted) return false;
    if (s.isActive) return s.link.trim().isNotEmpty;

    final start = scheduledStart(s);
    if (start == null) return false;

    final now = DateTime.now();
    final openAt = start.subtract(Duration(minutes: minutesBefore));
    final endAt = estimatedEnd(s) ?? start.add(const Duration(hours: 2));

    if (now.isBefore(openAt)) return false;
    if (now.isAfter(endAt)) return false;
    return s.link.trim().isNotEmpty;
  }

  /// Human-readable hint when join is not open yet.
  static String joinOpensHint(LiveSessionEntity s, {int minutesBefore = defaultMinutesBefore}) {
    final openAt = joinOpensAt(s, minutesBefore: minutesBefore);
    if (openAt == null) return '';
    final datePart = AppDateFormat.date(openAt);
    final timePart = AppDateFormat.time(openAt);
    if (datePart.isEmpty) return '';
    return timePart.isEmpty ? datePart : '$datePart, $timePart';
  }
}
