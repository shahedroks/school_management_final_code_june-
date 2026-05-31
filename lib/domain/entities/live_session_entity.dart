enum LiveSessionPlatform { zoom, meet }

class LiveSessionEntity {
  final String id;
  final String classId;
  final String title;
  final String date;
  final String time;
  final LiveSessionPlatform platform;
  final String link;
  final bool isActive;
  /// From API: e.g. "5th Grade - English A". Used for upcoming card when set.
  final String? className;

  /// From teacher sessions API (`grade`).
  final String? gradeLevel;

  /// From teacher sessions API (`subject`).
  final String? subject;

  /// Scheduled duration in minutes (`duration` from API).
  final int? durationMinutes;

  /// Raw API status, e.g. `approved`, `ongoing`, `completed`.
  final String? status;

  const LiveSessionEntity({
    required this.id,
    required this.classId,
    required this.title,
    required this.date,
    required this.time,
    required this.platform,
    required this.link,
    required this.isActive,
    this.className,
    this.gradeLevel,
    this.subject,
    this.durationMinutes,
    this.status,
  });

  bool get isCompleted {
    final st = (status ?? '').toLowerCase().trim();
    return st == 'completed' || st == 'ended' || st == 'cancelled';
  }

  /// True when the scheduled date/time is already in the past (local time).
  bool get isScheduledPast {
    if (date.trim().length < 10) return false;
    try {
      final datePart = date.trim().substring(0, 10);
      final hm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time.trim());
      if (hm == null) return false;
      final parts = datePart.split('-');
      if (parts.length != 3) return false;
      final scheduled = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        int.parse(hm.group(1)!),
        int.parse(hm.group(2)!),
      );
      return scheduled.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// Teacher can edit/delete only upcoming, non-live sessions.
  bool get canManage => !isActive && !isCompleted && !isScheduledPast;
}
