import '../entities/live_session_entity.dart';
import '../entities/student_live_sessions_overview.dart';
import '../entities/teacher_live_sessions_overview.dart';

abstract class LiveSessionsRepository {
  Future<List<LiveSessionEntity>> getLiveSessions();
  /// Student: GET /sessions/student?status=approved (or status=ongoing). Returns API data when configured.
  Future<List<LiveSessionEntity>> getStudentLiveSessions({String? status});
  /// Student: active + upcoming buckets from sessions API and enrolled class details.
  Future<StudentLiveSessionsOverview> getStudentSessionsOverview();
  /// GET /sessions/student/:id when API configured.
  Future<LiveSessionEntity?> getStudentLiveSessionById(String sessionId);
  /// Teacher: GET /sessions/teacher when API configured; otherwise mock split (no completed list).
  Future<TeacherLiveSessionsOverview> getTeacherSessionsOverview();
  /// True when teacher session list/create can use the remote API ([AppConstants.apiBaseUrl] + token).
  bool get teacherSessionsApiConfigured;
  /// POST /sessions when API configured; otherwise appends to mock list.
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
  });
  /// PUT /sessions/:id when API configured; otherwise updates mock list.
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
  });
  /// DELETE /sessions/:id when API configured; otherwise removes from mock list.
  Future<bool> deleteTeacherLiveSession(String sessionId);
  Future<void> addLiveSession(LiveSessionEntity session);
}
