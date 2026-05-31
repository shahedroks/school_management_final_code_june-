import 'package:high_school/domain/entities/live_session_entity.dart';

/// Shared parsing for live session objects from class detail / session list APIs.
class LiveSessionJsonParser {
  LiveSessionJsonParser._();

  static List<LiveSessionEntity> parseList(dynamic raw, {String fallbackClassId = ''}) {
    if (raw is! List) return [];
    final out = <LiveSessionEntity>[];
    for (final e in raw) {
      final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      final entity = parseItem(m, fallbackClassId: fallbackClassId);
      if (entity != null) out.add(entity);
    }
    return out;
  }

  static LiveSessionEntity? parseItem(
    Map<String, dynamic> m, {
    String fallbackClassId = '',
  }) {
    final id = _readDocumentId(m);
    if (id == null || id.isEmpty) return null;

    final title = m['title']?.toString() ?? 'Session';
    final dateRaw = m['date']?.toString() ?? '';
    var dateStr = dateRaw;
    if (dateRaw.length >= 10) dateStr = dateRaw.substring(0, 10);
    final time = m['time']?.toString() ?? '';
    final link = m['zoomLink']?.toString() ?? m['link']?.toString() ?? m['meetingLink']?.toString() ?? '';
    final statusStr = _resolveStatus(m);
    final isActive = statusStr == 'live' ||
        statusStr == 'ongoing' ||
        statusStr == 'active' ||
        statusStr == 'started';
    final platform = link.toLowerCase().contains('zoom')
        ? LiveSessionPlatform.zoom
        : LiveSessionPlatform.meet;
    var cid = m['classId']?.toString() ?? '';
    if (cid.isEmpty) cid = fallbackClassId;
    final cn = m['className']?.toString();
    final grade = m['grade']?.toString() ?? m['gradeLevel']?.toString();
    final subject = m['subject']?.toString();
    final dur = m['duration'];
    final durationMinutes = dur is int ? dur : int.tryParse(dur?.toString() ?? '');

    return LiveSessionEntity(
      id: id,
      classId: cid,
      title: title,
      date: dateStr,
      time: time,
      platform: platform,
      link: link,
      isActive: isActive,
      className: (cn == null || cn.isEmpty) ? null : cn,
      gradeLevel: (grade != null && grade.isNotEmpty) ? grade : null,
      subject: (subject != null && subject.isNotEmpty) ? subject : null,
      durationMinutes: durationMinutes,
      status: statusStr.isEmpty ? null : statusStr,
    );
  }

  static String? _readDocumentId(Map<String, dynamic> m) {
    dynamic raw = m['_id'] ?? m['id'];
    if (raw == null) return null;
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? null : s;
    }
    if (raw is int || raw is double) return raw.toString();
    if (raw is Map) {
      final oid = raw[r'$oid'] ?? raw['\$oid'] ?? raw['oid'];
      if (oid != null) {
        final s = oid.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String _resolveStatus(Map<String, dynamic> m) {
    final status = (m['status']?.toString() ?? '').toLowerCase().trim();
    if (status.isNotEmpty) return status;

    final approval = m['approvalStatus'];
    if (approval is Map) {
      final s = (approval['status'] ?? approval['name'] ?? approval['label'])
          ?.toString()
          .toLowerCase()
          .trim();
      if (s != null && s.isNotEmpty) return s;
    }
    if (approval != null) {
      final s = approval.toString().toLowerCase().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }
}
