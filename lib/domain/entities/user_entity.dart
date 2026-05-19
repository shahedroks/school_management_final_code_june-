enum UserRole { student, teacher }

class UserEntity {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? avatar;
  final String? grade;
  final String? subject;
  final List<String>? enrolledClassIds;
  /// Raw phone from API (for OTP redirect). Optional for legacy/mock users.
  final String? phone;
  /// From API `phoneVerified` (informational; does not block app access).
  final bool phoneVerified;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatar,
    this.grade,
    this.subject,
    this.enrolledClassIds,
    this.phone,
    this.phoneVerified = true,
  });
}
