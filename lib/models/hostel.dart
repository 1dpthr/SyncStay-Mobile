import 'room.dart';

enum HostelApprovalStatus { pending, approved, rejected }

extension HostelApprovalStatusX on HostelApprovalStatus {
  String get displayLabel {
    switch (this) {
      case HostelApprovalStatus.pending:
        return 'PENDING';
      case HostelApprovalStatus.approved:
        return 'APPROVED';
      case HostelApprovalStatus.rejected:
        return 'REJECTED';
    }
  }
}

class Hostel {
  final String id;
  final String hostelName;
  final String location;
  final int totalFloors;
  final int totalRooms;
  String createdByOwner;
  /// Assigned warden (stored as assignedAdminId in Firestore for backward compatibility).
  String? assignedAdminId;
  /// Set when admin approves a warden assignment (e.g. Girls Hostel, Boys Hostel).
  String? assignedType;
  final DateTime createdAt;
  final List<Floor> floors;
  HostelApprovalStatus approvalStatus;
  String? hostelImageUrl;
  String? paperImageUrl;
  String? hostelImageBase64;
  String? paperImageBase64;
  double rentPerMonth;
  String? rejectionReason;

  Hostel({
    required this.id,
    required this.hostelName,
    required this.location,
    required this.totalFloors,
    required this.totalRooms,
    required this.createdByOwner,
    this.assignedAdminId,
    this.assignedType,
    required this.createdAt,
    required this.floors,
    this.approvalStatus = HostelApprovalStatus.approved,
    this.hostelImageUrl,
    this.paperImageUrl,
    this.hostelImageBase64,
    this.paperImageBase64,
    this.rentPerMonth = 0,
    this.rejectionReason,
  });

  String? get assignedWardenId => assignedAdminId;

  set assignedWardenId(String? id) => assignedAdminId = id;

  bool get isBooked => assignedAdminId != null;

  bool get isApproved => approvalStatus == HostelApprovalStatus.approved;

  /// Available for warden to request (approved by platform admin and not yet booked).
  bool get isAvailableForWarden => isApproved && !isBooked;

  String get availabilityLabel {
    if (!isApproved) return approvalStatus.displayLabel;
    if (isBooked) return 'BOOKED';
    return 'AVAILABLE';
  }
}

class Floor {
  final String id;
  final int floorNumber;
  final List<Room> rooms;

  Floor({
    required this.id,
    required this.floorNumber,
    required this.rooms,
  });
}
