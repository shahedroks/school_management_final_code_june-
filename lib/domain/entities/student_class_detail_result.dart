import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:high_school/domain/entities/lesson_entity.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';

/// Result of GET /classes/student/:classId — class header plus embedded lessons and assignments.
class StudentClassDetailResult {
  const StudentClassDetailResult({
    required this.classEntity,
    required this.lessons,
    required this.assignments,
    this.liveSessions = const [],
  });

  final ClassEntity classEntity;
  final List<LessonEntity> lessons;
  final List<AssignmentEntity> assignments;
  final List<LiveSessionEntity> liveSessions;
}
