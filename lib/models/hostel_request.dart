enum HostelRequestStatus { pending, booked, rejected }

extension HostelRequestStatusX on HostelRequestStatus {
  String get displayLabel {
    switch (this) {
      case HostelRequestStatus.booked:
        return 'BOOKED';
      case HostelRequestStatus.rejected:
        return 'REJECTED';
      case HostelRequestStatus.pending:
        return 'PENDING';
    }
  }
}

class HostelRequest {
  final String id;
  final String studentId;
  final String studentName;
  final String hostelId;
  final String hostelName;
  final String location;
  final String adminId;
  final String adminName;
  /// Type requested by admin (Girls Hostel, Boys Hostel, etc.)
  final String hostelType;
  final String description;
  final DateTime requestedAt;
  HostelRequestStatus status;
  String? adminFeedback;
  String? ownerMessage;

  HostelRequest({
    required this.id,
    this.studentId = '',
    this.studentName = '',
    required this.hostelId,
    required this.hostelName,
    this.location = '',
    required this.adminId,
    this.adminName = 'Admin',
    required this.hostelType,
    this.description = '',
    required this.requestedAt,
    this.status = HostelRequestStatus.pending,
    this.adminFeedback,
    this.ownerMessage,
  });

  /// Warden asking admin to assign them to a hostel (no student involved).
  bool get isWardenAssignmentRequest =>
      studentId.trim().isEmpty && adminId.trim().isNotEmpty;

  /// Student asking to join a warden's hostel.
  bool get isStudentJoinRequest => studentId.trim().isNotEmpty;
}

class RoomAssignment {
  final String id;
  final String studentId;
  final String hostelId;
  final String floorId;
  final String roomId;
  final DateTime assignedAt;
  bool studentAccepted;

  RoomAssignment({
    required this.id,
    required this.studentId,
    required this.hostelId,
    required this.floorId,
    required this.roomId,
    required this.assignedAt,
    this.studentAccepted = false,
  });
}
