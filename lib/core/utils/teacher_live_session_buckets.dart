import 'package:high_school/core/utils/live_session_join_policy.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/student_dashboard_entity.dart';
import 'package:high_school/domain/entities/teacher_dashboard_entity.dart';
import 'package:high_school/domain/entities/teacher_live_sessions_overview.dart';

/// Normalizes teacher live session lists into active / upcoming / completed buckets.
class TeacherLiveSessionBuckets {
  TeacherLiveSessionBuckets._();

  static bool isUpcoming(LiveSessionEntity s) {
    if (LiveSessionJoinPolicy.isSessionRunning(s)) return false;
    if (s.isCompleted) return false;
    return !s.isScheduledPast;
  }

  static bool isCompletedBucket(LiveSessionEntity s) {
    if (LiveSessionJoinPolicy.isSessionRunning(s)) return false;
    if (s.isCompleted) return true;
    final end = LiveSessionJoinPolicy.estimatedEnd(s);
    if (end != null && DateTime.now().isAfter(end)) return true;
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
      if (s.isActive || LiveSessionJoinPolicy.isSessionRunning(s)) {
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

  /// Maps GET /students/dashboard `activeLiveSessions` rows into [LiveSessionEntity].
  static LiveSessionEntity? entityFromStudentDashboardSession(
    StudentDashboardActiveSession s,
  ) {
    final id = s.id.trim();
    if (id.isEmpty) return null;
    final dateRaw = s.date.trim();
    var dateStr = dateRaw;
    if (dateRaw.length >= 10) dateStr = dateRaw.substring(0, 10);
    final link = s.zoomLink.trim();
    final isZoom = link.toLowerCase().contains('zoom');
    final st = s.status.toLowerCase().trim();
    final running = st == 'live' ||
        st == 'ongoing' ||
        st == 'active' ||
        st == 'started';
    return LiveSessionEntity(
      id: id,
      classId: '',
      title: s.title.trim().isEmpty ? 'Session' : s.title.trim(),
      date: dateStr,
      time: s.time.trim(),
      platform: isZoom ? LiveSessionPlatform.zoom : LiveSessionPlatform.meet,
      link: link,
      isActive: running,
      subject: s.subject.trim().isNotEmpty ? s.subject.trim() : null,
      status: st.isEmpty ? 'approved' : st,
    );
  }

  /// Maps GET /teachers/dashboard `upcomingLiveSessions` rows into [LiveSessionEntity].
  static LiveSessionEntity? entityFromDashboardSession(
    TeacherDashboardUpcomingSession s,
  ) {
    final id = s.id.trim();
    if (id.isEmpty) return null;
    final dateRaw = s.date?.trim() ?? '';
    var dateStr = dateRaw;
    if (dateRaw.length >= 10) dateStr = dateRaw.substring(0, 10);
    final link = s.zoomLink?.trim() ?? '';
    final isZoom = link.toLowerCase().contains('zoom');
    return LiveSessionEntity(
      id: id,
      classId: '',
      title: s.title.trim().isEmpty ? 'Session' : s.title.trim(),
      date: dateStr,
      time: s.time?.trim() ?? '',
      platform: isZoom ? LiveSessionPlatform.zoom : LiveSessionPlatform.meet,
      link: link,
      isActive: false,
      status: 'approved',
    );
  }

  /// Active + upcoming sessions for teacher home / lists (excludes completed/past).
  static List<LiveSessionEntity> upcomingAndActive(
    TeacherLiveSessionsOverview overview,
  ) {
    final seen = <String>{};
    final out = <LiveSessionEntity>[];
    for (final s in [...overview.activeNow, ...overview.upcoming]) {
      if (!isUpcoming(s)) continue;
      if (!seen.add(s.id)) continue;
      out.add(s);
    }
    out.sort((a, b) {
      final da = _dateTime(a);
      final db = _dateTime(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return out;
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
