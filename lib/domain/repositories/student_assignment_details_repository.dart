import 'package:high_school/domain/entities/assignment_detail_result.dart';
import 'package:high_school/domain/entities/my_submission_status.dart';

abstract class StudentAssignmentDetailsRepository {
  /// Fetches assignment detail (and current student's submission if any) from API.
  /// Returns null if API is not configured or request fails.
  Future<AssignmentDetailResult?> getAssignmentDetail(String assignmentId);

  /// Fetches the resubmit-aware status for the current student.
  /// Returns null on failure (network / unauthorized).
  Future<MySubmissionStatus?> getMySubmission(String assignmentId);

  /// Submits the current student's assignment answer to the API.
  /// On failure, [SubmitResult.errorKind] categorises the cause so the UI
  /// can refresh & show a friendly message (already graded / closed / late).
  Future<SubmitResult> submitAssignment(
    String assignmentId, {
    String? textAnswer,
    String? filePath,
  });
}
