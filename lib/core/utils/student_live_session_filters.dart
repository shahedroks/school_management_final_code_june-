import 'package:high_school/core/utils/live_session_join_policy.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';

/// Which live sessions a student should see in lists.
class StudentLiveSessionFilters {
  StudentLiveSessionFilters._();

  static bool isVisibleToStudent(LiveSessionEntity s) {
    final st = _effectiveStatus(s);
    if (st == 'pending' ||
        st == 'rejected' ||
        st == 'draft' ||
        st == 'cancelled') {
      return false;
    }
    if (s.isCompleted) return false;
    final end = LiveSessionJoinPolicy.estimatedEnd(s);
    if (end != null &&
        DateTime.now().isAfter(end) &&
        !LiveSessionJoinPolicy.isSessionRunning(s)) {
      return false;
    }
    return true;
  }

  static String _effectiveStatus(LiveSessionEntity s) {
    return (s.status ?? '').toLowerCase().trim();
  }
}
