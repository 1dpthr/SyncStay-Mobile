import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/firestore_mappers.dart';
import '../models/hostel.dart';
import '../models/hostel_request.dart';
import '../models/notification.dart';
import '../models/payment.dart';
import '../models/roommate_request.dart';
import '../models/student.dart';
import '../models/hostel_review.dart';
import '../models/unblock_request.dart';
import 'firebase_service.dart';

typedef DataListener = void Function({
  required List<Student> users,
  required List<Hostel> hostels,
  required List<HostelRequest> hostelRequests,
  required List<RoommateRequest> roommateRequests,
  required List<Payment> payments,
  required List<AppNotification> notifications,
  required List<UnblockRequest> unblockRequests,
  required List<HostelReview> hostelReviews,
});

class FirestoreRepository {
  FirestoreRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseService.firestore,
        _auth = auth ?? FirebaseService.auth;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const _users = 'users';
  static const _hostels = 'hostels';
  static const _hostelRequests = 'hostel_requests';
  static const _roommateRequests = 'roommate_requests';
  static const _payments = 'payments';
  static const _notifications = 'notifications';
  static const _unblockRequests = 'unblock_requests';
  static const _hostelReviews = 'hostel_reviews';

  String _userDocId(String email) => email.trim().toLowerCase();

  String _userDocIdFor(Student user) {
    final id = user.email.trim().isNotEmpty ? user.email : user.studentId;
    return _userDocId(id);
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );
  }

  Future<UserCredential> signUp(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );
  }

  Future<void> signOut() => _auth.signOut();

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<({
    List<Student> users,
    List<Hostel> hostels,
    List<HostelRequest> hostelRequests,
    List<RoommateRequest> roommateRequests,
    List<Payment> payments,
    List<AppNotification> notifications,
    List<UnblockRequest> unblockRequests,
    List<HostelReview> hostelReviews,
  })> loadAll() async {
    final results = await Future.wait([
      _db.collection(_users).get(),
      _db.collection(_hostels).get(),
      _db.collection(_hostelRequests).get(),
      _db.collection(_roommateRequests).get(),
      _db.collection(_payments).get(),
      _db.collection(_notifications).get(),
      _db.collection(_unblockRequests).get(),
      _db.collection(_hostelReviews).get(),
    ]);

    return (
      users: results[0].docs.map((d) => studentFromMap(d.data())).toList(),
      hostels: results[1].docs.map((d) => hostelFromMap(d.data(), docId: d.id)).toList(),
      hostelRequests: results[2].docs.map((d) => hostelRequestFromMap(d.data())).toList(),
      roommateRequests: results[3].docs.map((d) => roommateRequestFromMap(d.data())).toList(),
      payments: results[4].docs.map((d) => paymentFromMap(d.data())).toList(),
      notifications: results[5].docs.map((d) => notificationFromMap(d.data())).toList(),
      unblockRequests: results[6].docs.map((d) => unblockRequestFromMap(d.data())).toList(),
      hostelReviews: results[7].docs.map((d) => hostelReviewFromMap(d.data())).toList(),
    );
  }

  List<StreamSubscription<dynamic>> listenAll(DataListener onData) {
    var users = <Student>[];
    var hostels = <Hostel>[];
    var hostelRequests = <HostelRequest>[];
    var roommateRequests = <RoommateRequest>[];
    var payments = <Payment>[];
    var notifications = <AppNotification>[];
    var unblockRequests = <UnblockRequest>[];
    var hostelReviews = <HostelReview>[];

    void emit() {
      onData(
        users: users,
        hostels: hostels,
        hostelRequests: hostelRequests,
        roommateRequests: roommateRequests,
        payments: payments,
        notifications: notifications,
        unblockRequests: unblockRequests,
        hostelReviews: hostelReviews,
      );
    }

    void onListenError(Object _, StackTrace __) {}

    return [
      _db.collection(_users).snapshots().listen((snap) {
        users = snap.docs.map((d) => studentFromMap(d.data())).toList();
        emit();
      }, onError: onListenError),
      _db.collection(_hostels).snapshots().listen((snap) {
        hostels = snap.docs.map((d) => hostelFromMap(d.data(), docId: d.id)).toList();
        emit();
      }, onError: onListenError),
      _db.collection(_hostelRequests).snapshots().listen((snap) {
        hostelRequests = snap.docs.map((d) => hostelRequestFromMap(d.data())).toList();
        emit();
      }, onError: onListenError),
      _db.collection(_roommateRequests).snapshots().listen((snap) {
        roommateRequests = snap.docs.map((d) => roommateRequestFromMap(d.data())).toList();
        emit();
      }, onError: onListenError),
      _db.collection(_payments).snapshots().listen((snap) {
        payments = snap.docs.map((d) => paymentFromMap(d.data())).toList();
        emit();
      }, onError: onListenError),
      _db.collection(_notifications).snapshots().listen((snap) {
        notifications = snap.docs.map((d) => notificationFromMap(d.data())).toList();
        emit();
      }, onError: onListenError),
      _db.collection(_unblockRequests).snapshots().listen((snap) {
        unblockRequests = snap.docs.map((d) => unblockRequestFromMap(d.data())).toList();
        emit();
      }, onError: onListenError),
      _db.collection(_hostelReviews).snapshots().listen((snap) {
        hostelReviews = snap.docs.map((d) => hostelReviewFromMap(d.data())).toList();
        emit();
      }, onError: onListenError),
    ];
  }

  Future<void> syncAll({
    required List<Hostel> hostels,
    required List<HostelRequest> hostelRequests,
    required List<RoommateRequest> roommateRequests,
    required List<Payment> payments,
    required List<AppNotification> notifications,
    required List<UnblockRequest> unblockRequests,
    required List<HostelReview> hostelReviews,
  }) async {
    // Users are saved individually via saveUser() to avoid stale local state
    // overwriting remote block/unblock changes during debounced sync.
    await Future.wait([
      _syncHostels(hostels),
      _syncCollection(
        _hostelRequests,
        hostelRequests,
        (r) => r.id,
        hostelRequestToMap,
        deleteMissingRemote: false,
      ),
      _syncCollection(_roommateRequests, roommateRequests, (r) => r.id, roommateRequestToMap),
      _syncCollection(_payments, payments, (p) => p.paymentId, paymentToMap),
      _syncCollection(_notifications, notifications, (n) => n.id, notificationToMap),
      _syncCollection(_unblockRequests, unblockRequests, (r) => r.id, unblockRequestToMap),
      _syncCollection(_hostelReviews, hostelReviews, (r) => r.id, hostelReviewToMap),
    ]);
  }

  /// Writes local hostels without downgrading admin approval on the server.
  Future<void> _syncHostels(List<Hostel> local) async {
    final snap = await _db.collection(_hostels).get();
    final remoteById = {for (final d in snap.docs) d.id: d.data()};
    final remoteIds = remoteById.keys.toSet();
    final localIds = local.map((h) => h.id).toSet();
    final batch = _db.batch();

    for (final h in local) {
      var map = hostelToMap(h);
      final remote = remoteById[h.id];
      // Owner device may still show "pending" while admin already approved on server.
      if (remote != null) {
        if (h.approvalStatus == HostelApprovalStatus.pending) {
          final remoteStatus = remote['approvalStatus'] as String?;
          if (remoteStatus != null &&
              remoteStatus.isNotEmpty &&
              remoteStatus != HostelApprovalStatus.pending.name) {
            map = Map<String, dynamic>.from(map)..['approvalStatus'] = remoteStatus;
            map['rejectionReason'] = remote['rejectionReason'] ?? map['rejectionReason'];
          }
        }
        final localWarden = h.assignedAdminId;
        final remoteWarden = remote['assignedAdminId'] as String?;
        if ((localWarden == null || localWarden.isEmpty) &&
            remoteWarden != null &&
            remoteWarden.isNotEmpty) {
          map = Map<String, dynamic>.from(map)
            ..['assignedAdminId'] = remoteWarden
            ..['assignedType'] = remote['assignedType'] ?? map['assignedType'];
        }
      }
      batch.set(_db.collection(_hostels).doc(h.id), map);
    }
    for (final id in remoteIds.difference(localIds)) {
      batch.delete(_db.collection(_hostels).doc(id));
    }
    if (local.isEmpty && remoteIds.isEmpty) return;
    await batch.commit();
  }

  Future<void> _syncCollection<T>(
    String collection,
    List<T> local,
    String Function(T) idFn,
    Map<String, dynamic> Function(T) toMap, {
    bool deleteMissingRemote = true,
  }) async {
    final snap = await _db.collection(collection).get();
    final remoteIds = snap.docs.map((d) => d.id).toSet();
    final localIds = local.map(idFn).toSet();
    final batch = _db.batch();
    for (final item in local) {
      batch.set(_db.collection(collection).doc(idFn(item)), toMap(item));
    }
    if (deleteMissingRemote) {
      for (final id in remoteIds.difference(localIds)) {
        batch.delete(_db.collection(collection).doc(id));
      }
    }
    if (local.isEmpty && (!deleteMissingRemote || remoteIds.isEmpty)) return;
    await batch.commit();
  }

  // ── CRUD (single-doc helpers) ──────────────────────────────────────────────

  Future<void> saveUser(Student user) {
    return _db.collection(_users).doc(_userDocIdFor(user)).set(studentToMap(user));
  }

  /// Persists block state so student devices see block immediately.
  Future<void> saveBlockedUser(Student user) async {
    final docId = _userDocIdFor(user);
    final map = studentToMap(user);
    map['isAccountBlocked'] = true;
    map['blockReason'] = user.blockReason ?? 'Blocked';
    map['blockedAt'] = user.blockedAt != null
        ? Timestamp.fromDate(user.blockedAt!)
        : FieldValue.serverTimestamp();
    await _db.collection(_users).doc(docId).set(map, SetOptions(merge: true));
  }

  /// Clears block fields in Firestore so remote listeners see unblock immediately.
  Future<void> saveUnblockedUser(Student user) async {
    final docId = _userDocIdFor(user);
    final map = studentToMap(user);
    map['isAccountBlocked'] = false;
    map['blockReason'] = FieldValue.delete();
    map['blockedAt'] = FieldValue.delete();
    await _db.collection(_users).doc(docId).set(map, SetOptions(merge: true));
  }

  Future<void> deleteUser(String email) {
    return _db.collection(_users).doc(_userDocId(email)).delete();
  }

  Future<Student?> getUserByEmail(String email) async {
    try {
      final doc = await _db.collection(_users).doc(_userDocId(email)).get();
      if (!doc.exists || doc.data() == null) return null;
      return studentFromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHostel(Hostel hostel) {
    return _db.collection(_hostels).doc(hostel.id).set(hostelToMap(hostel));
  }

  Future<void> deleteHostel(String hostelId) {
    return _db.collection(_hostels).doc(hostelId).delete();
  }

  /// Deletes hostel and all linked Firestore data so admin/warden/student UIs stay in sync.
  Future<void> purgeHostelAndRelatedData({
    required String hostelId,
    required String hostelName,
    required String roomIdPrefix,
  }) async {
    await deleteHostel(hostelId);

    final requests = await _db.collection(_hostelRequests).where('hostelId', isEqualTo: hostelId).get();
    for (final doc in requests.docs) {
      await doc.reference.delete();
    }

    final reviews = await _db.collection(_hostelReviews).where('hostelId', isEqualTo: hostelId).get();
    for (final doc in reviews.docs) {
      await doc.reference.delete();
    }

    final payments = await _db.collection(_payments).get();
    for (final doc in payments.docs) {
      final data = doc.data();
      final linkedHostel = data['hostelId'] as String?;
      final roomId = data['roomId'] as String? ?? '';
      if (linkedHostel == hostelId || roomId.startsWith(roomIdPrefix)) {
        await doc.reference.delete();
      }
    }

    final notifications = await _db.collection(_notifications).get();
    for (final doc in notifications.docs) {
      final data = doc.data();
      final message = data['message'] as String? ?? '';
      final title = data['title'] as String? ?? '';
      if (message.contains(hostelName) || title.contains(hostelName)) {
        await doc.reference.delete();
      }
    }
  }

  Future<void> saveHostelRequest(HostelRequest request) {
    return _db.collection(_hostelRequests).doc(request.id).set(hostelRequestToMap(request));
  }

  Future<void> deleteHostelRequest(String id) {
    return _db.collection(_hostelRequests).doc(id).delete();
  }

  Future<void> saveRoommateRequest(RoommateRequest request) {
    return _db.collection(_roommateRequests).doc(request.id).set(roommateRequestToMap(request));
  }

  Future<void> deleteRoommateRequest(String id) {
    return _db.collection(_roommateRequests).doc(id).delete();
  }

  Future<void> savePayment(Payment payment) {
    return _db.collection(_payments).doc(payment.paymentId).set(paymentToMap(payment));
  }

  Future<void> saveNotification(AppNotification notification) {
    return _db.collection(_notifications).doc(notification.id).set(notificationToMap(notification));
  }

  Future<void> deleteNotification(String id) {
    return _db.collection(_notifications).doc(id).delete();
  }

  Future<void> clearAllNotifications() async {
    final snap = await _db.collection(_notifications).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> saveUnblockRequest(UnblockRequest request) {
    return _db.collection(_unblockRequests).doc(request.id).set(unblockRequestToMap(request));
  }

  Future<void> saveUsers(List<Student> users) async {
    final batch = _db.batch();
    for (final user in users) {
      batch.set(_db.collection(_users).doc(_userDocId(user.email)), studentToMap(user));
    }
    await batch.commit();
  }

  Future<void> saveHostels(List<Hostel> hostels) async {
    final batch = _db.batch();
    for (final hostel in hostels) {
      batch.set(_db.collection(_hostels).doc(hostel.id), hostelToMap(hostel));
    }
    await batch.commit();
  }

  /// Demo owner/warden accounts removed — admin creates owners, owners create wardens.
  static const legacyDemoOwnerWardenEmails = [
    'example@owner.com',
    'ali@owner.com',
    'example@warden.com',
    'ali@warden.com',
  ];

  /// Removes old seed/demo owner & warden profiles from Firestore (runs every app start).
  Future<void> purgeLegacyDemoOwnerWardenAccounts() async {
    for (final email in legacyDemoOwnerWardenEmails) {
      try {
        await deleteUser(email);
      } catch (_) {}
    }

    final hostelsSnap = await _db.collection(_hostels).get();
    for (final doc in hostelsSnap.docs) {
      final data = doc.data();
      final ownerId = data['createdByOwner'] as String? ?? '';
      final wardenId = data['assignedAdminId'] as String? ?? '';
      if (legacyDemoOwnerWardenEmails.contains(ownerId)) {
        await deleteHostel(doc.id);
      } else if (legacyDemoOwnerWardenEmails.contains(wardenId)) {
        await doc.reference.update({
          'assignedAdminId': null,
          'assignedType': null,
        });
      }
    }

    final reqSnap = await _db.collection(_hostelRequests).get();
    for (final doc in reqSnap.docs) {
      final data = doc.data();
      final adminId = data['adminId'] as String? ?? '';
      if (legacyDemoOwnerWardenEmails.contains(adminId)) {
        await deleteHostelRequest(doc.id);
      }
    }
  }

  static const platformAdminEmail = 'admin@syncstay.com';
  static const platformAdminPassword = '123456';

  /// Ensures platform admin exists in Firebase Auth + Firestore (runs every app start).
  Future<void> ensurePlatformAdminAccount() async {
    const email = platformAdminEmail;
    const password = platformAdminPassword;

    await _ensureAuthAccount(email, password);

    final docRef = _db.collection(_users).doc(_userDocId(email));
    final doc = await docRef.get();
    if (!doc.exists || doc.data() == null) {
      await saveUser(Student(
        studentId: email,
        name: 'Platform Admin',
        email: email,
        role: UserRole.admin,
      ));
      return;
    }

    final role = doc.data()!['role'] as String? ?? '';
    if (role != UserRole.admin.name) {
      await docRef.update({'role': UserRole.admin.name});
    }
  }

  // ── Seed ───────────────────────────────────────────────────────────────────

  Future<void> seedIfEmpty() async {
    final usersSnap = await _db.collection(_users).limit(1).get();
    if (usersSnap.docs.isNotEmpty) return;

    try {
      await _ensureAuthAccount(platformAdminEmail, platformAdminPassword);
      await _ensureAuthAccount('ali@student.com', 'password');
      await _ensureAuthAccount('sara@student.com', 'password');
    } catch (_) {
      // Auth accounts may already exist — continue seeding Firestore data.
    }

    final platformAdmin = Student(
      studentId: 'admin@syncstay.com',
      name: 'Platform Admin',
      email: 'admin@syncstay.com',
      role: UserRole.admin,
    );
    final students = [
      Student(
        studentId: 'ali@student.com',
        name: 'Ali Ahmed',
        email: 'ali@student.com',
        role: UserRole.student,
        gender: 'Male',
      ),
      Student(
        studentId: 'sara@student.com',
        name: 'Sara Khan',
        email: 'sara@student.com',
        role: UserRole.student,
        gender: 'Female',
      ),
    ];

    await saveUsers([platformAdmin, ...students]);

    final batch = _db.batch();

    batch.set(
      _db.collection(_roommateRequests).doc('REQ_MOCK_1'),
      roommateRequestToMap(
        RoommateRequest(
          id: 'REQ_MOCK_1',
          senderId: 'ali@student.com',
          receiverId: 'sara@student.com',
          senderName: 'Ali Ahmed',
          receiverName: 'Sara Khan',
          compatibilityScore: 85.0,
        ),
      ),
    );

    batch.set(_db.collection('meta').doc('app'), {
      'seeded': true,
      'seededAt': FieldValue.serverTimestamp(),
      'projectId': 'madpbl-ef1dd',
    });

    await batch.commit();
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  Future<void> _ensureAuthAccount(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
    }
  }

}
