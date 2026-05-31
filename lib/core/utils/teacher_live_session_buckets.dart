import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/teacher_live_sessions_overview.dart';

/// Normalizes teacher live session lists into active / upcoming / completed buckets.
class TeacherLiveSessionBuckets {
  TeacherLiveSessionBuckets._();

  static bool isUpcoming(LiveSessionEntity s) {
    if (s.isActive) return true;
    if (s.isCompleted) return false;
    return !s.isScheduledPast;
  }

  static bool isCompletedBucket(LiveSessionEntity s) {
    if (s.isActive) return false;
    if (s.isCompleted) return true;
    return s.isScheduledPast;
  }

  /// Re-sorts all sessions by schedule date so mis-bucketed API rows still display correctly.
  static TeacherLiveSessionsOverview repartition(
    TeacherLiveSessionsOverview overview,
  ) {
    final all = [
      ...overview.activeNow,
      ...overview.upcoming,
      ...overview.completed,
    ];
    return _bucketAll(all, fromRemote: overview.fromRemote);
  }

  /// Adds sessions from class detail payloads that are missing from the teacher list API.
  static TeacherLiveSessionsOverview mergeMissing(
    TeacherLiveSessionsOverview overview,
    Iterable<LiveSessionEntity> extraSessions,
  ) {
    final known = <String>{
      ...overview.activeNow.map((s) => s.id),
      ...overview.upcoming.map((s) => s.id),
      ...overview.completed.map((s) => s.id),
    };
    final extras = <LiveSessionEntity>[];
    for (final s in extraSessions) {
      if (s.id.isEmpty || known.contains(s.id)) continue;
      known.add(s.id);
      extras.add(s);
    }
    if (extras.isEmpty) return overview;
    final all = [
      ...overview.activeNow,
      ...overview.upcoming,
      ...overview.completed,
      ...extras,
    ];
    return _bucketAll(all, fromRemote: overview.fromRemote);
  }

  static TeacherLiveSessionsOverview _bucketAll(
    List<LiveSessionEntity> all, {
    required bool fromRemote,
  }) {
    final seen = <String>{};
    final activeNow = <LiveSessionEntity>[];
    final upcoming = <LiveSessionEntity>[];
    final completed = <LiveSessionEntity>[];

    for (final s in all) {
      if (!seen.add(s.id)) continue;
      if (s.isActive) {
        activeNow.add(s);
      } else if (isCompletedBucket(s)) {
        completed.add(s);
      } else if (isUpcoming(s)) {
        upcoming.add(s);
      } else {
        completed.add(s);
      }
    }

    int compare(LiveSessionEntity a, LiveSessionEntity b) {
      final da = _dateTime(a);
      final db = _dateTime(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }

    activeNow.sort(compare);
    upcoming.sort(compare);
    completed.sort(compare);

    return TeacherLiveSessionsOverview(
      activeNow: activeNow,
      upcoming: upcoming,
      completed: completed,
      fromRemote: fromRemote,
    );
  }

  static DateTime? _dateTime(LiveSessionEntity s) {
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
}
