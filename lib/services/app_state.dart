import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../models/room.dart';
import '../models/roommate_request.dart';
import '../models/payment.dart';
import 'matching_engine.dart';
import '../models/hostel.dart';
import '../models/hostel_request.dart';
import '../models/notification.dart';
import '../models/unblock_request.dart';
import '../models/hostel_review.dart';
import '../models/firestore_mappers.dart';
import 'firestore_repository.dart';
import 'firebase_service.dart';
import '../utils/payment_months.dart';

class StrongMatch {
  final Student studentA;
  final Student studentB;
  final double compatibilityScore;

  StrongMatch(this.studentA, this.studentB, this.compatibilityScore);
}

/// Two students who requested the same hostel and score high on compatibility.
class HostelMatchPair {
  final Student studentA;
  final Student studentB;
  final double compatibilityScore;
  final String hostelId;

  HostelMatchPair(this.studentA, this.studentB, this.compatibilityScore, this.hostelId);

  String get pairKey => '${studentA.studentId}_${studentB.studentId}';
}

class ActivityLogEntry {
  final DateTime time;
  final String category;
  final String title;
  final String detail;

  ActivityLogEntry({
    required this.time,
    required this.category,
    required this.title,
    required this.detail,
  });
}

class AppState extends ChangeNotifier {
  static const platformAdminEmail = 'admin@syncstay.com';

  List<Student> allStudents = [];
  List<Room> allRooms = [];
  List<RoommateRequest> allRequests = [];
  List<Payment> allPayments = [];
  List<AppNotification> allNotifications = [];
  List<Hostel> hostels = [];
  List<HostelRequest> hostelRequests = [];
  List<UnblockRequest> unblockRequests = [];
  List<HostelReview> hostelReviews = [];
  List<RoomAssignment> assignments = [];
  List<Student> owners = [];
  List<Student> wardens = [];
  List<Student> admins = [];
  Student? currentUser;
  UserRole? get currentUserRole => currentUser?.role;
  final RoommateMatchingEngine engine = RoommateMatchingEngine();
  
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;
  int selectedNavIndex = 0;
  int _dashboardTabJumpToken = 0;
  int get dashboardTabJumpToken => _dashboardTabJumpToken;
  
  List<String> requestedRoomIds = [];
  List<String> rejectedRoomIds = [];

  final FirestoreRepository _db = FirestoreRepository();
  List<StreamSubscription<dynamic>>? _firestoreSubs;
  Timer? _syncTimer;
  bool _applyingRemote = false;
  bool isInitialized = false;
  bool isLoading = true;
  String? initError;

  AppState() {
    _loadPreferences();
  }

  Future<void> initialize() async {
    try {
      isLoading = true;
      initError = null;
      notifyListeners();

      try {
        await _db.purgeLegacyDemoOwnerWardenAccounts();
        await _db.ensurePlatformAdminAccount();
        await _db.seedIfEmpty();
      } catch (e) {
        initError = 'Could not seed Firebase: $e';
      }

      final data = await _db.loadAll();
      _applyRemoteData(
        users: data.users,
        hostels: data.hostels,
        hostelRequests: data.hostelRequests,
        roommateRequests: data.roommateRequests,
        payments: data.payments,
        notifications: data.notifications,
        unblockRequests: data.unblockRequests,
        hostelReviews: data.hostelReviews,
      );

      for (final sub in _firestoreSubs ?? []) {
        await sub.cancel();
      }
      _firestoreSubs = _db.listenAll(_applyRemoteData);

      isInitialized = true;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      initError = e.toString();
      isInitialized = true;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistToFirestore() async {
    if (!isInitialized) return;
    await _db.syncAll(
      hostels: hostels,
      hostelRequests: hostelRequests,
      roommateRequests: allRequests,
      payments: allPayments,
      notifications: allNotifications,
      unblockRequests: unblockRequests,
      hostelReviews: hostelReviews,
    );
  }

  void _applyRemoteData({
    required List<Student> users,
    required List<Hostel> hostels,
    required List<HostelRequest> hostelRequests,
    required List<RoommateRequest> roommateRequests,
    required List<Payment> payments,
    required List<AppNotification> notifications,
    required List<UnblockRequest> unblockRequests,
    required List<HostelReview> hostelReviews,
  }) {
    _applyingRemote = true;
    allStudents = users;
    _rebuildRoleLists();
    this.hostels = _mergeIncomingHostelApprovals(hostels);
    allRooms = roomsFromHostels(this.hostels);
    this.hostelRequests = _mergeIncomingHostelRequests(hostelRequests);
    _healWardenRequestStatusesFromHostelAssignments();
    allRequests = _mergeIncomingRoommateRequests(roommateRequests);
    allPayments = payments;
    allNotifications = notifications;
    this.unblockRequests = unblockRequests;
    this.hostelReviews = hostelReviews;

    if (currentUser != null) {
      final refreshed =
          getStudentById(currentUser!.studentId) ?? getStudentById(currentUser!.email);
      if (refreshed != null) currentUser = refreshed;
    }
    super.notifyListeners();
    _applyingRemote = false;
  }

  void _rebuildRoleLists() {
    owners = allStudents.where((s) => s.role == UserRole.owner).toList();
    wardens = allStudents.where((s) => s.role == UserRole.warden).toList();
    admins = allStudents.where((s) => s.role == UserRole.admin).toList();
  }

  /// Avoids flicker when a stale snapshot arrives after admin already approved.
  List<Hostel> _mergeIncomingHostelApprovals(List<Hostel> incoming) {
    if (this.hostels.isEmpty) return incoming;
    final previous = {for (final h in this.hostels) h.id: h};
    return incoming.map((h) {
      final prev = previous[h.id];
      if (prev == null) return h;
      if (h.approvalStatus == HostelApprovalStatus.pending) {
        if (prev.approvalStatus == HostelApprovalStatus.approved) {
          h.approvalStatus = HostelApprovalStatus.approved;
          h.rejectionReason = null;
        } else if (prev.approvalStatus == HostelApprovalStatus.rejected) {
          h.approvalStatus = HostelApprovalStatus.rejected;
          h.rejectionReason = prev.rejectionReason ?? h.rejectionReason;
        }
      }
      if ((h.assignedAdminId == null || h.assignedAdminId!.isEmpty) &&
          prev.assignedAdminId != null &&
          prev.assignedAdminId!.isNotEmpty) {
        h.assignedAdminId = prev.assignedAdminId;
        h.assignedType = prev.assignedType ?? h.assignedType;
      }
      return h;
    }).toList();
  }

  /// Keeps booked/rejected warden requests when Firestore sends a stale pending snapshot.
  List<HostelRequest> _mergeIncomingHostelRequests(List<HostelRequest> incoming) {
    if (hostelRequests.isEmpty) return incoming;
    final previous = {for (final r in hostelRequests) r.id: r};
    final merged = <HostelRequest>[];
    final incomingIds = <String>{};

    for (final r in incoming) {
      incomingIds.add(r.id);
      final prev = previous[r.id];
      if (prev != null &&
          r.status == HostelRequestStatus.pending &&
          (prev.status == HostelRequestStatus.booked || prev.status == HostelRequestStatus.rejected)) {
        r.status = prev.status;
        r.adminFeedback = prev.adminFeedback ?? r.adminFeedback;
        r.ownerMessage = prev.ownerMessage ?? r.ownerMessage;
      }
      merged.add(r);
    }

    for (final prev in hostelRequests) {
      if (!incomingIds.contains(prev.id)) merged.add(prev);
    }
    return merged;
  }

  /// Keeps accepted/rejected roommate requests when Firestore sends a stale pending snapshot.
  List<RoommateRequest> _mergeIncomingRoommateRequests(List<RoommateRequest> incoming) {
    if (allRequests.isEmpty) return incoming;
    final previous = {for (final r in allRequests) r.id: r};
    final merged = <RoommateRequest>[];
    final incomingIds = <String>{};

    for (final r in incoming) {
      incomingIds.add(r.id);
      final prev = previous[r.id];
      if (prev != null) {
        if (r.status == RequestStatus.pending &&
            (prev.status == RequestStatus.accepted || prev.status == RequestStatus.rejected)) {
          r.status = prev.status;
          r.respondedAt = prev.respondedAt ?? r.respondedAt;
          r.isMatched = prev.isMatched || r.isMatched;
        } else if (prev.status == RequestStatus.accepted && r.status != RequestStatus.accepted) {
          r.status = prev.status;
          r.respondedAt = prev.respondedAt ?? r.respondedAt;
          r.isMatched = prev.isMatched;
        }
      }
      merged.add(r);
    }

    for (final prev in allRequests) {
      if (!incomingIds.contains(prev.id)) merged.add(prev);
    }
    return merged;
  }

  /// If hostel is already assigned to a warden, their request must not stay pending.
  void _healWardenRequestStatusesFromHostelAssignments() {
    for (final r in hostelRequests) {
      if (!r.isWardenAssignmentRequest || r.status != HostelRequestStatus.pending) continue;
      final hostel = hostels.cast<Hostel?>().firstWhere(
            (h) => h?.id == r.hostelId,
            orElse: () => null,
          );
      if (hostel != null && hostel.assignedAdminId == r.adminId) {
        r.status = HostelRequestStatus.booked;
        unawaited(_db.saveHostelRequest(r).catchError((_) {}));
      }
    }
  }

  HostelRequestStatus effectiveWardenRequestStatus(HostelRequest request) {
    if (!request.isWardenAssignmentRequest) return request.status;
    if (request.status != HostelRequestStatus.pending) return request.status;
    final hostel = hostels.cast<Hostel?>().firstWhere(
          (h) => h?.id == request.hostelId,
          orElse: () => null,
        );
    if (hostel != null && hostel.assignedAdminId == request.adminId) {
      return HostelRequestStatus.booked;
    }
    return request.status;
  }

  void _scheduleFirestoreSync() {
    if (_applyingRemote || !isInitialized) return;
    if (FirebaseService.auth.currentUser == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persistToFirestore().catchError((_) {}));
    });
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleFirestoreSync();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    for (final sub in _firestoreSubs ?? []) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    selectedNavIndex = prefs.getInt('selectedNavIndex') ?? 0;
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  void setSelectedNavIndex(int index) async {
    selectedNavIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedNavIndex', index);
    notifyListeners();
  }

  void jumpToDashboardTab(int index) {
    setSelectedNavIndex(index);
    _dashboardTabJumpToken++;
    notifyListeners();
  }


  Future<void> logout() async {
    await _db.signOut();
    currentUser = null;
    notifyListeners();
  }

  void _syncStudent(Student updated, {bool persist = true}) {
    final idx = allStudents.indexWhere((s) => s.studentId == updated.studentId);
    if (idx != -1) allStudents[idx] = updated;
    if (currentUser?.studentId == updated.studentId) currentUser = updated;
    if (persist && !_applyingRemote) {
      unawaited(_db.saveUser(updated).catchError((_) {}));
    }
  }

  Student? getStudentById(String studentId) {
    final key = studentId.trim().toLowerCase();
    if (key.isEmpty) return null;
    try {
      return allStudents.firstWhere(
        (s) =>
            s.studentId.trim().toLowerCase() == key ||
            s.email.trim().toLowerCase() == key,
      );
    } catch (_) {
      return null;
    }
  }

  String _userKey(Student user) =>
      user.email.trim().isNotEmpty ? user.email.trim().toLowerCase() : user.studentId.trim().toLowerCase();

  String _normalizeId(String id) => id.trim().toLowerCase();

  bool idsMatch(String a, String b) => _normalizeId(a) == _normalizeId(b);

  /// Pull latest profile from Firestore (used on blocked screen + after login).
  Future<void> refreshCurrentUserFromRemote() async {
    if (currentUser == null) return;
    final key = _userKey(currentUser!);
    if (key.isEmpty) return;
    try {
      final remote = await _db.getUserByEmail(key);
      if (remote == null) return;
      _syncStudent(remote, persist: false);
      notifyListeners();
    } catch (_) {}
  }

  UserRole _roleFromEmail(String email) {
    final e = email.trim().toLowerCase();
    if (e == platformAdminEmail) return UserRole.admin;
    if (e.endsWith('@owner.com')) return UserRole.owner;
    if (e.endsWith('@warden.com')) return UserRole.warden;
    if (e.endsWith('@admin.com')) return UserRole.warden; // legacy accounts
    return UserRole.student;
  }

  bool _emailMatchesRole(String email, UserRole role) {
    final e = email.trim().toLowerCase();
    switch (role) {
      case UserRole.admin:
        return e == platformAdminEmail;
      case UserRole.owner:
        return e.endsWith('@owner.com');
      case UserRole.warden:
        return e.endsWith('@warden.com') || e.endsWith('@admin.com');
      case UserRole.student:
        return e.endsWith('@student.com');
    }
  }

  Future<bool> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    try {
      await _db.signIn(cleanEmail, cleanPass);

      Student? user;
      try {
        user = await _db.getUserByEmail(cleanEmail);
      } catch (_) {}
      user ??= getStudentById(cleanEmail);

      // Auth OK but Firestore profile missing — create it now.
      if (user == null) {
        user = Student(
          studentId: cleanEmail,
          email: cleanEmail,
          name: cleanEmail.split('@').first,
          role: _roleFromEmail(cleanEmail),
        );
        try {
          await _db.saveUser(user);
        } catch (_) {
          // Keep going with in-memory profile if Firestore write fails.
        }
        if (!allStudents.any((s) => s.email == cleanEmail)) {
          allStudents.add(user);
          if (user.role == UserRole.warden) wardens.add(user);
          if (user.role == UserRole.admin) admins.add(user);
          if (user.role == UserRole.owner) owners.add(user);
        }
      }

      if (cleanEmail == platformAdminEmail && user.role != UserRole.admin) {
        user.role = UserRole.admin;
        _syncStudent(user);
        try {
          await _db.saveUser(user);
        } catch (_) {}
      }

      if (!_emailMatchesRole(cleanEmail, user.role)) {
        await _db.signOut();
        return false;
      }

      currentUser = user;
      _syncStudent(user);
      setSelectedNavIndex(0);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastLoginEmail', cleanEmail);
      } catch (_) {}
      notifyListeners();
      return true;
    } on FirebaseAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password, String gender) async {
    final lowEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    if (lowEmail == platformAdminEmail) return false;

    if (allStudents.any((s) => s.email.toLowerCase() == lowEmail)) return false;

    final UserRole role;
    if (lowEmail.endsWith('@student.com')) {
      role = UserRole.student;
    } else if (lowEmail.endsWith('@owner.com')) {
      role = UserRole.owner;
    } else if (lowEmail.endsWith('@warden.com')) {
      role = UserRole.warden;
    } else {
      return false;
    }

    if ((role == UserRole.student || role == UserRole.warden) && gender.trim().isEmpty) {
      return false;
    }

    try {
      await _db.signUp(lowEmail, cleanPass);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return false;
      return false;
    } catch (_) {
      return false;
    }

    var newUser = Student(
      studentId: lowEmail,
      name: name.trim(),
      email: lowEmail,
      role: role,
      gender: gender.trim(),
      profileCompleted: role != UserRole.student,
    );

    allStudents.add(newUser);
    if (role == UserRole.owner) owners.add(newUser);
    if (role == UserRole.warden) wardens.add(newUser);
    currentUser = newUser;
    setSelectedNavIndex(0);

    try {
      await _db.saveUser(newUser);
    } catch (_) {
      // Auth account exists; profile will sync on next login.
    }

    notifyListeners();
    return true;
  }

  List<Student> getAllOwners() => owners;

  /// Wardens currently assigned to this owner's hostels (read-only for owner dashboard).
  List<Student> getWardensAssignedToOwner(String ownerId) {
    final result = <Student>[];
    final seen = <String>{};
    for (final h in hostels) {
      if (!idsMatch(h.createdByOwner, ownerId) || h.assignedAdminId == null) continue;
      if (!seen.add(h.assignedAdminId!)) continue;
      final w = getStudentById(h.assignedAdminId!);
      if (w != null) result.add(w);
    }
    return result;
  }

  List<Student> getWardensForOwner(String ownerId) => getWardensAssignedToOwner(ownerId);

  List<Student> getAvailableOwnersForTransfer({String? excludeOwnerId}) {
    return owners
        .where((o) =>
            !o.isAccountBlocked &&
            (excludeOwnerId == null || o.studentId != excludeOwnerId))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  String? transferHostelToOwner(String hostelId, String newOwnerId) {
    if (currentUser?.role != UserRole.admin) return 'Only admin can transfer hostels';
    final hostelIdx = hostels.indexWhere((h) => h.id == hostelId);
    if (hostelIdx == -1) return 'Hostel not found';

    final newOwner = getStudentById(newOwnerId);
    if (newOwner == null || newOwner.role != UserRole.owner) {
      return 'New owner account not valid';
    }
    if (newOwner.isAccountBlocked) return 'Selected owner is blocked';

    final hostel = hostels[hostelIdx];
    if (hostel.createdByOwner == newOwnerId) return 'Hostel already belongs to this owner';

    final oldOwnerId = hostel.createdByOwner;
    hostel.createdByOwner = newOwnerId;
    unawaited(_db.saveHostel(hostel).catchError((_) {}));

    addNotification(
      'Hostel Ownership Transferred',
      '${hostel.hostelName} is now managed by ${newOwner.name.isNotEmpty ? newOwner.name : newOwner.email}.',
      NotificationType.info,
      targetUserId: newOwnerId,
    );
    if (oldOwnerId.isNotEmpty && oldOwnerId != newOwnerId) {
      addNotification(
        'Hostel Ownership Updated',
        'Your hostel ${hostel.hostelName} was transferred by platform admin.',
        NotificationType.info,
        targetUserId: oldOwnerId,
      );
    }
    notifyListeners();
    return null;
  }

  // Hostel Management — owner submits for platform admin approval
  void submitHostelForApproval(
    String name,
    String location,
    int floorCount,
    Map<int, int> roomsPerFloor, {
    required double rentPerMonth,
    String? hostelId,
    String? hostelImageUrl,
    String? paperImageUrl,
    String? hostelImageBase64,
    String? paperImageBase64,
  }) {
    final resolvedHostelId = hostelId ?? 'H${DateTime.now().millisecondsSinceEpoch}';
    List<Floor> floors = [];

    for (int f = 1; f <= floorCount; f++) {
      List<Room> rooms = [];
      int roomCount = roomsPerFloor[f] ?? 0;
      for (int r = 1; r <= roomCount; r++) {
        String roomId = '$resolvedHostelId-F$f-R$r';
        String roomNum = '${f}${r.toString().padLeft(2, '0')}';
        rooms.add(Room(
          roomId: roomId,
          block: name.isNotEmpty ? name[0] : 'H',
          floor: f,
          roomNumber: roomNum,
          capacity: 2,
          roomType: 'standard',
          hasAC: false,
          hasWifi: true,
          hasAttachedBathroom: true,
          location: location,
          basePrice: rentPerMonth / (roomCount > 0 ? roomCount : 1),
        ));
      }
      floors.add(Floor(id: '$resolvedHostelId-F$f', floorNumber: f, rooms: rooms));
    }

    final hostel = Hostel(
      id: resolvedHostelId,
      hostelName: name,
      location: location,
      totalFloors: floorCount,
      totalRooms: floors.fold(0, (sum, f) => sum + f.rooms.length),
      createdByOwner: currentUser?.studentId ?? '',
      createdAt: DateTime.now(),
      floors: floors,
      approvalStatus: HostelApprovalStatus.pending,
      hostelImageUrl: hostelImageUrl,
      paperImageUrl: paperImageUrl,
      hostelImageBase64: hostelImageBase64,
      paperImageBase64: paperImageBase64,
      rentPerMonth: rentPerMonth,
    );
    hostels.add(hostel);
    allRooms = roomsFromHostels(hostels);
    unawaited(_db.saveHostel(hostel).catchError((_) {}));

    addNotification(
      'New Hostel Submission',
      '$name submitted by ${currentUser?.name ?? "Owner"} — pending your approval.',
      NotificationType.info,
      targetUserId: platformAdminEmail,
    );
    notifyListeners();
  }

  List<Hostel> getPendingOwnerHostelSubmissions() {
    return hostels.where((h) => h.approvalStatus == HostelApprovalStatus.pending).toList();
  }

  List<Hostel> getHostelsForOwner(String ownerId) {
    return hostels.where((h) => h.createdByOwner == ownerId).toList();
  }

  Future<bool> approveOwnerHostelSubmission(String hostelId) async {
    final idx = hostels.indexWhere((h) => h.id == hostelId);
    if (idx == -1) return false;
    if (hostels[idx].approvalStatus != HostelApprovalStatus.pending) return false;

    hostels[idx].approvalStatus = HostelApprovalStatus.approved;
    hostels[idx].rejectionReason = null;
    try {
      await _db.saveHostel(hostels[idx]);
    } catch (_) {
      hostels[idx].approvalStatus = HostelApprovalStatus.pending;
      return false;
    }

    addNotification(
      'Hostel Approved',
      '${hostels[idx].hostelName} is now live and available for wardens.',
      NotificationType.info,
      targetUserId: hostels[idx].createdByOwner,
    );

    final pendingWardenRequests = getPendingRequestsForHostel(hostelId);
    for (final request in pendingWardenRequests) {
      addNotification(
        'Hostel Approved — Action Needed',
        '${hostels[idx].hostelName} is approved. Approve ${wardenNameForRequest(request)}\'s assignment in the Wardens tab.',
        NotificationType.info,
        targetUserId: platformAdminEmail,
      );
    }

    notifyListeners();
    return true;
  }

  Future<bool> rejectOwnerHostelSubmission(String hostelId, {String? reason}) async {
    final idx = hostels.indexWhere((h) => h.id == hostelId);
    if (idx == -1) return false;
    if (hostels[idx].approvalStatus != HostelApprovalStatus.pending) return false;

    hostels[idx].approvalStatus = HostelApprovalStatus.rejected;
    hostels[idx].rejectionReason = reason;
    try {
      await _db.saveHostel(hostels[idx]);
    } catch (_) {
      hostels[idx].approvalStatus = HostelApprovalStatus.pending;
      hostels[idx].rejectionReason = null;
      return false;
    }

    addNotification(
      'Hostel Rejected',
      reason ?? '${hostels[idx].hostelName} was rejected by platform admin.',
      NotificationType.info,
      targetUserId: hostels[idx].createdByOwner,
    );
    notifyListeners();
    return true;
  }

  /// Owner removes their hostel (not allowed if warden assigned or students linked).
  Future<String?> removeHostelByOwner(String hostelId) async {
    if (currentUser?.role != UserRole.owner) return 'Only owners can remove hostels';

    final idx = hostels.indexWhere((h) => h.id == hostelId);
    if (idx == -1) return 'Hostel not found';

    final hostel = hostels[idx];
    if (hostel.createdByOwner != currentUser!.studentId) return 'Not your hostel';

    if (hostel.isBooked) {
      return 'Cannot remove: a warden is already assigned to this hostel.';
    }

    final hasStudentActivity = hostelRequests.any(
      (r) =>
          r.hostelId == hostelId &&
          r.isStudentJoinRequest &&
          (r.status == HostelRequestStatus.pending || r.status == HostelRequestStatus.booked),
    );
    if (hasStudentActivity) {
      return 'Cannot remove: students have active requests for this hostel.';
    }

    final roomPrefix = '$hostelId-';
    for (final room in allRooms.where((r) => r.roomId.startsWith(roomPrefix))) {
      if (room.occupantsIds.isNotEmpty) {
        return 'Cannot remove: students are assigned to rooms in this hostel.';
      }
    }

    final hostelName = hostel.hostelName;

    try {
      await _db.purgeHostelAndRelatedData(
        hostelId: hostelId,
        hostelName: hostelName,
        roomIdPrefix: roomPrefix,
      );
    } catch (_) {
      return 'Could not delete from server. Try again.';
    }

    _purgeHostelDataLocally(hostelId, hostelName, roomPrefix);

    addNotification(
      'Hostel Removed',
      '$hostelName was removed by the owner. It no longer appears in admin submissions.',
      NotificationType.info,
      targetUserId: platformAdminEmail,
    );
    addNotification(
      'Hostel Removed',
      'You removed $hostelName. Related requests and reviews were cleared.',
      NotificationType.info,
      targetUserId: currentUser!.studentId,
    );

    notifyListeners();
    unawaited(_persistToFirestore());
    return null;
  }

  void _purgeHostelDataLocally(String hostelId, String hostelName, String roomPrefix) {
    hostelRequests.removeWhere((r) => r.hostelId == hostelId);
    hostelReviews.removeWhere((r) => r.hostelId == hostelId);

    allPayments.removeWhere(
      (p) => p.hostelId == hostelId || p.roomId.startsWith(roomPrefix),
    );

    allNotifications.removeWhere(
      (n) => n.message.contains(hostelName) || n.title.contains(hostelName),
    );

    _studentActivityLogs.removeWhere(
      (log) => log.title.contains(hostelName) || log.detail.contains(hostelName),
    );

    for (final s in allStudents) {
      if (s.requestedRoomId != null && s.requestedRoomId!.startsWith(roomPrefix)) {
        s.requestedRoomId = null;
        final i = allStudents.indexWhere((x) => x.studentId == s.studentId);
        if (i != -1) allStudents[i].requestedRoomId = null;
      }
    }

    hostels.removeWhere((h) => h.id == hostelId);
    allRooms = roomsFromHostels(hostels);
  }

  /// Approved hostels not yet booked — any warden may request (one hostel at a time).
  List<Hostel> getHostelsAvailableForAdminRequest() {
    return hostels.where((h) => h.isAvailableForWarden).toList();
  }

  String defaultHostelTypeForGender(String gender) {
    return gender.trim().toLowerCase() == 'male' ? 'Boys Hostel' : 'Girls Hostel';
  }

  bool hostelTypeMatchesGender(String hostelType, String gender) {
    final isMale = gender.trim().toLowerCase() == 'male';
    final type = hostelType.toLowerCase();
    if (isMale) {
      return type.contains('boy') || type.contains('male');
    }
    return type.contains('girl') || type.contains('female');
  }

  bool adminHasPendingRequestForHostel(String adminId, String hostelId) {
    return hostelRequests.any((r) =>
        r.isWardenAssignmentRequest &&
        r.adminId == adminId &&
        r.hostelId == hostelId &&
        r.status == HostelRequestStatus.pending);
  }

  /// Warden may only manage one hostel at a time (assigned or pending request).
  String? wardenHostelRequestBlockReason(String adminId, {String? forHostelId}) {
    final assigned = getAssignedHostelForAdmin(adminId);
    if (assigned != null) {
      return 'You already manage ${assigned.hostelName}. Leave this hostel before requesting another.';
    }

    for (final r in hostelRequests) {
      if (!r.isWardenAssignmentRequest) continue;
      if (r.adminId != adminId) continue;
      if (r.status != HostelRequestStatus.pending) continue;
      if (forHostelId != null && r.hostelId == forHostelId) continue;
      return 'You already have a pending request for ${r.hostelName}. Wait for admin approval first.';
    }
    return null;
  }

  bool wardenCanRequestHostelAssignment(String adminId) =>
      wardenHostelRequestBlockReason(adminId) == null;

  String wardenNameForRequest(HostelRequest request) {
    if (request.adminName.trim().isNotEmpty) return request.adminName.trim();
    return getStudentById(request.adminId)?.name ?? request.adminId;
  }

  List<HostelRequest> getWardenAssignmentRequests() {
    final list = hostelRequests.where((r) => r.isWardenAssignmentRequest).toList();
    list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return list;
  }

  bool hostelMatchesStudentGender(Hostel hostel, String gender) {
    if (!hostel.isBooked || hostel.assignedType == null) return false;
    final isMale = gender.trim().toLowerCase() == 'male';
    final type = hostel.assignedType!.toLowerCase();
    if (isMale) {
      return type.contains('boy') || type.contains('male');
    }
    return type.contains('girl') || type.contains('female');
  }

  static const _genericLocationTokens = {
    'pakistan',
    'punjab',
    'sindh',
    'khyber pakhtunkhwa',
    'balochistan',
    'district',
    'division',
    'tehsil',
    'city',
    'province',
    'area',
    'pakistan.',
  };

  /// Meaningful place names from a map/manual address (skips country/province noise).
  static List<String> significantLocationParts(String raw) {
    final parts = <String>[];
    for (final segment in raw.toLowerCase().split(RegExp(r'[,|/]'))) {
      for (final piece in segment.split(RegExp(r'\s*[-–—]\s*'))) {
        final token = piece.trim();
        if (!_isSignificantLocationToken(token)) continue;
        if (token.endsWith(' district') || token.endsWith(' division')) continue;
        parts.add(token);
      }
    }
    return parts;
  }

  static bool _isSignificantLocationToken(String token) {
    if (token.length < 3) return false;
    if (RegExp(r'^\d+$').hasMatch(token)) return false;
    return !_genericLocationTokens.contains(token);
  }

  /// City/area words from commas, spaces, and multi-word segments (e.g. "Lahore Township" → lahore, township).
  static Set<String> _allLocationTokens(String raw) {
    final tokens = <String>{};
    for (final part in significantLocationParts(raw)) {
      tokens.add(part);
      for (final word in part.split(RegExp(r'\s+'))) {
        final w = word.trim().toLowerCase();
        if (_isSignificantLocationToken(w)) tokens.add(w);
      }
    }
    for (final word in raw.toLowerCase().split(RegExp(r'[\s,|/\-–—]+'))) {
      final w = word.trim();
      if (_isSignificantLocationToken(w)) tokens.add(w);
    }
    return tokens;
  }

  static bool _isPrefixPlaceMatch(String shorter, String longer) {
    if (shorter.length < 4 || longer.length < shorter.length) return false;
    if (!longer.startsWith(shorter)) return false;
    if (longer.length == shorter.length) return true;
    final next = longer[shorter.length];
    return next == ' ' || next == ',' || next == '-' || next == '/';
  }

  static bool _locationTokensMatch(String a, String b) {
    if (a == b) return true;
    return _isPrefixPlaceMatch(a, b) || _isPrefixPlaceMatch(b, a);
  }

  static bool _tokenAppearsInLocation(String token, String location) {
    final t = token.trim().toLowerCase();
    if (!_isSignificantLocationToken(t)) return false;
    final loc = location.trim().toLowerCase();
    if (loc == t) return true;

    final escaped = RegExp.escape(t);
    final wordBoundary = RegExp('(?:^|[\\s,|/\\-–—])$escaped(?:[\\s,|/\\-–—]|\$)');
    if (wordBoundary.hasMatch(loc)) return true;

    for (final segment in loc.split(RegExp(r'[,|/]'))) {
      for (final piece in segment.split(RegExp(r'\s*[-–—]\s*'))) {
        final pieceTrim = piece.trim();
        if (_locationTokensMatch(t, pieceTrim)) return true;
      }
    }
    return false;
  }

  /// Case-insensitive match: same city, sub-area, or any shared place token (e.g. Lahore ↔ Lahore Township).
  static bool locationsMatch(String preferred, String hostelLocation) {
    final p = preferred.trim().toLowerCase();
    final h = hostelLocation.trim().toLowerCase();
    if (p.isEmpty || p == 'any' || h.isEmpty) return false;
    if (p == h) return true;

    final pTokens = _allLocationTokens(preferred);
    final hTokens = _allLocationTokens(hostelLocation);

    for (final token in pTokens) {
      if (_tokenAppearsInLocation(token, hostelLocation)) return true;
    }
    for (final token in hTokens) {
      if (_tokenAppearsInLocation(token, preferred)) return true;
    }

    for (final a in pTokens) {
      for (final b in hTokens) {
        if (_locationTokensMatch(a, b)) return true;
      }
    }

    return false;
  }

  HostelRequest? getPendingHostelRequestForStudent(String studentId) {
    for (final r in hostelRequests) {
      if (r.isStudentJoinRequest &&
          r.studentId == studentId &&
          r.status == HostelRequestStatus.pending) {
        return r;
      }
    }
    return null;
  }

  bool studentHasBookedHostel(String studentId) =>
      getBookedHostelRequestForStudent(studentId) != null;

  /// Student may only join one hostel (booked, pending, or assigned room).
  String? studentHostelRequestBlockReason(String studentId, {String? forHostelId}) {
    final student = getStudentById(studentId);
    if (student?.assignedRoomId != null) {
      return 'You already have room ${student!.assignedRoomId}. Cannot request another hostel.';
    }

    final booked = getBookedHostelRequestForStudent(studentId);
    if (booked != null) {
      if (forHostelId != null && booked.hostelId == forHostelId) {
        return 'You are already approved for ${booked.hostelName}.';
      }
      return 'You are already in ${booked.hostelName}. Cannot request another hostel.';
    }

    final pending = getPendingHostelRequestForStudent(studentId);
    if (pending != null) {
      if (forHostelId != null && pending.hostelId == forHostelId) {
        return 'You already have a pending request for ${pending.hostelName}.';
      }
      return 'You already have a pending request for ${pending.hostelName}. Wait for warden approval.';
    }
    return null;
  }

  bool studentCanRequestHostel(String studentId, {String? hostelId}) =>
      studentHostelRequestBlockReason(studentId, forHostelId: hostelId) == null;

  List<Hostel> getHostelsByGender(String gender, {String? preferredLocation}) {
    final loc = preferredLocation ?? currentUser?.preferredLocation ?? '';
    if (loc.trim().isEmpty || loc.trim().toLowerCase() == 'any') return [];

    return hostels
        .where((h) =>
            h.isApproved &&
            h.isBooked &&
            hostelMatchesStudentGender(h, gender) &&
            locationsMatch(loc, h.location))
        .toList();
  }

  bool roomMatchesStudentGender(String roomId, String gender) {
    final hostel = getHostelForRoom(roomId);
    if (hostel == null) return false;
    return hostelMatchesStudentGender(hostel, gender);
  }

  String? sendHostelRequest(String hostelId) {
    if (currentUser == null) return 'Not logged in';
    final user = currentUser!;
    if (user.isAccountBlocked) return 'Your account is blocked. Request unblock first.';

    final blockReason = studentHostelRequestBlockReason(user.studentId, forHostelId: hostelId);
    if (blockReason != null) return blockReason;

    final hostelIdx = hostels.indexWhere((h) => h.id == hostelId);
    if (hostelIdx == -1) return 'Hostel not found';
    final hostel = hostels[hostelIdx];
    if (hostel.assignedAdminId == null) return 'This hostel has no warden yet';
    if (!hostelMatchesStudentGender(hostel, user.gender)) return 'This hostel does not match your gender';

    final request = HostelRequest(
      id: 'SR_${DateTime.now().millisecondsSinceEpoch}',
      studentId: user.studentId,
      studentName: user.name.trim().isNotEmpty ? user.name.trim() : user.studentId.split('@').first,
      hostelId: hostelId,
      hostelName: hostel.hostelName,
      location: hostel.location,
      adminId: hostel.assignedAdminId!,
      adminName: getStudentById(hostel.assignedAdminId!)?.name ?? 'Warden',
      hostelType: hostel.assignedType ?? 'General',
      requestedAt: DateTime.now(),
    );
    hostelRequests.insert(0, request);
    unawaited(_db.saveHostelRequest(request).catchError((_) {}));
    _logStudentActivity(
      currentUser!.studentId,
      currentUser!.name,
      hostelId,
      hostel.hostelName,
      hostel.assignedAdminId!,
      'Hostel join request sent',
    );
    addNotification(
      'New Student Hostel Request',
      '${currentUser!.name} requested ${hostel.hostelName}',
      NotificationType.info,
      targetUserId: hostel.assignedAdminId,
    );
    addNotification(
      'Hostel Request Sent',
      'Your request for ${hostel.hostelName} was sent to the Warden.',
      NotificationType.info,
      targetUserId: currentUser!.studentId,
    );
    notifyListeners();
    return null;
  }

  List<Hostel> getAdminAssignedHostels(String adminId) {
    return hostels.where((h) => h.assignedAdminId == adminId).toList();
  }

  Hostel? getAssignedHostelForAdmin(String adminId) {
    for (final h in hostels) {
      if (h.assignedAdminId == adminId) return h;
    }
    return null;
  }

  bool adminHasAssignedHostel(String adminId) => getAssignedHostelForAdmin(adminId) != null;

  /// Rooms that belong to the hostel booked for this admin.
  List<Room> getRoomsForAdminHostel(String adminId) {
    final hostel = getAssignedHostelForAdmin(adminId);
    if (hostel == null) return [];
    final prefix = '${hostel.id}-';
    return allRooms.where((r) => r.roomId.startsWith(prefix)).toList();
  }

  /// Student hostel join requests sent to this admin (after admin has a hostel).
  List<HostelRequest> getStudentHostelRequestsForAdmin(String adminId) {
    return hostelRequests
        .where((r) => r.adminId == adminId && r.studentId.isNotEmpty)
        .toList();
  }

  Set<String> getRoomIdsForAdminHostel(String adminId) {
    final hostel = getAssignedHostelForAdmin(adminId);
    if (hostel == null) return {};
    final prefix = '${hostel.id}-';
    return allRooms.where((r) => r.roomId.startsWith(prefix)).map((r) => r.roomId).toSet();
  }

  /// Student room payments for rooms under this warden's assigned hostel only.
  List<Payment> getStudentPaymentsForAdminHostel(String adminId) {
    final roomIds = getRoomIdsForAdminHostel(adminId);
    if (roomIds.isEmpty) return [];
    return allPayments
        .where((p) => p.kind == PaymentKind.studentRoom && roomIds.contains(p.roomId))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// All payments made by a user (student or warden own payments).
  List<Payment> getPaymentHistoryForUser(String userId) {
    return allPayments
        .where((p) => p.userId == userId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Warden: member room payments + own hostel fee payments.
  List<Payment> getWardenFullPaymentHistory(String wardenId) {
    final member = getStudentPaymentsForAdminHostel(wardenId);
    final own = allPayments
        .where((p) => p.userId == wardenId && p.kind == PaymentKind.wardenHostel)
        .toList();
    final combined = [...member, ...own];
    combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return combined;
  }

  /// Payment history list for the logged-in role.
  List<Payment> getPaymentHistoryForCurrentUser() {
    if (currentUser == null) return [];
    switch (currentUser!.role) {
      case UserRole.student:
        return getPaymentHistoryForUser(currentUser!.studentId);
      case UserRole.warden:
        return getWardenFullPaymentHistory(currentUser!.studentId);
      case UserRole.admin:
      case UserRole.owner:
        return List<Payment>.from(allPayments)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
  }

  ({int paid, int pending, int failed, int total}) paymentHistoryCounts(List<Payment> payments) {
    var paid = 0;
    var pending = 0;
    var failed = 0;
    for (final p in payments) {
      if (p.status == PaymentStatus.failed) {
        failed++;
      } else if (p.isSettled) {
        paid++;
      } else {
        pending++;
      }
    }
    return (paid: paid, pending: pending, failed: failed, total: payments.length);
  }

  /// Role-scoped payment list (warden → own hostel members only).
  List<Payment> getPaymentsVisibleToCurrentUser() {
    if (currentUser == null) return [];
    if (currentUser!.role == UserRole.warden) {
      return getWardenFullPaymentHistory(currentUser!.studentId);
    }
    if (currentUser!.role == UserRole.student) {
      return getPaymentHistoryForUser(currentUser!.studentId);
    }
    return List<Payment>.from(allPayments)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Paid revenue for rooms under the admin's assigned hostel.
  double getRevenueForAdminHostel(String adminId) {
    final roomIds = getRoomIdsForAdminHostel(adminId);
    if (roomIds.isEmpty) return 0;
    return allPayments
        .where((p) => roomIds.contains(p.roomId) && (p.status == PaymentStatus.paid || p.status == PaymentStatus.confirmed))
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  /// Students linked to admin's hostel (requested or occupying a room there).
  int getActiveStudentCountForAdmin(String adminId) {
    final students = getStudentsWhoRequestedAdmin(adminId);
    final hostel = getAssignedHostelForAdmin(adminId);
    if (hostel == null) return students.length;
    final prefix = '${hostel.id}-';
    final occupantIds = <String>{};
    for (final room in allRooms.where((r) => r.roomId.startsWith(prefix))) {
      occupantIds.addAll(room.occupantsIds);
    }
    return {...students.map((s) => s.studentId), ...occupantIds}.length;
  }

  List<Student> getStudentsWhoRequestedAdmin(String adminId) {
    final ids = getStudentHostelRequestsForAdmin(adminId).map((r) => r.studentId).toSet();
    return allStudents.where((s) => ids.contains(s.studentId)).toList();
  }

  HostelRequest? getStudentHostelRequestRecord(String adminId, String studentId) {
    for (final r in getStudentHostelRequestsForAdmin(adminId)) {
      if (r.studentId == studentId) return r;
    }
    return null;
  }

  /// Admin Matched Pairs: same booked hostel + high compatibility + mutual accepted roommate request.
  List<HostelMatchPair> getEligibleHostelMatchPairs(String adminId, {double minScore = 75}) {
    final hostel = getAssignedHostelForAdmin(adminId);
    if (hostel == null) return [];

    final requests = getStudentHostelRequestsForAdmin(adminId)
        .where((r) => r.hostelId == hostel.id && r.status == HostelRequestStatus.booked)
        .toList();

    final studentIds = requests.map((r) => r.studentId).toSet().toList();
    final pairs = <HostelMatchPair>[];

    for (int i = 0; i < studentIds.length; i++) {
      for (int j = i + 1; j < studentIds.length; j++) {
        final idA = studentIds[i];
        final idB = studentIds[j];

        if (!hasAcceptedRoommateRequestBetween(idA, idB)) continue;

        Student s1;
        Student s2;
        try {
          s1 = allStudents.firstWhere((s) => s.studentId == idA);
          s2 = allStudents.firstWhere((s) => s.studentId == idB);
        } catch (_) {
          continue;
        }

        if (s1.assignedRoomId != null || s2.assignedRoomId != null) continue;

        final score = engine.calculateDetailedCompatibility(s1, s2).compatibilityScore;
        if (score < minScore) continue;

        pairs.add(HostelMatchPair(s1, s2, score, hostel.id));
      }
    }

    pairs.sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));
    return pairs;
  }

  bool approveStudentHostelRequest(String requestId) {
    final idx = hostelRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final request = hostelRequests[idx];
    if (!request.isStudentJoinRequest) return false;
    if (request.status != HostelRequestStatus.pending) return false;

    request.status = HostelRequestStatus.booked;
    unawaited(_db.saveHostelRequest(request).catchError((_) {}));
    addNotification(
      'Hostel Request Approved',
      'Your request for ${request.hostelName} was approved by the Warden.',
      NotificationType.info,
      targetUserId: request.studentId,
    );
    _logStudentActivity(
      request.studentId,
      request.studentName,
      request.hostelId,
      request.hostelName,
      request.adminId,
      'Hostel request approved',
    );
    notifyListeners();
    return true;
  }

  void rejectStudentHostelRequest(String requestId, {String? message}) {
    final idx = hostelRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;

    final request = hostelRequests[idx];
    if (!request.isStudentJoinRequest) return;
    if (request.status != HostelRequestStatus.pending) return;

    request.status = HostelRequestStatus.rejected;
    unawaited(_db.saveHostelRequest(request).catchError((_) {}));
    request.adminFeedback = message;
    addNotification(
      'Hostel Request Rejected',
      message ?? 'Your request for ${request.hostelName} was rejected by the Warden.',
      NotificationType.info,
      targetUserId: request.studentId,
    );
    _logStudentActivity(
      request.studentId,
      request.studentName,
      request.hostelId,
      request.hostelName,
      request.adminId,
      'Hostel request rejected',
    );
    notifyListeners();
  }

  List<HostelRequest> getAdminRequests(String adminId) {
    return hostelRequests.where((r) => r.adminId == adminId).toList();
  }

  void updateProfile(Student updatedStudent) {
    int idx = allStudents.indexWhere((s) => s.studentId == updatedStudent.studentId);
    if (idx != -1) {
      allStudents[idx] = updatedStudent;
      
      // Also update role-specific lists
      if (updatedStudent.role == UserRole.admin) {
        int aIdx = admins.indexWhere((s) => s.studentId == updatedStudent.studentId);
        if (aIdx != -1) admins[aIdx] = updatedStudent;
      } else if (updatedStudent.role == UserRole.warden) {
        int wIdx = wardens.indexWhere((s) => s.studentId == updatedStudent.studentId);
        if (wIdx != -1) wardens[wIdx] = updatedStudent;
      } else if (updatedStudent.role == UserRole.owner) {
        int oIdx = owners.indexWhere((s) => s.studentId == updatedStudent.studentId);
        if (oIdx != -1) owners[oIdx] = updatedStudent;
      }

      if (currentUser?.studentId == updatedStudent.studentId) currentUser = updatedStudent;
      unawaited(_db.saveUser(updatedStudent).catchError((_) {}));
      notifyListeners();
    }
  }

  // Notifications
  void addNotification(String title, String message, NotificationType type, {String? targetUserId}) {
    allNotifications.insert(
      0,
      AppNotification(
        id: 'NOTIF_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        message: message,
        type: type,
        targetUserId: targetUserId,
      ),
    );
    notifyListeners();
  }

  List<AppNotification> getNotificationsForCurrentUser() {
    if (currentUser == null) return [];
    if (currentUser!.role == UserRole.admin ||
        currentUser!.role == UserRole.warden ||
        currentUser!.role == UserRole.owner) {
      return List<AppNotification>.from(allNotifications)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return allNotifications
        .where((n) => n.targetUserId == currentUser!.studentId)
        .toList();
  }

  List<ActivityLogEntry> getActivityLogsForWarden(String adminId) {
    final hostel = getAssignedHostelForAdmin(adminId);
    if (hostel == null) return [];

    final roomIds = getRoomIdsForAdminHostel(adminId);
    final logs = <ActivityLogEntry>[];

    for (final n in allNotifications.where((n) => n.targetUserId == adminId)) {
      logs.add(ActivityLogEntry(
        time: n.timestamp,
        category: 'Alert',
        title: n.title,
        detail: n.message,
      ));
    }

    for (final r in getStudentHostelRequestsForAdmin(adminId)) {
      logs.add(ActivityLogEntry(
        time: r.requestedAt,
        category: 'Student',
        title: 'Hostel join: ${r.hostelName}',
        detail: '${r.studentName} · ${r.status.displayLabel}',
      ));
    }

    for (final r in getRequestsByAdmin(adminId).where((r) => r.isWardenAssignmentRequest)) {
      logs.add(ActivityLogEntry(
        time: r.requestedAt,
        category: 'Hostel',
        title: 'Your hostel request',
        detail: '${r.hostelName} · ${r.hostelType} · ${r.status.displayLabel}',
      ));
    }

    for (final p in getStudentPaymentsForAdminHostel(adminId)) {
      final student = getStudentById(p.userId);
      final name = student?.name.isNotEmpty == true ? student!.name : p.userId;
      logs.add(ActivityLogEntry(
        time: p.timestamp,
        category: 'Payment',
        title: 'Payment ${p.status.name}',
        detail: '$name · Rs.${p.amount.toInt()} · Room ${p.roomId}',
      ));
    }

    final memberIds = getStudentsWhoRequestedAdmin(adminId).map((s) => s.studentId).toSet();
    for (final r in unblockRequests.where((r) => memberIds.contains(r.studentId))) {
      logs.add(ActivityLogEntry(
        time: r.requestedAt,
        category: 'Account',
        title: 'Unblock: ${r.studentName}',
        detail: '${r.status.displayLabel} · ${r.message}',
      ));
    }

    logs.sort((a, b) => b.time.compareTo(a.time));
    return logs;
  }

  List<ActivityLogEntry> getActivityLogsVisibleToCurrentUser() {
    if (currentUser?.role == UserRole.warden) {
      return getActivityLogsForWarden(currentUser!.studentId);
    }
    return getSystemActivityLogs();
  }

  List<ActivityLogEntry> getSystemActivityLogs() {
    final logs = <ActivityLogEntry>[];

    for (final n in allNotifications) {
      logs.add(ActivityLogEntry(
        time: n.timestamp,
        category: 'Alert',
        title: n.title,
        detail: n.message,
      ));
    }

    for (final r in hostelRequests) {
      if (r.isWardenAssignmentRequest) {
        logs.add(ActivityLogEntry(
          time: r.requestedAt,
          category: 'Hostel',
          title: 'Warden request: ${wardenNameForRequest(r)}',
          detail: '${r.hostelName} · ${r.hostelType} · ${r.status.displayLabel}',
        ));
      } else {
        logs.add(ActivityLogEntry(
          time: r.requestedAt,
          category: 'Student',
          title: 'Hostel join: ${r.hostelName}',
          detail: '${r.studentName} · ${r.status.displayLabel}',
        ));
      }
    }

    for (final r in unblockRequests) {
      logs.add(ActivityLogEntry(
        time: r.requestedAt,
        category: 'Account',
        title: 'Unblock: ${r.studentName}',
        detail: '${r.status.displayLabel} · ${r.message}',
      ));
    }

    for (final p in allPayments) {
      logs.add(ActivityLogEntry(
        time: p.timestamp,
        category: 'Payment',
        title: 'Payment ${p.status.name}',
        detail: '${p.userId} · Rs.${p.amount.toInt()} · ${p.paymentMonth ?? "—"} · Room ${p.roomId}',
      ));
    }

    for (final s in allStudents.where((s) => s.isAccountBlocked)) {
      if (s.blockedAt != null) {
        logs.add(ActivityLogEntry(
          time: s.blockedAt!,
          category: 'Account',
          title: 'Blocked: ${s.name.isNotEmpty ? s.name : s.studentId}',
          detail: s.blockReason ?? 'No reason recorded',
        ));
      }
    }

    logs.sort((a, b) => b.time.compareTo(a.time));
    return logs;
  }

  void markNotificationRead(String id) {
    final idx = allNotifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      allNotifications[idx].isRead = true;
      notifyListeners();
    }
  }

  void markAllNotificationsRead() {
    for (final n in allNotifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void clearNotifications() { allNotifications.clear(); notifyListeners(); }

  HostelRequest? getBookedHostelRequestForStudent(String studentId) {
    for (final r in hostelRequests) {
      if (r.isStudentJoinRequest &&
          r.studentId == studentId &&
          r.status == HostelRequestStatus.booked) {
        return r;
      }
    }
    return null;
  }

  bool hasAcceptedRoommateRequestBetween(String studentIdA, String studentIdB) {
    return allRequests.any((r) =>
        r.type == RequestType.roommate &&
        r.status == RequestStatus.accepted &&
        ((r.senderId == studentIdA && r.receiverId == studentIdB) ||
            (r.senderId == studentIdB && r.receiverId == studentIdA)));
  }

  // Room & Roommate Matching
  String? getHostelIdForRoom(String roomId) {
    final dash = roomId.indexOf('-');
    if (dash <= 0) return null;
    return roomId.substring(0, dash);
  }

  Hostel? getHostelForRoom(String roomId) {
    final hid = getHostelIdForRoom(roomId);
    if (hid == null) return null;
    for (final h in hostels) {
      if (h.id == hid) return h;
    }
    return null;
  }

  /// Room rent must not exceed student's monthly budget (profile slider value).
  static bool roomFitsBudget(double roomPrice, double monthlyBudget) {
    if (monthlyBudget <= 0) return false;
    return roomPrice <= monthlyBudget;
  }

  /// Higher when price is closer to budget from below (uses full budget, not over).
  static int budgetFitScore(double roomPrice, double monthlyBudget) {
    if (!roomFitsBudget(roomPrice, monthlyBudget)) return 0;
    final ratio = roomPrice / monthlyBudget;
    return (40 * ratio.clamp(0.0, 1.0)).round();
  }

  /// 0–100 match based on student profile (budget, facilities, sharing).
  int getRoomPreferenceScore(Room room, Student user) {
    int score = 0;
    final price = room.calculateTotalPrice();
    score += budgetFitScore(price, user.budget);
    if (!user.requiresAC || room.hasAC) score += 20;
    if (!user.requiresAttachedBath || room.hasAttachedBathroom) score += 15;
    if (!user.requiresWifi || room.hasWifi) score += 15;
    if (!user.requiresFurnished || room.isFurnished) score += 10;
    if (user.requiresKitchen && room.hasKitchenAccess) score += 5;
    if (user.requiresLaundry && room.hasLaundry) score += 5;
    if (user.preferredSharing == 'Any' || room.sharingType == user.preferredSharing) score += 10;
    return score.clamp(0, 100);
  }

  /// Suggested rooms after hostel booked: same hostel, rent ≤ profile budget, facilities match.
  List<Room> getRecommendedRooms() {
    if (currentUser == null || !currentUser!.profileCompleted || currentUser!.isAccountBlocked) {
      return [];
    }
    if (currentUser!.assignedRoomId != null) return [];

    final user = currentUser!;
    final booked = getBookedHostelRequestForStudent(user.studentId);
    if (booked == null) return [];

    Hostel? hostel;
    for (final h in hostels) {
      if (h.id == booked.hostelId) {
        hostel = h;
        break;
      }
    }
    if (hostel == null) return [];
    if (!locationsMatch(user.preferredLocation, hostel.location)) return [];

    final rooms = allRooms.where((room) {
      final hostelId = getHostelIdForRoom(room.roomId);
      if (hostelId != booked.hostelId) return false;
      if (!roomMatchesStudentGender(room.roomId, user.gender)) return false;
      if (room.isFull()) return false;
      if (rejectedRoomIds.contains(room.roomId)) return false;
      final price = room.calculateTotalPrice();
      if (!roomFitsBudget(price, user.budget)) return false;
      if (user.requiresAC && !room.hasAC) return false;
      if (user.requiresAttachedBath && !room.hasAttachedBathroom) return false;
      if (user.requiresWifi && !room.hasWifi) return false;
      if (user.requiresFurnished && !room.isFurnished) return false;
      if (user.requiresKitchen && !room.hasKitchenAccess) return false;
      if (user.requiresLaundry && !room.hasLaundry) return false;
      return true;
    }).toList();

    rooms.sort((a, b) {
      final scoreCmp = getRoomPreferenceScore(b, user).compareTo(getRoomPreferenceScore(a, user));
      if (scoreCmp != 0) return scoreCmp;
      final priceA = a.calculateTotalPrice();
      final priceB = b.calculateTotalPrice();
      final gapA = user.budget - priceA;
      final gapB = user.budget - priceB;
      return gapA.compareTo(gapB);
    });
    return rooms;
  }

  /// Suggested users: both must have admin-approved (booked) hostel request for the same hostel + high match.
  List<StudentMatch> getSuggestedRoommatesForCurrentUser({double minScore = 75, int topN = 10}) {
    if (currentUser == null) return [];
    final myHostelReq = getBookedHostelRequestForStudent(currentUser!.studentId);
    if (myHostelReq == null) return [];

    final matches = <StudentMatch>[];
    for (final candidate in allStudents) {
      if (candidate.role != UserRole.student) continue;
      if (candidate.studentId == currentUser!.studentId) continue;
      if (candidate.assignedRoomId != null) continue;
      if (candidate.gender != currentUser!.gender) continue;

      final theirHostelReq = getBookedHostelRequestForStudent(candidate.studentId);
      if (theirHostelReq == null) continue;
      if (theirHostelReq.hostelId != myHostelReq.hostelId) continue;

      final match = engine.calculateDetailedCompatibility(currentUser!, candidate);
      if (match.compatibilityScore >= minScore) {
        matches.add(match);
      }
    }

    matches.sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));
    return matches.take(topN).toList();
  }

  List<StudentMatch> getMatchesForCurrentUser(int topN) {
    return getSuggestedRoommatesForCurrentUser(topN: topN);
  }

  void requestRoom(String roomId) {
    if (currentUser == null || currentUser!.assignedRoomId != null) return;
    if (!currentUser!.profileCompleted) return;
    if (!roomMatchesStudentGender(roomId, currentUser!.gender)) return;

    currentUser!.requestedRoomId = roomId;
    final idx = allStudents.indexWhere((s) => s.studentId == currentUser!.studentId);
    if (idx != -1) {
      allStudents[idx].requestedRoomId = roomId;
    }

    final hostel = getHostelForRoom(roomId);
    final hostelName = hostel?.hostelName ?? 'Hostel';
    final adminId = hostel?.assignedAdminId;

    addNotification(
      'New Room Request',
      '${currentUser!.name} requested Room $roomId ($hostelName)',
      NotificationType.requestReceived,
      targetUserId: adminId,
    );
    addNotification(
      'Room Request Sent',
      'Your request for Room $roomId was sent to the Admin for $hostelName.',
      NotificationType.info,
      targetUserId: currentUser!.studentId,
    );
    notifyListeners();
  }

  bool hasRequestedRoom(String roomId) {
    return currentUser?.requestedRoomId == roomId;
  }

  void rejectRoomRequest(String studentId) {
    int idx = allStudents.indexWhere((s) => s.studentId == studentId);
    if (idx != -1) {
      String? roomId = allStudents[idx].requestedRoomId;
      allStudents[idx].requestedRoomId = null;
      if (currentUser?.studentId == studentId) {
        currentUser!.requestedRoomId = null;
      }
      addNotification('Room Request Rejected', 'Your request for Room $roomId was rejected by Admin.', NotificationType.info, targetUserId: studentId);
      notifyListeners();
    }
  }

  void rejectRoom(String roomId) {
    if (!rejectedRoomIds.contains(roomId)) {
      rejectedRoomIds.add(roomId);
      notifyListeners();
    }
  }

  // Request Management
  void sendRoommateRequest(String receiverId, double score) {
    if (currentUser == null) return;
    if (isAlreadyMatched(currentUser!.studentId) || isAlreadyMatched(receiverId)) return;
    if (!canSendRoommateRequest(receiverId)) return;

    var receiver = allStudents.firstWhere((s) => s.studentId == receiverId);
    final request = RoommateRequest(
      id: 'REQ_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUser!.studentId,
      receiverId: receiver.studentId,
      senderName: currentUser!.name,
      receiverName: receiver.name,
      compatibilityScore: score,
    );
    allRequests.add(request);
    unawaited(_db.saveRoommateRequest(request).catchError((_) {}));
    addNotification('Roommate Request', '${currentUser!.name} sent you a roommate request', NotificationType.requestReceived, targetUserId: receiverId);
    notifyListeners();
  }

  bool approveRoommateRequest(String requestId) {
    final idx = allRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final req = allRequests[idx];
    if (req.status != RequestStatus.pending) return false;
    if (currentUser != null &&
        req.receiverId != currentUser!.studentId &&
        req.senderId != currentUser!.studentId) {
      return false;
    }

    req.status = RequestStatus.accepted;
    req.respondedAt = DateTime.now();

    if (req.type == RequestType.roommate) {
      req.isMatched = true;
      final removedIds = <String>[];
      allRequests.removeWhere((r) {
        if (r.id == requestId) return false;
        if (r.type != RequestType.roommate) return false;
        final involvesPair = r.senderId == req.senderId ||
            r.senderId == req.receiverId ||
            r.receiverId == req.senderId ||
            r.receiverId == req.receiverId;
        if (involvesPair) removedIds.add(r.id);
        return involvesPair;
      });

      final s1Idx = allStudents.indexWhere((s) => s.studentId == req.senderId);
      final s2Idx = allStudents.indexWhere((s) => s.studentId == req.receiverId);
      if (s1Idx != -1) {
        allStudents[s1Idx].roommateId = req.receiverId;
        if (currentUser?.studentId == req.senderId) currentUser?.roommateId = req.receiverId;
        unawaited(_db.saveUser(allStudents[s1Idx]).catchError((_) {}));
      }
      if (s2Idx != -1) {
        allStudents[s2Idx].roommateId = req.senderId;
        if (currentUser?.studentId == req.receiverId) currentUser?.roommateId = req.senderId;
        unawaited(_db.saveUser(allStudents[s2Idx]).catchError((_) {}));
      }

      for (final id in removedIds) {
        unawaited(_db.deleteRoommateRequest(id).catchError((_) {}));
      }

      addNotification('Match Confirmed', 'Your roommate request was approved by ${req.receiverName}', NotificationType.roommateMatched, targetUserId: req.senderId);
      addNotification('Match Confirmed', 'You are now matched with ${req.senderName}', NotificationType.roommateMatched, targetUserId: req.receiverId);

      final senderHostel = getBookedHostelRequestForStudent(req.senderId);
      if (senderHostel != null) {
        addNotification(
          'New Matched Pair',
          '${req.senderName} & ${req.receiverName} accepted each other — assign a room in Matched Pairs.',
          NotificationType.roommateMatched,
          targetUserId: senderHostel.adminId,
        );
      }
    } else {
      addNotification('Request Accepted', '${req.receiverName} accepted your skill share request', NotificationType.info, targetUserId: req.senderId);
    }

    unawaited(_db.saveRoommateRequest(req).catchError((_) {}));
    unawaited(_persistToFirestore().catchError((_) {}));
    notifyListeners();
    return true;
  }

  bool rejectRoommateRequest(String requestId) {
    final idx = allRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final req = allRequests[idx];
    if (req.status != RequestStatus.pending) return false;

    req.status = RequestStatus.rejected;
    req.respondedAt = DateTime.now();
    final typeLabel = req.type == RequestType.skillShare ? 'skill' : 'roommate';
    addNotification(
      'Request Rejected',
      'Your $typeLabel request was rejected by ${req.receiverName}',
      NotificationType.info,
      targetUserId: req.senderId,
    );
    unawaited(_db.saveRoommateRequest(req).catchError((_) {}));
    notifyListeners();
    return true;
  }

  bool canSendRoommateRequest(String receiverId) {
    if (currentUser == null) return false;
    if (isAlreadyMatched(currentUser!.studentId) || isAlreadyMatched(receiverId)) return false;
    
    bool hasReverse = allRequests.any((r) => 
      r.type == RequestType.roommate && 
      r.senderId == receiverId && 
      r.receiverId == currentUser!.studentId && 
      r.status == RequestStatus.pending
    );
    if (hasReverse) return false;

    bool hasDuplicate = allRequests.any((r) => 
      r.type == RequestType.roommate && 
      r.senderId == currentUser!.studentId && 
      r.receiverId == receiverId && 
      (r.status == RequestStatus.pending || r.status == RequestStatus.accepted)
    );
    if (hasDuplicate) return false;

    return true;
  }

  bool isAlreadyMatched(String studentId) {
    try {
      var student = allStudents.firstWhere((s) => s.studentId == studentId);
      return student.roommateId != null;
    } catch (e) {
      return false;
    }
  }

  List<RoommateRequest> getPendingRequests() {
    return allRequests.where((r) => r.status == RequestStatus.pending).toList();
  }

  List<RoommateRequest> getConfirmedMatches() {
    return allRequests.where((r) => r.isMatched == true).toList();
  }

  // Admin Review
  void approveMatch(String requestId) {
    int idx = allRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      allRequests[idx].adminStatus = AdminStatus.approved;
      notifyListeners();
    }
  }

  // Skill Sharing — same-gender students only
  List<Student> getSkillPeers() {
    if (currentUser == null) return [];
    final myGender = currentUser!.gender.trim().toLowerCase();
    if (myGender.isEmpty) return [];

    return allStudents.where((s) {
      if (s.studentId == currentUser!.studentId) return false;
      if (s.role != UserRole.student) return false;
      return s.gender.trim().toLowerCase() == myGender;
    }).toList();
  }

  void sendSkillShareRequest(Student receiver, String skill) {
    if (currentUser == null) return;
    final request = RoommateRequest(
      id: 'SKILL_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUser!.studentId,
      receiverId: receiver.studentId,
      senderName: currentUser!.name,
      receiverName: receiver.name,
      type: RequestType.skillShare,
      skillName: skill,
    );
    allRequests.add(request);
    unawaited(_db.saveRoommateRequest(request).catchError((_) {}));
    addNotification(
      'Skill Request',
      '${currentUser!.name} wants to exchange skill: $skill',
      NotificationType.requestReceived,
      targetUserId: receiver.studentId,
    );
    notifyListeners();
  }

  // Payment Management

  bool hasSettledPaymentForMonth({
    required String userId,
    required String paymentMonth,
    PaymentKind kind = PaymentKind.studentRoom,
    String? hostelId,
    String? roomId,
  }) {
    final month = paymentMonth.trim();
    if (month.isEmpty) return false;
    return allPayments.any((p) {
      if (p.userId != userId || !p.isSettled || p.kind != kind) return false;
      if (p.paymentMonth?.trim() != month) return false;
      if (hostelId != null && p.hostelId != hostelId) return false;
      if (roomId != null && roomId.isNotEmpty && p.roomId != roomId) return false;
      return true;
    });
  }

  Set<String> _paidMonthsFor({
    required String userId,
    required PaymentKind kind,
    String? hostelId,
    String? roomId,
  }) {
    return allPayments
        .where((p) {
          if (p.userId != userId || !p.isSettled || p.kind != kind) return false;
          if (hostelId != null && p.hostelId != hostelId) return false;
          if (roomId != null && roomId.isNotEmpty && p.roomId != roomId) return false;
          return p.paymentMonth != null && p.paymentMonth!.trim().isNotEmpty;
        })
        .map((p) => p.paymentMonth!.trim())
        .toSet();
  }

  List<String> getAvailablePaymentMonthsForStudent(String studentId) {
    final student = getStudentById(studentId);
    final roomId = student?.assignedRoomId;
    if (roomId == null || roomId.isEmpty) return [];
    final paid = _paidMonthsFor(
      userId: studentId,
      kind: PaymentKind.studentRoom,
      roomId: roomId,
    );
    return paymentMonthOptions().where((m) => !paid.contains(m)).toList();
  }

  List<String> getAvailablePaymentMonthsForWarden(String wardenId, String hostelId) {
    final paid = _paidMonthsFor(
      userId: wardenId,
      kind: PaymentKind.wardenHostel,
      hostelId: hostelId,
    );
    return paymentMonthOptions().where((m) => !paid.contains(m)).toList();
  }

  bool studentHasPaidForMonth(String studentId, String paymentMonth, {String? roomId}) {
    return hasSettledPaymentForMonth(
      userId: studentId,
      paymentMonth: paymentMonth,
      roomId: roomId,
    );
  }

  bool wardenHasPaidForMonth(String wardenId, String hostelId, String paymentMonth) {
    return hasSettledPaymentForMonth(
      userId: wardenId,
      paymentMonth: paymentMonth,
      kind: PaymentKind.wardenHostel,
      hostelId: hostelId,
    );
  }

  bool studentNeedsRentPayment(Student s) {
    if (s.assignedRoomId == null || s.assignedRoomId!.isEmpty) return false;
    if (s.assignmentStatus != AssignmentStatus.accepted &&
        s.assignmentStatus != AssignmentStatus.confirmed) {
      return false;
    }
    return getAvailablePaymentMonthsForStudent(s.studentId).isNotEmpty;
  }

  String? makePayment(String method, {String? cardLast4Digits, required String paymentMonth}) {
    if (currentUser == null || currentUser!.assignedRoomId == null) {
      return 'No room assigned for payment';
    }
    final room = allRooms.firstWhere((r) => r.roomId == currentUser!.assignedRoomId);

    if (hasSettledPaymentForMonth(
      userId: currentUser!.studentId,
      paymentMonth: paymentMonth,
      roomId: room.roomId,
    )) {
      return 'You already paid for $paymentMonth. Each month can be paid only once.';
    }

    final payment = Payment(
      paymentId: 'PAY_${DateTime.now().millisecondsSinceEpoch}',
      userId: currentUser!.studentId,
      roomId: room.roomId,
      amount: room.calculateTotalPrice(),
      paymentMethod: method,
      status: PaymentStatus.paid,
      cardLast4Digits: cardLast4Digits,
      paymentMonth: paymentMonth,
    );
    allPayments.add(payment);

    int sIdx = allStudents.indexWhere((s) => s.studentId == currentUser!.studentId);
    if (sIdx != -1) {
      allStudents[sIdx].paymentVerified = true;
      allStudents[sIdx].assignmentStatus = AssignmentStatus.confirmed;
      currentUser = allStudents[sIdx];
    }

    addNotification(
      'Payment Successful',
      'Your payment for $paymentMonth via $method was successful.',
      NotificationType.paymentConfirmed,
    );
    notifyListeners();
    return null;
  }

  void verifyPayment(String paymentId) {
    int idx = allPayments.indexWhere((p) => p.paymentId == paymentId);
    if (idx != -1) {
      allPayments[idx] = allPayments[idx].copyWith(status: PaymentStatus.paid);
      int sIdx = allStudents.indexWhere((s) => s.studentId == allPayments[idx].userId);
      if (sIdx != -1) {
        allStudents[sIdx].paymentVerified = true;
        allStudents[sIdx].assignmentStatus = AssignmentStatus.confirmed;
        addNotification('Payment Verified', 'Your payment has been successfully verified! Your booking is confirmed.', NotificationType.paymentConfirmed, targetUserId: allPayments[idx].userId);
        addNotification('Payment Verified', 'Payment from ${allStudents[sIdx].name} verified.', NotificationType.paymentConfirmed);
      }
      notifyListeners();
    }
  }

  // Room Assignment
  bool assignRoom(Student s1, Student s2, Room room) {
    if (room.capacity - room.currentOccupancy < 2) return false;
    room.addOccupant(s1.studentId);
    room.addOccupant(s2.studentId);
    s1.assignedRoomId = room.roomId;
    s2.assignedRoomId = room.roomId;
    s1.roommateId = s2.studentId;
    s2.roommateId = s1.studentId;
    s1.assignmentStatus = AssignmentStatus.assigned;
    s2.assignmentStatus = AssignmentStatus.assigned;
    addNotification('Room Assigned', 'Admin assigned you to Room ${room.roomId} with ${s2.name}. Please accept to proceed.', NotificationType.roomAssigned, targetUserId: s1.studentId);
    addNotification('Room Assigned', 'Admin assigned you to Room ${room.roomId} with ${s1.name}. Please accept to proceed.', NotificationType.roomAssigned, targetUserId: s2.studentId);
    notifyListeners();
    return true;
  }

  bool assignStudentToRoom(Student s, Room room) {
    if (room.isFull()) return false;
    room.addOccupant(s.studentId);
    s.assignedRoomId = room.roomId;
    s.requestedRoomId = null; 
    s.assignmentStatus = AssignmentStatus.assigned;
    addNotification('Room Assigned', 'Admin assigned you to Room ${room.roomId}. Please accept to proceed.', NotificationType.roomAssigned, targetUserId: s.studentId);
    notifyListeners();
    return true;
  }

  void acceptAssignedRoom(Student s) {
    s.assignmentStatus = AssignmentStatus.accepted;
    _syncStudent(s);
    addNotification('Room Accepted', 'You accepted Room ${s.assignedRoomId}. You can now proceed to payment.', NotificationType.info, targetUserId: s.studentId);
    addNotification('Room Accepted', '${s.name} accepted the assigned Room ${s.assignedRoomId}.', NotificationType.info);
    notifyListeners();
  }

  void rejectAssignedRoom(Student s) {
    final roomId = s.assignedRoomId;
    if (roomId == null) return;

    if (s.roommateId != null) {
      final roommate = getStudentById(s.roommateId!);
      if (roommate != null) {
        roommate.roommateId = null;
        if (roommate.assignedRoomId == roomId) {
          roommate.assignedRoomId = null;
          roommate.assignmentStatus = AssignmentStatus.none;
        }
        _syncStudent(roommate);
      }
    }

    final room = allRooms.firstWhere((r) => r.roomId == roomId);
    room.removeOccupant(s.studentId);
    s.assignedRoomId = null;
    s.roommateId = null;
    s.assignmentStatus = AssignmentStatus.rejected;
    _syncStudent(s);
    addNotification('Room Rejected', 'You rejected Room $roomId.', NotificationType.info, targetUserId: s.studentId);
    addNotification('Room Rejected', '${s.name} rejected the assigned Room $roomId.', NotificationType.info);
    notifyListeners();
  }

  void unassignFromRoom(Student s) {
    if (s.assignedRoomId != null) {
      var room = allRooms.firstWhere((r) => r.roomId == s.assignedRoomId);
      room.removeOccupant(s.studentId);
      s.assignedRoomId = null;
      s.roommateId = null;
      s.paymentVerified = false;
      s.assignmentStatus = AssignmentStatus.none;
      _syncStudent(s);
      notifyListeners();
    }
  }

  String? wardenLeaveAssignedHostel(Student warden) {
    if (currentUser?.role != UserRole.warden || currentUser!.studentId != warden.studentId) {
      return 'Only logged-in warden can use this action';
    }
    final hostel = getAssignedHostelForAdmin(warden.studentId);
    if (hostel == null) return 'No assigned hostel to leave';

    final roomPrefix = '${hostel.id}-';
    final hasOccupants = allRooms
        .where((r) => r.roomId.startsWith(roomPrefix))
        .any((r) => r.occupantsIds.isNotEmpty);
    if (hasOccupants) {
      return 'Cannot leave now: students are currently assigned in this hostel.';
    }

    final hasBookedStudents = hostelRequests.any((r) =>
        r.adminId == warden.studentId &&
        r.isStudentJoinRequest &&
        r.status == HostelRequestStatus.booked);
    if (hasBookedStudents) {
      return 'Cannot leave now: approved student hostel requests still exist.';
    }

    for (final r in hostelRequests.where((r) =>
        r.adminId == warden.studentId &&
        r.isStudentJoinRequest &&
        r.status == HostelRequestStatus.pending)) {
      r.status = HostelRequestStatus.rejected;
      r.adminFeedback = 'Warden left this hostel. Please request another hostel.';
      addNotification(
        'Hostel Request Cancelled',
        'Your hostel request for ${r.hostelName} was cancelled because the warden left.',
        NotificationType.info,
        targetUserId: r.studentId,
      );
    }

    hostel.assignedAdminId = null;
    hostel.assignedType = null;
    warden.isAccountBlocked = true;
    warden.blockReason = 'Left hostel ${hostel.hostelName}';
    warden.blockedAt = DateTime.now();
    _syncStudent(warden);
    allRooms = roomsFromHostels(hostels);

    addNotification(
      'Warden Left Hostel',
      '${warden.name} left ${hostel.hostelName}. You can assign a new warden.',
      NotificationType.info,
      targetUserId: platformAdminEmail,
    );
    addNotification(
      'Warden Left Hostel',
      'Your warden ${warden.name} left ${hostel.hostelName}. Request a replacement warden.',
      NotificationType.info,
      targetUserId: hostel.createdByOwner,
    );
    addNotification(
      'Hostel Left',
      'You left ${hostel.hostelName}. Your account is blocked until owner/admin approves unblock request.',
      NotificationType.info,
      targetUserId: warden.studentId,
    );
    notifyListeners();
    return null;
  }

  String? ownerLeavePlatform(Student owner) {
    if (currentUser?.role != UserRole.owner || currentUser!.studentId != owner.studentId) {
      return 'Only logged-in owner can use this action';
    }

    final myHostels = getHostelsForOwner(owner.studentId);
    if (myHostels.isNotEmpty) {
      return 'Transfer your hostels to another owner first, then leave.';
    }

    final managedWardens = getWardensForOwner(owner.studentId);
    for (final w in managedWardens) {
      w.managedByOwnerId = null;
      _syncStudent(w);
      addNotification(
        'Owner Left Platform',
        'Your owner left. Ask platform admin for reassignment.',
        NotificationType.info,
        targetUserId: w.studentId,
      );
    }

    owner.isAccountBlocked = true;
    owner.blockReason = 'Owner left platform';
    owner.blockedAt = DateTime.now();
    _syncStudent(owner);

    addNotification(
      'Owner Left Platform',
      '${owner.name} left the platform. You can assign their wardens/hostels to new owner.',
      NotificationType.info,
      targetUserId: platformAdminEmail,
    );
    addNotification(
      'Account Left',
      'You left the platform. Account is blocked until admin approval.',
      NotificationType.info,
      targetUserId: owner.studentId,
    );
    notifyListeners();
    return null;
  }

  bool wardenManagesStudent(String wardenId, String studentId) {
    final w = _normalizeId(wardenId);
    final s = _normalizeId(studentId);
    return hostelRequests.any(
      (r) =>
          r.isStudentJoinRequest &&
          _normalizeId(r.studentId) == s &&
          _normalizeId(r.adminId) == w,
    );
  }

  Future<bool> _applyBlock(Student target, String detail, String blockedByLabel) async {
    if (target.email.trim().isEmpty && target.studentId.contains('@')) {
      target.email = _normalizeId(target.studentId);
    }
    target.isAccountBlocked = true;
    target.blockReason = detail.trim().isEmpty ? 'Blocked by $blockedByLabel' : detail.trim();
    target.blockedAt = DateTime.now();
    _syncStudent(target, persist: false);

    try {
      await _db.saveBlockedUser(target);
    } catch (_) {
      return false;
    }

    addNotification(
      'Account Blocked',
      'Your account was blocked by $blockedByLabel: ${target.blockReason}',
      NotificationType.info,
      targetUserId: target.studentId,
    );
    return true;
  }

  /// Warden blocks a student under their hostel.
  Future<bool> wardenBlockStudent(String studentId, String detail) async {
    if (currentUser?.role != UserRole.warden) return false;
    final s = getStudentById(studentId);
    if (s == null || s.role != UserRole.student) return false;
    if (!wardenManagesStudent(currentUser!.studentId, studentId)) return false;

    if (s.assignedRoomId != null) {
      final room = allRooms.firstWhere((r) => r.roomId == s.assignedRoomId);
      room.removeOccupant(s.studentId);
      s.lastLeftRoomId = s.assignedRoomId;
      s.assignedRoomId = null;
      s.roommateId = null;
    }
    s.paymentVerified = false;
    s.assignmentStatus = AssignmentStatus.none;

    final ok = await _applyBlock(s, detail, 'Warden');
    if (!ok) return false;

    addNotification(
      'Student Blocked',
      '${s.name} was blocked by warden ${currentUser!.name}.',
      NotificationType.info,
      targetUserId: platformAdminEmail,
    );
    notifyListeners();
    return true;
  }

  /// Platform admin blocks a student.
  void adminBlockStudent(String studentId, String detail) {
    if (currentUser?.role != UserRole.admin) return;
    final s = getStudentById(studentId);
    if (s == null || s.role != UserRole.student) return;

    if (s.assignedRoomId != null) {
      final room = allRooms.firstWhere((r) => r.roomId == s.assignedRoomId);
      room.removeOccupant(s.studentId);
      s.lastLeftRoomId = s.assignedRoomId;
      s.assignedRoomId = null;
      s.roommateId = null;
    }
    s.paymentVerified = false;
    s.assignmentStatus = AssignmentStatus.none;

    _applyBlock(s, detail, 'Platform Admin');
    notifyListeners();
  }

  String? _wardenIdForStudent(String studentId) {
    for (final r in hostelRequests) {
      if (r.isStudentJoinRequest &&
          r.studentId == studentId &&
          (r.status == HostelRequestStatus.booked || r.status == HostelRequestStatus.pending)) {
        return r.adminId;
      }
    }
    return null;
  }

  String unblockApproverLabelForRole(UserRole blockedRole, {Student? target}) {
    switch (blockedRole) {
      case UserRole.student:
        return 'Warden';
      case UserRole.warden:
        return 'Owner';
      case UserRole.owner:
        return 'Platform Admin';
      case UserRole.admin:
        return 'Platform Admin';
    }
  }

  String? unblockApproverIdFor(Student target) {
    switch (target.role) {
      case UserRole.student:
        return _wardenIdForStudent(target.studentId);
      case UserRole.warden:
        return target.managedByOwnerId;
      case UserRole.owner:
        return platformAdminEmail;
      case UserRole.admin:
        return platformAdminEmail;
    }
  }

  bool canApproveUnblockRequest(String requestId) {
    if (currentUser == null) return false;
    final idx = unblockRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;
    final req = unblockRequests[idx];
    if (req.status != UnblockRequestStatus.pending) return false;

    if (currentUser!.role != UserRole.warden) return false;
    return req.targetRole == UserRole.student &&
        wardenManagesStudent(currentUser!.studentId, req.studentId);
  }

  List<UnblockRequest> getPendingUnblockRequestsForWarden([String? wardenId]) {
    final wid = wardenId ?? currentUser?.studentId;
    if (wid == null || wid.isEmpty) return [];
    return unblockRequests
        .where(
          (r) =>
              r.status == UnblockRequestStatus.pending &&
              r.targetRole == UserRole.student &&
              wardenManagesStudent(wid, r.studentId),
        )
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  int get pendingWardenUnblockCount => getPendingUnblockRequestsForWarden().length;

  UnblockRequest? getPendingUnblockRequestForStudent(String studentId) {
    final s = getStudentById(studentId);
    if (s == null) return null;
    final list = unblockRequests
        .where(
          (r) =>
              idsMatch(r.studentId, studentId) &&
              r.status == UnblockRequestStatus.pending &&
              _isUnblockRequestForCurrentBlock(r, s),
        )
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return list.isEmpty ? null : list.first;
  }

  List<UnblockRequest> getUnblockRequestsForCurrentApprover() {
    if (currentUser == null) return [];
    final list = unblockRequests.where((r) {
      if (currentUser!.role != UserRole.warden) return false;
      return r.targetRole == UserRole.student &&
          wardenManagesStudent(currentUser!.studentId, r.studentId);
    }).toList();
    list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return list;
  }

  bool _isUnblockRequestForCurrentBlock(UnblockRequest r, Student s) {
    if (s.blockedAt == null) return true;
    return !r.requestedAt.isBefore(s.blockedAt!);
  }

  /// Latest unblock request for the student's **current** block only (ignores old approved cycles).
  UnblockRequest? getUnblockRequestForStudent(String studentId) {
    final s = getStudentById(studentId);
    if (s == null) return null;

    final list = unblockRequests
        .where((r) => idsMatch(r.studentId, studentId) && _isUnblockRequestForCurrentBlock(r, s))
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return list.isEmpty ? null : list.first;
  }

  bool hasPendingUnblockRequest(String studentId) =>
      getPendingUnblockRequestForStudent(studentId) != null;

  bool canSubmitUnblockRequest(String studentId) {
    final s = getStudentById(studentId);
    if (s == null || !s.isAccountBlocked) return false;
    if (hasPendingUnblockRequest(studentId)) return false;
    final current = getUnblockRequestForStudent(studentId);
    return current == null || current.status == UnblockRequestStatus.rejected;
  }

  Future<String?> submitUnblockRequest(String message) async {
    if (currentUser == null) return 'Not logged in';
    if (!currentUser!.isAccountBlocked) return 'Account is not blocked';

    final studentKey = _userKey(currentUser!);
    if (hasPendingUnblockRequest(studentKey)) {
      return 'You already have a pending unblock request';
    }

    final approverId = unblockApproverIdFor(currentUser!);
    final approverLabel = unblockApproverLabelForRole(currentUser!.role, target: currentUser);
    if (currentUser!.role == UserRole.student && approverId == null) {
      return 'No warden is linked to your hostel. Ask your warden to unblock you.';
    }

    final req = UnblockRequest(
      id: 'UB_${DateTime.now().millisecondsSinceEpoch}',
      studentId: studentKey,
      studentName: currentUser!.name.isNotEmpty ? currentUser!.name : studentKey.split('@').first,
      targetRole: currentUser!.role,
      message: message.trim(),
      requestedAt: DateTime.now(),
    );
    unblockRequests.insert(0, req);

    try {
      await _db.saveUnblockRequest(req);
    } catch (_) {
      unblockRequests.remove(req);
      return 'Could not send request — check internet and try again';
    }

    addNotification(
      'Unblock Request Sent',
      'Your unblock request was sent to $approverLabel.',
      NotificationType.info,
      targetUserId: studentKey,
    );
    if (approverId != null && !idsMatch(approverId, studentKey)) {
      addNotification(
        'Unblock Request',
        '${currentUser!.name.isNotEmpty ? currentUser!.name : studentKey.split('@').first} requested account unblock.',
        NotificationType.info,
        targetUserId: approverId,
      );
    }
    notifyListeners();
    return null;
  }

  Future<bool> _releaseAccountBlock(Student s, {required String approvedByLabel}) async {
    if (s.email.trim().isEmpty && s.studentId.contains('@')) {
      s.email = s.studentId.trim().toLowerCase();
    }
    s.isAccountBlocked = false;
    s.blockReason = null;
    s.blockedAt = null;
    _syncStudent(s, persist: false);

    try {
      await _db.saveUnblockedUser(s);
    } catch (_) {
      return false;
    }

    for (final req in unblockRequests.where(
      (r) => idsMatch(r.studentId, s.studentId) && r.status == UnblockRequestStatus.pending,
    )) {
      req.status = UnblockRequestStatus.approved;
      unawaited(_db.saveUnblockRequest(req).catchError((_) {}));
    }

    addNotification(
      'Account Unblocked',
      'Your account has been unblocked by $approvedByLabel. You can use the app normally.',
      NotificationType.info,
      targetUserId: s.studentId,
    );
    return true;
  }

  Future<bool> approveUnblockRequest(String requestId) async {
    if (!canApproveUnblockRequest(requestId)) return false;

    final idx = unblockRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final req = unblockRequests[idx];
    var s = getStudentById(req.studentId);
    s ??= await _db.getUserByEmail(req.studentId);
    if (s == null) return false;
    _syncStudent(s, persist: false);

    req.status = UnblockRequestStatus.approved;
    try {
      await _db.saveUnblockRequest(req);
    } catch (_) {
      return false;
    }

    final ok = await _releaseAccountBlock(
      s,
      approvedByLabel: unblockApproverLabelForRole(currentUser!.role, target: s),
    );
    if (ok) notifyListeners();
    return ok;
  }

  /// Warden can unblock a student they manage without waiting for a formal request.
  Future<bool> wardenUnblockStudent(String studentId) async {
    if (currentUser?.role != UserRole.warden) return false;
    final s = getStudentById(studentId);
    if (s == null || s.role != UserRole.student || !s.isAccountBlocked) return false;
    if (!wardenManagesStudent(currentUser!.studentId, studentId)) return false;

    final ok = await _releaseAccountBlock(s, approvedByLabel: 'Warden');
    if (ok) notifyListeners();
    return ok;
  }

  Future<void> rejectUnblockRequest(String requestId, {String? adminNote}) async {
    if (!canApproveUnblockRequest(requestId)) return;

    final idx = unblockRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;

    final req = unblockRequests[idx];
    if (req.status != UnblockRequestStatus.pending) return;

    req.status = UnblockRequestStatus.rejected;
    req.adminNote = adminNote;
    try {
      await _db.saveUnblockRequest(req);
    } catch (_) {
      return;
    }

    final label = unblockApproverLabelForRole(req.targetRole);
    addNotification(
      'Unblock Request Rejected',
      adminNote ?? 'Your unblock request was rejected by $label.',
      NotificationType.info,
      targetUserId: req.studentId,
    );
    notifyListeners();
  }

  List<UnblockRequest> getAllUnblockRequests() {
    final copy = List<UnblockRequest>.from(unblockRequests);
    copy.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return copy;
  }

  List<Student> getBlockedStudentsForAdmin() {
    return allStudents
        .where((s) => s.role == UserRole.student && s.isAccountBlocked)
        .toList();
  }

  List<Student> getStudentsForAdminUsersTab(String adminId) {
    final ids = <String>{};
    final list = <Student>[];
    for (final r in getStudentHostelRequestsForAdmin(adminId)) {
      if (!ids.add(r.studentId)) continue;
      final s = getStudentById(r.studentId);
      if (s != null) {
        list.add(s);
      } else {
        list.add(Student(
          studentId: r.studentId,
          name: r.studentName.trim().isNotEmpty ? r.studentName : r.studentId.split('@').first,
          email: r.studentId.contains('@') ? r.studentId : '',
        ));
      }
    }
    for (final s in getBlockedStudentsForAdmin()) {
      if (ids.add(s.studentId)) list.add(s);
    }
    return list;
  }

  // Getters for UI
  List<RoommateRequest> getIncomingRequests() {
    if (currentUser == null) return [];
    return allRequests.where((r) => r.receiverId == currentUser!.studentId && r.status == RequestStatus.pending).toList();
  }

  List<RoommateRequest> getIncomingRoommateRequests() {
    return getIncomingRequests().where((r) => r.type == RequestType.roommate).toList();
  }

  List<RoommateRequest> getIncomingSkillRequests() {
    return getIncomingRequests().where((r) => r.type == RequestType.skillShare).toList();
  }

  List<RoommateRequest> getOutgoingRequests() {
    if (currentUser == null) return [];
    return allRequests.where((r) => r.senderId == currentUser!.studentId).toList();
  }

  int get pendingIncomingRequestCount => getIncomingRequests().length;

  RequestStatus? getOutgoingRoommateRequestStatusTo(Student receiver) {
    try {
      return allRequests.firstWhere((r) => r.senderId == currentUser?.studentId && r.receiverId == receiver.studentId && r.type == RequestType.roommate).status;
    } catch (e) { return null; }
  }

  bool hasPendingSkillRequestTo(Student receiver, String skill) {
    return allRequests.any((r) => r.senderId == currentUser?.studentId && r.receiverId == receiver.studentId && r.type == RequestType.skillShare && r.skillName == skill && r.status == RequestStatus.pending);
  }

  List<StrongMatch> getStrongMatches({double threshold = 75.0}) {
    List<StrongMatch> strong = [];
    for (var r in allRequests.where((req) => req.type == RequestType.roommate && req.status == RequestStatus.accepted && req.adminStatus == AdminStatus.pending)) {
      try {
        var studentA = allStudents.firstWhere((s) => s.studentId == r.senderId);
        var studentB = allStudents.firstWhere((s) => s.studentId == r.receiverId);
        strong.add(StrongMatch(studentA, studentB, r.compatibilityScore));
      } catch(e) {}
    }
    return strong;
  }

  // Admin Room Management
  void updateRoomFacilities(String roomId, {bool? ac, bool? bath, bool? wifi, bool? furn, bool? kitchen, bool? laundry}) {
    int idx = allRooms.indexWhere((r) => r.roomId == roomId);
    if (idx != -1) {
      if (ac != null) allRooms[idx].hasAC = ac;
      if (bath != null) allRooms[idx].hasAttachedBathroom = bath;
      if (wifi != null) allRooms[idx].hasWifi = wifi;
      if (furn != null) allRooms[idx].isFurnished = furn;
      if (kitchen != null) allRooms[idx].hasKitchenAccess = kitchen;
      if (laundry != null) allRooms[idx].hasLaundry = laundry;
      notifyListeners();
    }
  }

  void deleteRoom(String roomId) {
    allRooms.removeWhere((r) => r.roomId == roomId);
    for (final hostel in hostels) {
      for (final floor in hostel.floors) {
        floor.rooms.removeWhere((r) => r.roomId == roomId);
      }
    }
    notifyListeners();
  }

  void cancelOutgoingRoommateRequestTo(Student receiver) {
    allRequests.removeWhere((r) => 
      r.senderId == currentUser?.studentId && 
      r.receiverId == receiver.studentId && 
      r.type == RequestType.roommate
    );
    notifyListeners();
  }

  void removeUser(String studentId) {
    allStudents.removeWhere((s) => s.studentId == studentId);
    owners.removeWhere((s) => s.studentId == studentId);
    wardens.removeWhere((s) => s.studentId == studentId);
    allRequests.removeWhere((r) => r.senderId == studentId || r.receiverId == studentId);
    hostelRequests.removeWhere((r) => r.adminId == studentId || r.studentId == studentId);
    for (var room in allRooms) {
      if (room.occupantsIds.contains(studentId)) {
        room.removeOccupant(studentId);
      }
    }
    hostels.removeWhere((h) => h.createdByOwner == studentId);
    if (hostels.any((h) => h.assignedAdminId == studentId)) {
      for (final h in hostels) {
        if (h.assignedAdminId == studentId) {
          h.assignedAdminId = null;
          h.assignedType = null;
        }
      }
    }
    allRooms = roomsFromHostels(hostels);
    notifyListeners();
    unawaited(_db.deleteUser(studentId).catchError((_) {}));
    unawaited(_persistToFirestore());
  }

  // Hostel assignment requests (Warden → Owner, approved by Platform Admin)
  String? sendHostelAssignmentRequest(String hostelId, String requestedType, String desc) {
    if (currentUser == null) return 'Not logged in';
    if (currentUser!.role != UserRole.warden) return 'Only wardens can request hostel assignment';

    final warden = currentUser!;
    if (warden.gender.trim().isEmpty) {
      return 'Set your gender during signup. Only same-gender hostels can be managed.';
    }

    final blockReason = wardenHostelRequestBlockReason(warden.studentId, forHostelId: hostelId);
    if (blockReason != null) return blockReason;

    final hostelIdx = hostels.indexWhere((h) => h.id == hostelId);
    if (hostelIdx == -1) return 'Hostel not found';
    final hostel = hostels[hostelIdx];

    if (!hostel.isAvailableForWarden) {
      return 'This hostel is not available (pending approval or already booked)';
    }

    if (!hostelTypeMatchesGender(requestedType, warden.gender)) {
      return 'You can only manage ${defaultHostelTypeForGender(warden.gender)} (matches your gender).';
    }

    if (adminHasPendingRequestForHostel(warden.studentId, hostelId)) {
      return 'You already have a pending request for this hostel';
    }

    final request = HostelRequest(
      id: 'HR_${DateTime.now().millisecondsSinceEpoch}',
      adminId: currentUser!.studentId,
      adminName: currentUser!.name.trim().isNotEmpty ? currentUser!.name.trim() : currentUser!.email,
      hostelId: hostel.id,
      hostelName: hostel.hostelName,
      location: hostel.location,
      hostelType: requestedType,
      description: desc,
      requestedAt: DateTime.now(),
    );
    hostelRequests.insert(0, request);
    unawaited(_db.saveHostelRequest(request).catchError((_) {}));

    addNotification(
      'New Warden Hostel Request',
      '${currentUser!.name} requested ${hostel.hostelName} as $requestedType',
      NotificationType.info,
      targetUserId: platformAdminEmail,
    );
    addNotification(
      'Warden Request Received',
      '${currentUser!.name} requested your hostel ${hostel.hostelName} ($requestedType) — pending admin approval.',
      NotificationType.info,
      targetUserId: hostel.createdByOwner,
    );
    addNotification(
      'Hostel Request Sent',
      'Your request for ${hostel.hostelName} ($requestedType) was sent for admin approval.',
      NotificationType.info,
      targetUserId: currentUser!.studentId,
    );
    notifyListeners();
    return null;
  }

  /// Platform admin approves warden assignment to a hostel.
  Future<bool> approveWardenAssignmentRequest(String requestId) async {
    final idx = hostelRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;

    final request = hostelRequests[idx];
    if (request.isStudentJoinRequest) return approveStudentHostelRequest(requestId);
    if (!request.isWardenAssignmentRequest) return false;
    if (request.status != HostelRequestStatus.pending) return false;

    final existingHostel = getAssignedHostelForAdmin(request.adminId);
    if (existingHostel != null && existingHostel.id != request.hostelId) {
      return false;
    }

    final hostelIdx = hostels.indexWhere((h) => h.id == request.hostelId);
    if (hostelIdx == -1) return false;

    final hostel = hostels[hostelIdx];
    if (hostel.isBooked && hostel.assignedAdminId != request.adminId) return false;

    final warden = getStudentById(request.adminId);
    if (warden == null || warden.gender.trim().isEmpty) return false;
    if (!hostelTypeMatchesGender(request.hostelType, warden.gender)) return false;

    if (hostel.approvalStatus == HostelApprovalStatus.pending) {
      hostel.approvalStatus = HostelApprovalStatus.approved;
      hostel.rejectionReason = null;
    }

    hostel.assignedAdminId = request.adminId;
    hostel.assignedType = request.hostelType;
    request.status = HostelRequestStatus.booked;
    allRooms = roomsFromHostels(hostels);

    try {
      await Future.wait([
        _db.saveHostel(hostel),
        _db.saveHostelRequest(request),
      ]);
    } catch (_) {
      request.status = HostelRequestStatus.pending;
      if (hostel.assignedAdminId == request.adminId) {
        hostel.assignedAdminId = null;
        hostel.assignedType = null;
      }
      return false;
    }

    for (final r in hostelRequests) {
      if (r.hostelId == request.hostelId &&
          r.id != request.id &&
          r.isWardenAssignmentRequest &&
          r.status == HostelRequestStatus.pending) {
        r.status = HostelRequestStatus.rejected;
        r.ownerMessage = 'Another warden was assigned to this hostel.';
        unawaited(_db.saveHostelRequest(r).catchError((_) {}));
        addNotification(
          'Hostel Request Rejected',
          'Your request for ${r.hostelName} was not selected.',
          NotificationType.info,
          targetUserId: r.adminId,
        );
      }
    }

    addNotification(
      'Hostel Assigned',
      'You are now assigned to ${request.hostelName} (${request.hostelType}). Pay now to activate.',
      NotificationType.info,
      targetUserId: request.adminId,
    );
    addNotification(
      'Warden Assigned',
      '${wardenNameForRequest(request)} was assigned to ${request.hostelName} (${request.hostelType}).',
      NotificationType.info,
      targetUserId: hostel.createdByOwner,
    );
    notifyListeners();
    return true;
  }

  void rejectWardenAssignmentRequest(String requestId, {String? message}) {
    final idx = hostelRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;

    final request = hostelRequests[idx];
    if (request.isStudentJoinRequest) {
      rejectStudentHostelRequest(requestId, message: message);
      return;
    }
    if (!request.isWardenAssignmentRequest) return;
    if (request.status != HostelRequestStatus.pending) return;

    request.status = HostelRequestStatus.rejected;
    unawaited(_db.saveHostelRequest(request).catchError((_) {}));
    request.ownerMessage = message;

    addNotification(
      'Hostel Request Rejected',
      message ?? 'Your request for ${request.hostelName} was rejected by platform admin.',
      NotificationType.info,
      targetUserId: request.adminId,
    );
    final hostel = hostels.cast<Hostel?>().firstWhere(
          (h) => h?.id == request.hostelId,
          orElse: () => null,
        );
    if (hostel != null) {
      addNotification(
        'Warden Request Rejected',
        '${request.adminName}\'s request for ${request.hostelName} was rejected.',
        NotificationType.info,
        targetUserId: hostel.createdByOwner,
      );
    }
    notifyListeners();
  }

  /// Legacy entry — routes warden assignment to platform admin flow.
  Future<bool> approveHostelRequest(String requestId) => approveWardenAssignmentRequest(requestId);

  void rejectHostelRequest(String requestId, String? message) {
    rejectWardenAssignmentRequest(requestId, message: message);
  }

  List<HostelRequest> getPendingWardenAssignmentRequests() {
    return hostelRequests
        .where((r) => r.isWardenAssignmentRequest && r.status == HostelRequestStatus.pending)
        .toList();
  }

  /// Owner read-only: all warden requests for their hostels.
  List<HostelRequest> getWardenRequestsForOwner(String ownerId) {
    final ownerHostelIds = hostels.where((h) => h.createdByOwner == ownerId).map((h) => h.id).toSet();
    return hostelRequests
        .where((r) => r.isWardenAssignmentRequest && ownerHostelIds.contains(r.hostelId))
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  List<HostelRequest> getPendingRequestsForHostel(String hostelId) {
    return hostelRequests
        .where((r) =>
            r.hostelId == hostelId &&
            r.status == HostelRequestStatus.pending &&
            r.isWardenAssignmentRequest)
        .toList();
  }

  List<HostelRequest> getRequestsByAdmin(String adminId) {
    return hostelRequests.where((r) => r.adminId == adminId).toList();
  }

  /// Deprecated owner inbox — warden requests are admin-approved; owner sees status only.
  List<HostelRequest> getPendingHostelRequests() => getPendingWardenAssignmentRequests();

  // ── Student activity logs (visible to platform admin) ─────────────────────

  final List<ActivityLogEntry> _studentActivityLogs = [];

  void _logStudentActivity(
    String studentId,
    String studentName,
    String hostelId,
    String hostelName,
    String wardenId,
    String action,
  ) {
    final warden = getStudentById(wardenId);
    _studentActivityLogs.insert(
      0,
      ActivityLogEntry(
        time: DateTime.now(),
        category: 'Student',
        title: '$studentName → $hostelName',
        detail: '$action · Warden: ${warden?.name ?? wardenId}',
      ),
    );
  }

  List<ActivityLogEntry> getStudentActivityLogsForAdmin() {
    final logs = List<ActivityLogEntry>.from(_studentActivityLogs);

    for (final r in hostelRequests.where((r) => r.studentId.isNotEmpty)) {
      final warden = getStudentById(r.adminId);
      logs.add(ActivityLogEntry(
        time: r.requestedAt,
        category: 'Student',
        title: '${r.studentName} → ${r.hostelName}',
        detail: 'Status: ${r.status.displayLabel} · Warden: ${warden?.name ?? r.adminId}',
      ));
    }

    logs.sort((a, b) => b.time.compareTo(a.time));
    return logs;
  }

  // ── Hostel reviews ────────────────────────────────────────────────────────

  String? getAssignedHostelIdForStudent(String studentId) {
    final s = getStudentById(studentId);
    if (s?.assignedRoomId == null) return null;
    return getHostelIdForRoom(s!.assignedRoomId!);
  }

  String? getHostelNameById(String? hostelId) {
    if (hostelId == null) return null;
    try {
      return hostels.firstWhere((h) => h.id == hostelId).hostelName;
    } catch (_) {
      return null;
    }
  }

  bool shouldPromptHostelReview(String studentId) {
    final s = getStudentById(studentId);
    if (s == null || !s.paymentVerified) return false;
    final hostelId = getAssignedHostelIdForStudent(studentId);
    if (hostelId == null) return false;
    return !hasStudentReviewedHostel(studentId, hostelId);
  }

  bool hasStudentReviewedHostel(String studentId, String hostelId) {
    return hostelReviews.any((r) => r.studentId == studentId && r.hostelId == hostelId);
  }

  void submitHostelReview(String hostelId, int rating, String comment) {
    if (currentUser == null || !currentUser!.paymentVerified) return;
    if (hasStudentReviewedHostel(currentUser!.studentId, hostelId)) return;

    final assignedId = getAssignedHostelIdForStudent(currentUser!.studentId);
    if (assignedId != hostelId) return;

    final hostelName = getHostelNameById(hostelId) ?? 'Hostel';

    hostelReviews.add(HostelReview(
      id: 'REV_${DateTime.now().millisecondsSinceEpoch}',
      studentId: currentUser!.studentId,
      studentName: currentUser!.name.isNotEmpty ? currentUser!.name : currentUser!.email,
      hostelId: hostelId,
      hostelName: hostelName,
      rating: rating.clamp(1, 5).toInt(),
      comment: comment.trim(),
    ));

    addNotification(
      'New Hostel Review',
      '${currentUser!.name} rated $hostelName ${rating.clamp(1, 5).toInt()}/5',
      NotificationType.info,
    );
    notifyListeners();
  }

  List<HostelReview> getReviewsForHostel(String hostelId) {
    return hostelReviews.where((r) => r.hostelId == hostelId).toList();
  }

  List<HostelReview> getAllHostelReviewsSorted() {
    final copy = List<HostelReview>.from(hostelReviews);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  // ── Warden hostel payment (20% admin / 80% owner) ─────────────────────────

  bool wardenHasPaidForHostel(String wardenId, String hostelId) {
    return wardenHasPaidForMonth(wardenId, hostelId, currentPaymentMonthLabel());
  }

  String? makeWardenHostelPayment(String method, {String? cardLast4Digits, required String paymentMonth}) {
    if (currentUser == null || currentUser!.role != UserRole.warden) {
      return 'Only wardens can pay hostel fees';
    }
    final hostel = getAssignedHostelForAdmin(currentUser!.studentId);
    if (hostel == null) return 'No assigned hostel to pay for';

    if (hasSettledPaymentForMonth(
      userId: currentUser!.studentId,
      paymentMonth: paymentMonth,
      kind: PaymentKind.wardenHostel,
      hostelId: hostel.id,
    )) {
      return 'You already paid for $paymentMonth. Each month can be paid only once.';
    }

    final amount = hostel.rentPerMonth > 0 ? hostel.rentPerMonth : 25000.0;
    final adminShare = amount * 0.20;
    final ownerShare = amount * 0.80;

    allPayments.add(Payment(
      paymentId: 'WPAY_${DateTime.now().millisecondsSinceEpoch}',
      userId: currentUser!.studentId,
      roomId: '',
      amount: amount,
      paymentMethod: method,
      status: PaymentStatus.paid,
      cardLast4Digits: cardLast4Digits,
      kind: PaymentKind.wardenHostel,
      hostelId: hostel.id,
      adminShare: adminShare,
      ownerShare: ownerShare,
      ownerId: hostel.createdByOwner,
      paymentMonth: paymentMonth,
    ));

    addNotification(
      'Hostel Payment Received',
      'Warden ${currentUser!.name} paid Rs.${amount.toInt()} for $paymentMonth — ${hostel.hostelName}. Your share: Rs.${ownerShare.toInt()} (80%).',
      NotificationType.paymentConfirmed,
      targetUserId: hostel.createdByOwner,
    );
    addNotification(
      'Commission Received',
      'Warden payment for $paymentMonth (${hostel.hostelName}): your commission Rs.${adminShare.toInt()} (20%).',
      NotificationType.paymentConfirmed,
      targetUserId: platformAdminEmail,
    );
    addNotification(
      'Payment Successful',
      'Your hostel payment of Rs.${amount.toInt()} for $paymentMonth was successful.',
      NotificationType.paymentConfirmed,
      targetUserId: currentUser!.studentId,
    );
    notifyListeners();
    return null;
  }

  double getAdminCommissionTotal() {
    return allPayments
        .where((p) => p.kind == PaymentKind.wardenHostel && (p.status == PaymentStatus.paid || p.status == PaymentStatus.confirmed))
        .fold(0.0, (sum, p) => sum + (p.adminShare ?? p.amount * 0.20));
  }

  double getOwnerRevenueTotal(String ownerId) {
    return allPayments
        .where((p) =>
            p.kind == PaymentKind.wardenHostel &&
            p.ownerId == ownerId &&
            (p.status == PaymentStatus.paid || p.status == PaymentStatus.confirmed))
        .fold(0.0, (sum, p) => sum + (p.ownerShare ?? p.amount * 0.80));
  }

  String roleDisplayLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.owner:
        return 'Owner';
      case UserRole.warden:
        return 'Warden';
      case UserRole.student:
        return 'Student';
    }
  }
}
