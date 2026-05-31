import 'package:high_school/domain/entities/live_session_entity.dart';

/// Active + upcoming live sessions for the student Live Sessions screen.
class StudentLiveSessionsOverview {
  const StudentLiveSessionsOverview({
    required this.active,
    required this.upcoming,
    this.fromRemote = false,
  });

  final List<LiveSessionEntity> active;
  final List<LiveSessionEntity> upcoming;
  final bool fromRemote;
}
