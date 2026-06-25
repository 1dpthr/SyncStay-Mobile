import 'package:cloud_firestore/cloud_firestore.dart';

import 'hostel.dart';
import 'hostel_request.dart';
import 'hostel_review.dart';
import 'notification.dart';
import 'payment.dart';
import 'room.dart';
import 'roommate_request.dart';
import 'student.dart';
import 'unblock_request.dart';

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.parse(value);
  return DateTime.now();
}

Timestamp _writeDate(DateTime value) => Timestamp.fromDate(value);

// ── Student ────────────────────────────────────────────────────────────────

Map<String, dynamic> studentToMap(Student s) => {
      'studentId': s.studentId,
      'name': s.name,
      'email': s.email,
      'phoneNumber': s.phoneNumber,
      'age': s.age,
      'gender': s.gender,
      'department': s.department,
      'role': s.role.name,
      'managedByOwnerId': s.managedByOwnerId,
      'createdByAdmin': s.createdByAdmin,
      'skills': s.skills,
      'learningSkills': s.learningSkills,
      'otherSkills': s.otherSkills,
      'budget': s.budget,
      'preferredLocation': s.preferredLocation,
      'requiresAC': s.requiresAC,
      'requiresAttachedBath': s.requiresAttachedBath,
      'requiresWifi': s.requiresWifi,
      'requiresFurnished': s.requiresFurnished,
      'requiresKitchen': s.requiresKitchen,
      'requiresLaundry': s.requiresLaundry,
      'preferredSharing': s.preferredSharing,
      'occupation': s.occupation,
      'foodPreference': s.foodPreference,
      'introvertExtrovert': s.introvertExtrovert,
      'studyEnvironment': s.studyEnvironment,
      'genderPreference': s.genderPreference,
      'guestPreference': s.guestPreference,
      'studyHoursPerDay': s.studyHoursPerDay,
      'noiseTolerance': s.noiseTolerance,
      'guestPolicy': s.guestPolicy,
      'drinker': s.drinker,
      'smoker': s.smoker,
      'cleanlinessLevel': s.cleanlinessLevel,
      'sleepSchedule': s.sleepSchedule,
      'favoriteStudentIds': s.favoriteStudentIds,
      'blockedStudentIds': s.blockedStudentIds,
      'isOnline': s.isOnline,
      'assignedRoomId': s.assignedRoomId,
      'requestedRoomId': s.requestedRoomId,
      'roommateId': s.roommateId,
      'profileCompleted': s.profileCompleted,
      'quizCompleted': s.quizCompleted,
      'paymentVerified': s.paymentVerified,
      'assignmentStatus': s.assignmentStatus.name,
      'isAccountBlocked': s.isAccountBlocked,
      'blockReason': s.blockReason,
      'blockedAt': s.blockedAt != null ? _writeDate(s.blockedAt!) : null,
      'lastLeftRoomId': s.lastLeftRoomId,
    };

Student studentFromMap(Map<String, dynamic> data) => Student(
      studentId: data['studentId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      gender: data['gender'] as String? ?? '',
      department: data['department'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.student,
      ),
      managedByOwnerId: data['managedByOwnerId'] as String?,
      createdByAdmin: data['createdByAdmin'] as bool? ?? false,
      skills: List<String>.from(data['skills'] ?? []),
      learningSkills: List<String>.from(data['learningSkills'] ?? []),
      otherSkills: data['otherSkills'] as String? ?? '',
      budget: (data['budget'] as num?)?.toDouble() ?? 10000.0,
      preferredLocation: data['preferredLocation'] as String? ?? 'Main Campus',
      requiresAC: data['requiresAC'] as bool? ?? false,
      requiresAttachedBath: data['requiresAttachedBath'] as bool? ?? false,
      requiresWifi: data['requiresWifi'] as bool? ?? false,
      requiresFurnished: data['requiresFurnished'] as bool? ?? false,
      requiresKitchen: data['requiresKitchen'] as bool? ?? false,
      requiresLaundry: data['requiresLaundry'] as bool? ?? false,
      preferredSharing: data['preferredSharing'] as String? ?? 'Double',
      occupation: data['occupation'] as String? ?? 'Student',
      foodPreference: data['foodPreference'] as String? ?? 'Any',
      introvertExtrovert: data['introvertExtrovert'] as String? ?? 'Ambivert',
      studyEnvironment: data['studyEnvironment'] as String? ?? 'Social',
      genderPreference: data['genderPreference'] as String? ?? 'Any',
      guestPreference: data['guestPreference'] as String? ?? 'Sometimes',
      studyHoursPerDay: (data['studyHoursPerDay'] as num?)?.toDouble() ?? 2.0,
      noiseTolerance: (data['noiseTolerance'] as num?)?.toInt() ?? 5,
      guestPolicy: data['guestPolicy'] as String? ?? 'Sometimes',
      drinker: data['drinker'] as bool? ?? false,
      smoker: data['smoker'] as bool? ?? false,
      cleanlinessLevel: (data['cleanlinessLevel'] as num?)?.toInt() ?? 5,
      sleepSchedule: data['sleepSchedule'] as String? ?? 'Flexible',
      favoriteStudentIds: List<String>.from(data['favoriteStudentIds'] ?? []),
      blockedStudentIds: List<String>.from(data['blockedStudentIds'] ?? []),
      isOnline: data['isOnline'] as bool? ?? false,
      assignedRoomId: data['assignedRoomId'] as String?,
      requestedRoomId: data['requestedRoomId'] as String?,
      roommateId: data['roommateId'] as String?,
      profileCompleted: data['profileCompleted'] as bool? ?? false,
      quizCompleted: data['quizCompleted'] as bool? ?? false,
      paymentVerified: data['paymentVerified'] as bool? ?? false,
      assignmentStatus: AssignmentStatus.values.firstWhere(
        (e) => e.name == data['assignmentStatus'],
        orElse: () => AssignmentStatus.none,
      ),
      isAccountBlocked: data['isAccountBlocked'] as bool? ?? false,
      blockReason: data['blockReason'] as String?,
      blockedAt: data['blockedAt'] != null ? _readDate(data['blockedAt']) : null,
      lastLeftRoomId: data['lastLeftRoomId'] as String?,
    );

// ── Room ─────────────────────────────────────────────────────────────────────

Map<String, dynamic> roomToMap(Room r) => {
      'roomId': r.roomId,
      'block': r.block,
      'floor': r.floor,
      'roomNumber': r.roomNumber,
      'capacity': r.capacity,
      'currentOccupancy': r.currentOccupancy,
      'roomType': r.roomType,
      'hasAttachedBathroom': r.hasAttachedBathroom,
      'hasAC': r.hasAC,
      'hasWifi': r.hasWifi,
      'isFurnished': r.isFurnished,
      'hasKitchenAccess': r.hasKitchenAccess,
      'hasLaundry': r.hasLaundry,
      'sharingType': r.sharingType,
      'location': r.location,
      'basePrice': r.basePrice,
      'occupantsIds': r.occupantsIds,
      'imageUrls': r.imageUrls,
    };

Room roomFromMap(Map<String, dynamic> data) => Room(
      roomId: data['roomId'] as String,
      block: data['block'] as String? ?? '',
      floor: (data['floor'] as num?)?.toInt() ?? 0,
      roomNumber: data['roomNumber'] as String? ?? '',
      capacity: (data['capacity'] as num?)?.toInt() ?? 2,
      currentOccupancy: (data['currentOccupancy'] as num?)?.toInt() ?? 0,
      roomType: data['roomType'] as String? ?? 'standard',
      hasAttachedBathroom: data['hasAttachedBathroom'] as bool? ?? false,
      hasAC: data['hasAC'] as bool? ?? false,
      hasWifi: data['hasWifi'] as bool? ?? false,
      isFurnished: data['isFurnished'] as bool? ?? false,
      hasKitchenAccess: data['hasKitchenAccess'] as bool? ?? false,
      hasLaundry: data['hasLaundry'] as bool? ?? false,
      sharingType: data['sharingType'] as String? ?? 'Double',
      location: data['location'] as String? ?? '',
      basePrice: (data['basePrice'] as num?)?.toDouble() ?? 10000.0,
      occupantsIds: List<String>.from(data['occupantsIds'] ?? []),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
    );

// ── Hostel ───────────────────────────────────────────────────────────────────

Map<String, dynamic> hostelToMap(Hostel h) => {
      'id': h.id,
      'hostelName': h.hostelName,
      'location': h.location,
      'totalFloors': h.totalFloors,
      'totalRooms': h.totalRooms,
      'createdByOwner': h.createdByOwner,
      'assignedAdminId': h.assignedAdminId,
      'assignedType': h.assignedType,
      'createdAt': _writeDate(h.createdAt),
      'approvalStatus': h.approvalStatus.name,
      'hostelImageUrl': h.hostelImageUrl,
      'paperImageUrl': h.paperImageUrl,
      'hostelImageBase64': h.hostelImageBase64,
      'paperImageBase64': h.paperImageBase64,
      'rentPerMonth': h.rentPerMonth,
      'rejectionReason': h.rejectionReason,
      'floors': h.floors
          .map((f) => {
                'id': f.id,
                'floorNumber': f.floorNumber,
                'rooms': f.rooms.map(roomToMap).toList(),
              })
          .toList(),
    };

Hostel hostelFromMap(Map<String, dynamic> data, {String? docId}) {
  final floorsData = data['floors'] as List<dynamic>? ?? [];
  final floors = floorsData.map((f) {
    final fm = f as Map<String, dynamic>;
    final roomsData = fm['rooms'] as List<dynamic>? ?? [];
    return Floor(
      id: fm['id'] as String,
      floorNumber: (fm['floorNumber'] as num).toInt(),
      rooms: roomsData.map((r) => roomFromMap(r as Map<String, dynamic>)).toList(),
    );
  }).toList();

  return Hostel(
    id: (data['id'] as String?) ?? docId ?? '',
    hostelName: data['hostelName'] as String,
    location: data['location'] as String? ?? '',
    totalFloors: (data['totalFloors'] as num?)?.toInt() ?? 0,
    totalRooms: (data['totalRooms'] as num?)?.toInt() ?? 0,
    createdByOwner: data['createdByOwner'] as String? ?? '',
    assignedAdminId: data['assignedAdminId'] as String?,
    assignedType: data['assignedType'] as String?,
    createdAt: _readDate(data['createdAt']),
    approvalStatus: HostelApprovalStatus.values.firstWhere(
      (e) => e.name == (data['approvalStatus'] as String?),
      orElse: () => HostelApprovalStatus.pending,
    ),
    hostelImageUrl: data['hostelImageUrl'] as String?,
    paperImageUrl: data['paperImageUrl'] as String?,
    hostelImageBase64: data['hostelImageBase64'] as String?,
    paperImageBase64: data['paperImageBase64'] as String?,
    rentPerMonth: (data['rentPerMonth'] as num?)?.toDouble() ?? 0,
    rejectionReason: data['rejectionReason'] as String?,
    floors: floors,
  );
}

List<Room> roomsFromHostels(List<Hostel> hostels) {
  final rooms = <Room>[];
  for (final hostel in hostels) {
    for (final floor in hostel.floors) {
      rooms.addAll(floor.rooms);
    }
  }
  return rooms;
}

// ── HostelRequest ────────────────────────────────────────────────────────────

Map<String, dynamic> hostelRequestToMap(HostelRequest r) => {
      'id': r.id,
      'studentId': r.studentId,
      'studentName': r.studentName,
      'hostelId': r.hostelId,
      'hostelName': r.hostelName,
      'location': r.location,
      'adminId': r.adminId,
      'adminName': r.adminName,
      'hostelType': r.hostelType,
      'description': r.description,
      'requestedAt': _writeDate(r.requestedAt),
      'status': r.status.name,
      'adminFeedback': r.adminFeedback,
      'ownerMessage': r.ownerMessage,
    };

HostelRequest hostelRequestFromMap(Map<String, dynamic> data) => HostelRequest(
      id: data['id'] as String,
      studentId: (data['studentId'] as String? ?? '').trim(),
      studentName: (data['studentName'] as String? ?? '').trim(),
      hostelId: data['hostelId'] as String,
      hostelName: data['hostelName'] as String? ?? '',
      location: data['location'] as String? ?? '',
      adminId: (data['adminId'] as String? ?? '').trim(),
      adminName: (data['adminName'] as String? ?? 'Admin').trim(),
      hostelType: data['hostelType'] as String? ?? '',
      description: data['description'] as String? ?? '',
      requestedAt: _readDate(data['requestedAt']),
      status: HostelRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => HostelRequestStatus.pending,
      ),
      adminFeedback: data['adminFeedback'] as String?,
      ownerMessage: data['ownerMessage'] as String?,
    );

// ── RoommateRequest ──────────────────────────────────────────────────────────

Map<String, dynamic> roommateRequestToMap(RoommateRequest r) => {
      'id': r.id,
      'senderId': r.senderId,
      'receiverId': r.receiverId,
      'senderName': r.senderName,
      'receiverName': r.receiverName,
      'status': r.status.name,
      'adminStatus': r.adminStatus.name,
      'type': r.type.name,
      'createdAt': _writeDate(r.createdAt),
      'respondedAt': r.respondedAt != null ? _writeDate(r.respondedAt!) : null,
      'compatibilityScore': r.compatibilityScore,
      'skillName': r.skillName,
      'notificationRead': r.notificationRead,
      'isMatched': r.isMatched,
    };

RoommateRequest roommateRequestFromMap(Map<String, dynamic> data) => RoommateRequest(
      id: data['id'] as String,
      senderId: data['senderId'] as String,
      receiverId: data['receiverId'] as String,
      senderName: data['senderName'] as String? ?? '',
      receiverName: data['receiverName'] as String? ?? '',
      status: RequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RequestStatus.pending,
      ),
      adminStatus: AdminStatus.values.firstWhere(
        (e) => e.name == data['adminStatus'],
        orElse: () => AdminStatus.pending,
      ),
      type: RequestType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => RequestType.roommate,
      ),
      createdAt: _readDate(data['createdAt']),
      respondedAt: data['respondedAt'] != null ? _readDate(data['respondedAt']) : null,
      compatibilityScore: (data['compatibilityScore'] as num?)?.toDouble() ?? 0.0,
      skillName: data['skillName'] as String?,
      notificationRead: data['notificationRead'] as bool? ?? false,
      isMatched: data['isMatched'] as bool? ?? false,
    );

// ── Payment ──────────────────────────────────────────────────────────────────

Map<String, dynamic> paymentToMap(Payment p) => {
      'paymentId': p.paymentId,
      'userId': p.userId,
      'roomId': p.roomId,
      'amount': p.amount,
      'paymentMethod': p.paymentMethod,
      'status': p.status.name,
      'timestamp': _writeDate(p.timestamp),
      'cardLast4Digits': p.cardLast4Digits,
      'kind': p.kind.name,
      'hostelId': p.hostelId,
      'adminShare': p.adminShare,
      'ownerShare': p.ownerShare,
      'ownerId': p.ownerId,
      'paymentMonth': p.paymentMonth,
    };

Payment paymentFromMap(Map<String, dynamic> data) => Payment(
      paymentId: data['paymentId'] as String,
      userId: data['userId'] as String,
      roomId: data['roomId'] as String? ?? '',
      amount: (data['amount'] as num).toDouble(),
      paymentMethod: data['paymentMethod'] as String? ?? '',
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      timestamp: _readDate(data['timestamp']),
      cardLast4Digits: data['cardLast4Digits'] as String?,
      kind: PaymentKind.values.firstWhere(
        (e) => e.name == data['kind'],
        orElse: () => PaymentKind.studentRoom,
      ),
      hostelId: data['hostelId'] as String?,
      adminShare: (data['adminShare'] as num?)?.toDouble(),
      ownerShare: (data['ownerShare'] as num?)?.toDouble(),
      ownerId: data['ownerId'] as String?,
      paymentMonth: data['paymentMonth'] as String?,
    );

// ── AppNotification ──────────────────────────────────────────────────────────

Map<String, dynamic> notificationToMap(AppNotification n) => {
      'id': n.id,
      'title': n.title,
      'message': n.message,
      'timestamp': _writeDate(n.timestamp),
      'type': n.type.name,
      'targetUserId': n.targetUserId,
      'isRead': n.isRead,
    };

AppNotification notificationFromMap(Map<String, dynamic> data) => AppNotification(
      id: data['id'] as String,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.info,
      ),
      timestamp: _readDate(data['timestamp']),
      targetUserId: data['targetUserId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
    );

// ── UnblockRequest ───────────────────────────────────────────────────────────

Map<String, dynamic> unblockRequestToMap(UnblockRequest r) => {
      'id': r.id,
      'studentId': r.studentId,
      'studentName': r.studentName,
      'targetRole': r.targetRole.name,
      'message': r.message,
      'requestedAt': _writeDate(r.requestedAt),
      'status': r.status.name,
      'adminNote': r.adminNote,
    };

UnblockRequest unblockRequestFromMap(Map<String, dynamic> data) => UnblockRequest(
      id: data['id'] as String,
      studentId: data['studentId'] as String,
      studentName: data['studentName'] as String? ?? '',
      targetRole: UserRole.values.firstWhere(
        (e) => e.name == data['targetRole'],
        orElse: () => UserRole.student,
      ),
      message: data['message'] as String? ?? '',
      requestedAt: _readDate(data['requestedAt']),
      status: UnblockRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => UnblockRequestStatus.pending,
      ),
      adminNote: data['adminNote'] as String?,
    );

// ── HostelReview ───────────────────────────────────────────────────────────

Map<String, dynamic> hostelReviewToMap(HostelReview r) => {
      'id': r.id,
      'studentId': r.studentId,
      'studentName': r.studentName,
      'hostelId': r.hostelId,
      'hostelName': r.hostelName,
      'rating': r.rating,
      'comment': r.comment,
      'createdAt': _writeDate(r.createdAt),
    };

HostelReview hostelReviewFromMap(Map<String, dynamic> data) => HostelReview(
      id: data['id'] as String,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      hostelId: data['hostelId'] as String? ?? '',
      hostelName: data['hostelName'] as String? ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 5,
      comment: data['comment'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
    );
