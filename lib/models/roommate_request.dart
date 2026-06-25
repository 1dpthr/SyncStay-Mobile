import 'student.dart';

enum RequestStatus {
  pending,
  accepted,
  rejected,
}

enum RequestType {
  roommate,
  skillShare,
}

enum AdminStatus {
  pending,
  approved,
  rejected,
}

class RoommateRequest {
  String id;
  String senderId;
  String receiverId;
  String senderName;
  String receiverName;
  RequestStatus status;
  AdminStatus adminStatus;
  RequestType type;
  DateTime createdAt;
  DateTime? respondedAt;
  double compatibilityScore; 
  String? skillName; // Only used for skillShare type
  bool notificationRead;
  bool isMatched;

  RoommateRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.receiverName,
    this.status = RequestStatus.pending,
    this.adminStatus = AdminStatus.pending,
    this.type = RequestType.roommate,
    DateTime? createdAt,
    this.respondedAt,
    this.compatibilityScore = 0.0,
    this.skillName,
    this.notificationRead = false,
    this.isMatched = false,
  }) : createdAt = createdAt ?? DateTime.now();
}
