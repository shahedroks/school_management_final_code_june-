import 'dart:convert';

import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/data/datasources/live_session_json_parser.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// GET /sessions/student?status=... — student live sessions.
class StudentLiveSessionsRemoteDatasource {
  StudentLiveSessionsRemoteDatasource(this._prefs)
      : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  /// Fetches sessions for one status filter, or all when [status] is null/empty.
  Future<List<LiveSessionEntity>> getSessions({String? status}) async {
    if (!isConfigured) return [];
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return [];

    var path = '$_apiBase/sessions/student';
    if (status != null && status.isNotEmpty) {
      path += '?status=$status';
    }
    final uri = Uri.parse(path);
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) return [];
    try {
      var rawBody = response.body;
      if (rawBody.isNotEmpty && rawBody.codeUnitAt(0) == 0xFEFF) {
        rawBody = rawBody.substring(1);
      }
      final decoded = jsonDecode(rawBody) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      return _parseList(rawBody);
    } on UnauthorizedApiException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Tries unfiltered list first, then common status query values.
  Future<List<LiveSessionEntity>> fetchAllSessions() async {
    final seen = <String>{};
    final merged = <LiveSessionEntity>[];

    void addAll(List<LiveSessionEntity> batch) {
      for (final s in batch) {
        if (s.id.isEmpty || !seen.add(s.id)) continue;
        merged.add(s);
      }
    }

    addAll(await getSessions());
    for (final status in const [
      'approved',
      'ongoing',
      'active',
      'live',
      'scheduled',
      'upcoming',
    ]) {
      addAll(await getSessions(status: status));
    }
    return merged;
  }

  /// GET /sessions/student/:id — single session with meeting link when allowed.
  Future<LiveSessionEntity?> getSessionById(String sessionId) async {
    if (!isConfigured || sessionId.trim().isEmpty) return null;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse('$_apiBase/sessions/student/${sessionId.trim()}');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) return null;
    try {
      var rawBody = response.body;
      if (rawBody.isNotEmpty && rawBody.codeUnitAt(0) == 0xFEFF) {
        rawBody = rawBody.substring(1);
      }
      final decoded = jsonDecode(rawBody) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      final data = decoded?['data'];
      if (data is! Map) return null;
      return LiveSessionJsonParser.parseItem(Map<String, dynamic>.from(data));
    } on UnauthorizedApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  List<LiveSessionEntity> _parseList(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>?;
      if (decoded == null) return [];
      final list = _extractSessionList(decoded['data']);
      if (list == null) return [];
      return list
          .map((e) => LiveSessionJsonParser.parseItem(
                e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
              ))
          .whereType<LiveSessionEntity>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<dynamic>? _extractSessionList(dynamic data) {
    if (data == null) return null;
    if (data is List) return data;
    if (data is String && data.trim().isNotEmpty) {
      try {
        return _extractSessionList(jsonDecode(data));
      } catch (_) {
        return null;
      }
    }
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      for (final key in const [
        'sessions',
        'data',
        'items',
        'upcoming',
        'activeNow',
        'ongoing',
      ]) {
        final nested = _extractSessionList(m[key]);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    }
    return null;
  }
}
