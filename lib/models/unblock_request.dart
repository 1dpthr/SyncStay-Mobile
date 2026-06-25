import 'student.dart';

enum UnblockRequestStatus { pending, approved, rejected }

extension UnblockRequestStatusX on UnblockRequestStatus {
  String get displayLabel {
    switch (this) {
      case UnblockRequestStatus.approved:
        return 'APPROVED';
      case UnblockRequestStatus.rejected:
        return 'REJECTED';
      case UnblockRequestStatus.pending:
        return 'PENDING';
    }
  }
}

class UnblockRequest {
  final String id;
  /// Blocked account id (student, warden, or owner email).
  final String studentId;
  final String studentName;
  final UserRole targetRole;
  final String message;
  final DateTime requestedAt;
  UnblockRequestStatus status;
  String? adminNote;

  UnblockRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.targetRole,
    required this.message,
    required this.requestedAt,
    this.status = UnblockRequestStatus.pending,
    this.adminNote,
  });
}
