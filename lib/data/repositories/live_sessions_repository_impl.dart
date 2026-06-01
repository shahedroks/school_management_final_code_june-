import 'package:high_school/data/datasources/mock_data.dart';
import 'package:high_school/data/datasources/student_classes_remote_datasource.dart';
import 'package:high_school/data/datasources/student_live_sessions_remote_datasource.dart';
import 'package:high_school/data/datasources/teacher_classes_remote_datasource.dart';
import 'package:high_school/data/datasources/teacher_live_sessions_remote_datasource.dart';
import 'package:high_school/core/utils/student_live_session_filters.dart';
import 'package:high_school/core/utils/teacher_live_session_buckets.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/student_live_sessions_overview.dart';
import 'package:high_school/domain/entities/teacher_live_sessions_overview.dart';
import 'package:high_school/domain/repositories/live_sessions_repository.dart';
import 'package:high_school/domain/repositories/student_dashboard_repository.dart';
import 'package:high_school/domain/repositories/teacher_dashboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveSessionsRepositoryImpl implements LiveSessionsRepository {
  LiveSessionsRepositoryImpl(
    SharedPreferences prefs, {
    TeacherDashboardRepository? teacherDashboard,
    StudentDashboardRepository? studentDashboard,
  })  : _studentSessions = StudentLiveSessionsRemoteDatasource(prefs),
        _teacherSessions = TeacherLiveSessionsRemoteDatasource(prefs),
        _teacherClasses = TeacherClassesRemoteDatasource(prefs),
        _studentClasses = StudentClassesRemoteDatasource(prefs),
        _teacherDashboard = teacherDashboard,
        _studentDashboard = studentDashboard;

  final StudentLiveSessionsRemoteDatasource _studentSessions;
  final TeacherLiveSessionsRemoteDatasource _teacherSessions;
  final TeacherClassesRemoteDatasource _teacherClasses;
  final StudentClassesRemoteDatasource _studentClasses;
  final TeacherDashboardRepository? _teacherDashboard;
  final StudentDashboardRepository? _studentDashboard;

  @override
  Future<List<LiveSessionEntity>> getLiveSessions() async =>
      MockData.liveSessions;

  @override
  Future<List<LiveSessionEntity>> getStudentLiveSessions({String? status}) async {
    if (_studentSessions.isConfigured) {
      return _studentSessions.getSessions(status: status);
    }
    return getLiveSessions();
  }

  @override
  Future<StudentLiveSessionsOverview> getStudentSessionsOverview() async {
    if (_studentSessions.isConfigured) {
      var all = await _studentSessions.fetchAllSessions();
      var overview = TeacherLiveSessionBuckets.repartition(
        TeacherLiveSessionsOverview(
          activeNow: const [],
          upcoming: all,
          completed: const [],
          fromRemote: true,
        ),
      );
      overview = await _mergeStudentClassDetailSessions(overview);
      overview = await _mergeStudentDashboardActiveSessions(overview);
      final active = overview.activeNow
          .where(StudentLiveSessionFilters.isVisibleToStudent)
          .toList();
      final upcoming = overview.upcoming
          .where(StudentLiveSessionFilters.isVisibleToStudent)
          .toList();
      return StudentLiveSessionsOverview(
        active: active,
        upcoming: upcoming,
        fromRemote: true,
      );
    }

    final mock = await getLiveSessions();
    return StudentLiveSessionsOverview(
      active: mock.where((s) => s.isActive).toList(),
      upcoming: mock
          .where((s) => !s.isActive && TeacherLiveSessionBuckets.isUpcoming(s))
          .toList(),
      fromRemote: false,
    );
  }

  @override
  Future<LiveSessionEntity?> getStudentLiveSessionById(String sessionId) async {
    if (_studentSessions.isConfigured) {
      return _studentSessions.getSessionById(sessionId);
    }
    try {
      return (await getLiveSessions()).firstWhere((s) => s.id == sessionId);
    } catch (_) {
      return null;
    }
  }

  Future<TeacherLiveSessionsOverview> _mergeStudentClassDetailSessions(
    TeacherLiveSessionsOverview overview,
  ) async {
    if (!_studentClasses.isConfigured) return overview;
    final classes = await _studentClasses.getStudentClasses();
    if (classes.isEmpty) return overview;

    final details = await Future.wait(
      classes.map((c) => _studentClasses.getStudentClassDetail(c.classId)),
    );

    final extras = <LiveSessionEntity>[];
    for (var i = 0; i < details.length; i++) {
      final detail = details[i];
      if (detail == null) continue;
      final cls = detail.classEntity;
      for (final s in detail.liveSessions) {
        extras.add(
          LiveSessionEntity(
            id: s.id,
            classId: s.classId.isNotEmpty ? s.classId : cls.id,
            title: s.title,
            date: s.date,
            time: s.time,
            platform: s.platform,
            link: s.link,
            isActive: s.isActive,
            className: s.className ?? cls.name,
            gradeLevel: s.gradeLevel ?? cls.level,
            subject: s.subject ?? cls.subject,
            durationMinutes: s.durationMinutes,
            status: s.status,
          ),
        );
      }
    }

    return TeacherLiveSessionBuckets.mergeMissing(overview, extras);
  }

  /// Dashboard can list live sessions before they appear in GET /sessions/student.
  Future<TeacherLiveSessionsOverview> _mergeStudentDashboardActiveSessions(
    TeacherLiveSessionsOverview overview,
  ) async {
    final dashboardRepo = _studentDashboard;
    if (dashboardRepo == null) return overview;
    final dashboard = await dashboardRepo.getDashboard();
    if (dashboard == null) return overview;

    final extras = <LiveSessionEntity>[];
    for (final row in dashboard.activeLiveSessions) {
      final entity = TeacherLiveSessionBuckets.entityFromStudentDashboardSession(row);
      if (entity != null) extras.add(entity);
    }
    if (extras.isEmpty) return overview;
    return TeacherLiveSessionBuckets.mergeMissing(overview, extras);
  }

  @override
  Future<TeacherLiveSessionsOverview> getTeacherSessionsOverview() async {
    if (_teacherSessions.isConfigured) {
      final remote = await _teacherSessions.fetchOverview();
      if (remote != null) {
        var overview = TeacherLiveSessionBuckets.repartition(remote);
        overview = await _mergeClassDetailSessions(overview);
        overview = await _mergeDashboardUpcomingSessions(overview);
        return overview;
      }
    }
    final all = await getLiveSessions();
    return TeacherLiveSessionsOverview(
      activeNow: all.where((s) => s.isActive).toList(),
      upcoming: all.where((s) => !s.isActive).toList(),
      completed: const [],
      fromRemote: false,
    );
  }

  /// Sessions created for a class sometimes appear only under GET /classes/:id
  /// (`liveSessionDetails`) and not in GET /sessions/teacher.
  Future<TeacherLiveSessionsOverview> _mergeClassDetailSessions(
    TeacherLiveSessionsOverview overview,
  ) async {
    if (!_teacherClasses.isConfigured) return overview;
    final classes = await _teacherClasses.getMyClasses();
    if (classes.isEmpty) return overview;

    final details = await Future.wait(
      classes.map((c) => _teacherClasses.getClassDetailById(c.id)),
    );

    final extras = <LiveSessionEntity>[];
    for (var i = 0; i < details.length; i++) {
      final detail = details[i];
      if (detail == null) continue;
      final cls = classes[i];
      for (final s in detail.liveSessions) {
        extras.add(
          LiveSessionEntity(
            id: s.id,
            classId: s.classId.isNotEmpty ? s.classId : cls.id,
            title: s.title,
            date: s.date,
            time: s.time,
            platform: s.platform,
            link: s.link,
            isActive: s.isActive,
            className: s.className ?? cls.name,
            gradeLevel: s.gradeLevel ?? cls.level,
            subject: s.subject ?? cls.subject,
            durationMinutes: s.durationMinutes,
            status: s.status,
          ),
        );
      }
    }

    return TeacherLiveSessionBuckets.mergeMissing(overview, extras);
  }

  /// Home dashboard can list sessions that are not yet in GET /sessions/teacher.
  Future<TeacherLiveSessionsOverview> _mergeDashboardUpcomingSessions(
    TeacherLiveSessionsOverview overview,
  ) async {
    final dashboardRepo = _teacherDashboard;
    if (dashboardRepo == null) return overview;
    final dashboard = await dashboardRepo.getDashboard();
    if (dashboard == null) return overview;

    final extras = <LiveSessionEntity>[];
    for (final row in dashboard.upcomingLiveSessions) {
      final entity = TeacherLiveSessionBuckets.entityFromDashboardSession(row);
      if (entity != null) extras.add(entity);
    }
    if (extras.isEmpty) return overview;
    return TeacherLiveSessionBuckets.mergeMissing(overview, extras);
  }

  @override
  bool get teacherSessionsApiConfigured => _teacherSessions.isConfigured;

  @override
  Future<CreateLiveSessionResult> createTeacherLiveSession({
    required String title,
    required String gradeId,
    required String subjectId,
    required String classId,
    required String className,
    required String date,
    required String time,
    required int duration,
    required String zoomLink,
  }) async {
    if (_teacherSessions.isConfigured) {
      return _teacherSessions.createSession(
        title: title,
        gradeId: gradeId,
        subjectId: subjectId,
        classId: classId,
        className: className,
        date: date,
        time: time,
        duration: duration,
        zoomLink: zoomLink,
      );
    }
    final link = zoomLink.trim();
    final isZoom = link.toLowerCase().contains('zoom');
    await addLiveSession(
      LiveSessionEntity(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        classId: classId,
        title: title.trim(),
        date: date.trim(),
        time: time.trim(),
        platform: isZoom ? LiveSessionPlatform.zoom : LiveSessionPlatform.meet,
        link: link,
        isActive: false,
        className: className.trim().isNotEmpty ? className.trim() : null,
        gradeLevel: null,
        subject: null,
        durationMinutes: duration,
      ),
    );
    return const CreateLiveSessionResult(success: true);
  }

  @override
  Future<CreateLiveSessionResult> updateTeacherLiveSession({
    required String sessionId,
    required String title,
    required String gradeId,
    required String subjectId,
    required String classId,
    required String className,
    required String date,
    required String time,
    required int duration,
    required String zoomLink,
  }) async {
    if (_teacherSessions.isConfigured) {
      return _teacherSessions.updateSession(
        sessionId: sessionId,
        title: title,
        gradeId: gradeId,
        subjectId: subjectId,
        classId: classId,
        className: className,
        date: date,
        time: time,
        duration: duration,
        zoomLink: zoomLink,
      );
    }
    final link = zoomLink.trim();
    final isZoom = link.toLowerCase().contains('zoom');
    final idx = MockData.liveSessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) {
      return const CreateLiveSessionResult(success: false, message: 'Session not found');
    }
    final prev = MockData.liveSessions[idx];
    MockData.liveSessions[idx] = LiveSessionEntity(
      id: prev.id,
      classId: classId.trim(),
      title: title.trim(),
      date: date.trim(),
      time: time.trim(),
      platform: isZoom ? LiveSessionPlatform.zoom : LiveSessionPlatform.meet,
      link: link,
      isActive: prev.isActive,
      className: className.trim().isNotEmpty ? className.trim() : null,
      gradeLevel: prev.gradeLevel,
      subject: prev.subject,
      durationMinutes: duration,
      status: prev.status,
    );
    return const CreateLiveSessionResult(success: true);
  }

  @override
  Future<bool> deleteTeacherLiveSession(String sessionId) async {
    if (_teacherSessions.isConfigured) {
      return _teacherSessions.deleteSession(sessionId);
    }
    final before = MockData.liveSessions.length;
    MockData.liveSessions.removeWhere((s) => s.id == sessionId);
    return MockData.liveSessions.length < before;
  }

  @override
  Future<void> addLiveSession(LiveSessionEntity session) async {
    MockData.liveSessions.add(session);
  }
}
