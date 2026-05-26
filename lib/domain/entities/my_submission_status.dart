/// Detailed student submission payload from
/// `GET /submissions/assignments/:assignmentId/submission/me`.
class StudentSubmission {
  const StudentSubmission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.submissionType,
    this.fileOriginalName,
    this.fileMimeType,
    this.fileSize,
    this.fileStorageKey,
    this.fileUrl,
    this.textAnswer,
    this.submittedAt,
    required this.status,
    this.gradeScore,
    this.gradeFeedback,
    this.gradedBy,
    this.gradedAt,
  });

  final String id;
  final String assignmentId;
  final String studentId;
  /// `file` or `text`.
  final String submissionType;
  final String? fileOriginalName;
  final String? fileMimeType;
  final int? fileSize;
  final String? fileStorageKey;
  final String? fileUrl;
  final String? textAnswer;
  final DateTime? submittedAt;
  /// `pending`, `submitted`, or `graded`.
  final String status;
  final int? gradeScore;
  final String? gradeFeedback;
  final String? gradedBy;
  final DateTime? gradedAt;

  bool get isGraded => status.toLowerCase() == 'graded';
}

/// Response of `GET /submissions/assignments/:assignmentId/submission/me`.
class MySubmissionStatus {
  const MySubmissionStatus({
    this.submission,
    required this.isGraded,
    required this.canResubmit,
    required this.assignmentStatus,
    this.dueAt,
    required this.lateAllowed,
  });

  final StudentSubmission? submission;
  final bool isGraded;
  final bool canResubmit;
  /// `open` or `closed`.
  final String assignmentStatus;
  final DateTime? dueAt;
  final bool lateAllowed;

  bool get isClosed => assignmentStatus.toLowerCase() == 'closed';

  bool get isPastDue {
    final d = dueAt;
    if (d == null) return false;
    return DateTime.now().isAfter(d);
  }
}

/// Categorised reason a submit/resubmit call failed (parsed from the API
/// message). UI uses this to pick the right snackbar text and behaviour.
enum SubmitErrorKind {
  alreadyGraded,
  assignmentClosed,
  lateNotAllowed,
  unauthorized,
  other,
}

class SubmitResult {
  const SubmitResult({required this.ok, this.message, this.errorKind});

  final bool ok;
  final String? message;
  final SubmitErrorKind? errorKind;

  static SubmitResult success() => const SubmitResult(ok: true);

  static SubmitResult failure(String? message, [SubmitErrorKind? kind]) =>
      SubmitResult(ok: false, message: message, errorKind: kind);
}
