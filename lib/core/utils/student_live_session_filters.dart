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
    if (s.isCompleted && !s.isActive) return false;
    return true;
  }

  static String _effectiveStatus(LiveSessionEntity s) {
    return (s.status ?? '').toLowerCase().trim();
  }
}
