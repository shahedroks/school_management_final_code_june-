import 'dart:convert';
import 'dart:io';

import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/network/api_response_helper.dart';
import 'package:high_school/domain/entities/assignment_detail_result.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/entities/class_entity.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentAssignmentDetailsRemoteDatasource {
  StudentAssignmentDetailsRemoteDatasource(this._prefs)
      : _baseUrl = AppConstants.apiBaseUrl;

  final SharedPreferences _prefs;
  final String _baseUrl;

  String get _apiBase =>
      _baseUrl.endsWith('/') ? '${_baseUrl}api/v1' : '$_baseUrl/api/v1';

  bool get isConfigured => _baseUrl.isNotEmpty;

  /// POST /submission/:assignmentId/submit (Student, multipart/form-data).
  /// Sends the student's submission (optional text answer and optional file).
  Future<({bool ok, String? message})> submitAssignment({
    required String assignmentId,
    String? textAnswer,
    String? filePath,
  }) async {
    if (!isConfigured) return (ok: false, message: 'API not configured');
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return (ok: false, message: 'Not signed in');

    final uri = Uri.parse('$_apiBase/submission/$assignmentId/submit');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    if (textAnswer != null && textAnswer.trim().isNotEmpty) {
      request.fields['textAnswer'] = textAnswer.trim();
    }
    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        final filename = _basename(file.path);
        final contentType = _mediaTypeForFilename(filename);
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            filename: filename,
            contentType: contentType,
          ),
        );
      }
    }

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final raw = response.body.trim();

      Map<String, dynamic>? decoded;
      if (raw.isNotEmpty) {
        try {
          final j = jsonDecode(response.body);
          if (j is Map<String, dynamic>) {
            decoded = j;
          } else if (j is Map) {
            decoded = Map<String, dynamic>.from(j);
          }
        } catch (_) {
          decoded = null;
        }
      }
      if (decoded != null) ensureAuthorized(decoded);

      final code = response.statusCode;
      if (code == 200 || code == 201) {
        final success = decoded?['success'] == true ||
            decoded?['success'] == 1 ||
            (decoded?['status']?.toString().toLowerCase() == 'success');
        if (success) return (ok: true, message: null);
      }

      final msg = decoded?['message']?.toString() ??
          (raw.isNotEmpty ? raw : 'Request failed ($code)');
      return (ok: false, message: msg);
    } on UnauthorizedApiException {
      return (ok: false, message: 'Unauthorized');
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  /// GET /assignments/:assignmentId (Student). Returns null if not configured, unauthorized, or error.
  Future<AssignmentDetailResult?> getAssignmentDetail(String assignmentId) async {
    if (!isConfigured) return null;
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    if (token == null || token.isEmpty) return null;
    final uri = Uri.parse('$_apiBase/assignments/$assignmentId');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) return null;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      ensureAuthorized(decoded);
      return _parse(decoded);
    } on UnauthorizedApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  AssignmentDetailResult? _parse(Map<String, dynamic>? decoded) {
    if (decoded == null) return null;
    final success = decoded['success'];
    if (success != true) return null;
    final data = decoded['data'];
    if (data == null || data is! Map<String, dynamic>) return null;
    final assignmentJson = data['assignment'];
    if (assignmentJson == null || assignmentJson is! Map<String, dynamic>) return null;
    final submissionJson = data['submission'];

    AssignmentEntity assignment = _assignmentFromJson(assignmentJson);
    final classInfo = _classInfoFromJson(
      assignmentJson['classInfo'],
      assignment.classId,
    );
    bool hasSubmission = false;
    String? submittedAt;
    String? submissionFileUrl;
    String? submissionFileName;
    String? submissionType;
    String submissionStatus = '';
    int? submissionScore;
    String? submissionFeedback;
    if (submissionJson != null && submissionJson is Map<String, dynamic>) {
      hasSubmission = true;
      submittedAt = submissionJson['submittedAt']?.toString();
      submissionType = submissionJson['submissionType']?.toString();
      submissionStatus = (submissionJson['status']?.toString() ?? '').toLowerCase();
      final file = submissionJson['file'];
      if (file is Map<String, dynamic>) {
        submissionFileUrl = file['url']?.toString();
        submissionFileName = file['originalName']?.toString();
      }
      final gradeRaw = submissionJson['grade'];
      if (gradeRaw is Map) {
        final gm = Map<String, dynamic>.from(gradeRaw);
        submissionScore = _parseScore(gm['score']);
        final fb = gm['feedback']?.toString();
        if (fb != null && fb.isNotEmpty) submissionFeedback = fb;
      } else if (gradeRaw != null) {
        submissionScore = _parseScore(gradeRaw);
      }
      submissionScore ??= _parseScore(submissionJson['score']);
      submissionFeedback ??= submissionJson['feedback']?.toString();
    }
    if (hasSubmission && submissionStatus == 'graded') {
      assignment = AssignmentEntity(
        id: assignment.id,
        classId: assignment.classId,
        title: assignment.title,
        description: assignment.description,
        dueDate: assignment.dueDate,
        points: assignment.points,
        status: AssignmentStatus.graded,
        grade: submissionScore ?? assignment.grade,
        feedback: submissionFeedback ?? assignment.feedback,
        submissions: assignment.submissions,
        attachments: assignment.attachments,
      );
    } else if (hasSubmission) {
      assignment = AssignmentEntity(
        id: assignment.id,
        classId: assignment.classId,
        title: assignment.title,
        description: assignment.description,
        dueDate: assignment.dueDate,
        points: assignment.points,
        status: AssignmentStatus.submitted,
        grade: assignment.grade,
        feedback: assignment.feedback,
        submissions: assignment.submissions,
        attachments: assignment.attachments,
      );
    }

    return AssignmentDetailResult(
      assignment: assignment,
      classInfo: classInfo,
      hasSubmission: hasSubmission,
      submittedAt: submittedAt,
      submissionFileUrl: submissionFileUrl,
      submissionFileName: submissionFileName,
      submissionType: submissionType,
    );
  }

  AssignmentEntity _assignmentFromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? '';
    final classId = json['classId']?.toString() ?? '';
    final title = json['title']?.toString() ?? '';
    final description = json['description']?.toString() ?? '';
    final dueAt = json['dueAt']?.toString() ?? '';
    final points = _toInt(json['points']);
    final statusStr = (json['status']?.toString() ?? 'active').toLowerCase();
    AssignmentStatus status = AssignmentStatus.pending;
    if (statusStr == 'submitted') status = AssignmentStatus.submitted;
    if (statusStr == 'graded') status = AssignmentStatus.graded;
    final attachments = _attachmentsFromJson(json['attachments']);
    return AssignmentEntity(
      id: id,
      classId: classId,
      title: title,
      description: description,
      dueDate: dueAt,
      points: points,
      status: status,
      grade: null,
      feedback: null,
      submissions: null,
      attachments: attachments.isEmpty ? null : attachments,
    );
  }

  static List<AssignmentAttachmentEntity> _attachmentsFromJson(dynamic attRaw) {
    final attachments = <AssignmentAttachmentEntity>[];
    if (attRaw is! List) return attachments;
    for (final e in attRaw) {
      if (e is! Map) continue;
      final em = Map<String, dynamic>.from(e);
      final url = em['url']?.toString();
      final name = em['originalName']?.toString() ?? 'file';
      final sz = em['size'];
      attachments.add(
        AssignmentAttachmentEntity(
          originalName: name,
          mimeType: em['mimeType']?.toString(),
          size: sz is int ? sz : int.tryParse(sz?.toString() ?? ''),
          url: url != null && url.isNotEmpty ? url : null,
        ),
      );
    }
    return attachments;
  }

  ClassEntity? _classInfoFromJson(dynamic classInfoJson, String classId) {
    if (classInfoJson == null || classInfoJson is! Map<String, dynamic>) return null;
    final gradeLevel = classInfoJson['gradeLevel']?.toString() ?? '';
    final subject = classInfoJson['subject']?.toString() ?? '';
    final teacher = classInfoJson['teacher']?.toString() ?? '';
    final name = gradeLevel.isNotEmpty && subject.isNotEmpty
        ? '$gradeLevel - $subject'
        : (subject.isNotEmpty ? subject : 'Class');
    return ClassEntity(
      id: classId,
      name: name,
      subject: subject,
      category: '',
      teacher: teacher,
      teacherId: teacher,
      students: 0,
      color: '',
      schedule: '',
      room: '',
      level: gradeLevel,
      schoolYear: '',
      gradeId: classInfoJson['gradeId']?.toString(),
      subjectId: classInfoJson['subjectId']?.toString(),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static int? _parseScore(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  static String _basename(String path) {
    final i = path.replaceAll('\\', '/').lastIndexOf('/');
    return i >= 0 ? path.substring(i + 1) : path;
  }

  /// Backend validates allowed types from the part Content-Type (not only extension).
  static MediaType _mediaTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.doc')) return MediaType('application', 'msword');
    if (lower.endsWith('.docx')) {
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    }
    if (lower.endsWith('.txt')) return MediaType('text', 'plain');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.mp4')) return MediaType('video', 'mp4');
    if (lower.endsWith('.webm')) return MediaType('video', 'webm');
    return MediaType('application', 'octet-stream');
  }
}
