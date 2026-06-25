import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/student.dart';
import '../../models/payment.dart';
import '../../models/roommate_request.dart';
import '../../models/notification.dart';
import 'widgets/syncstay_app_bar.dart';
import 'widgets/payment_history_list.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final user = state.currentUser;
        if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        String cleanUsername = user.studentId.split('@')[0];
        String displayName = user.name.isNotEmpty ? user.name : cleanUsername;
        return Scaffold(
          appBar: syncStayAppBar(
            context,
            screenTitle: 'Dashboard',
            actions: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => _showNotifications(context, state),
                  ),
                  if (state.getNotificationsForCurrentUser().any((n) => !n.isRead))
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                        constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                        child: const Text('', style: TextStyle(color: Colors.white, fontSize: 8), textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  accountEmail: Text(user.studentId),
                  currentAccountPicture: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text(
                          (displayName[0]).toUpperCase(),
                          style: const TextStyle(fontSize: 40.0, color: Color(0xFF6C63FF)),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF6C63FF), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6C63FF),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('My Profile / Preferences'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Find Roommates'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/matches');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.psychology),
                  title: const Text('Skill Peers'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/skill-peers');
                  },
                ),
                ListTile(
                  leading: Stack(
                    children: [
                      const Icon(Icons.mail),
                      if (state.getIncomingRequests().any((r) => r.status == RequestStatus.pending))
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                            constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                          ),
                        ),
                    ],
                  ),
                  title: const Text('Inbox / Requests'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/inbox');
                  },
                ),
                const Divider(),
                SwitchListTile(
                  secondary: Icon(state.isDarkMode ? Icons.dark_mode : Icons.light_mode),
                  title: const Text('Dark Mode'),
                  value: state.isDarkMode,
                  onChanged: (bool value) {
                    state.toggleTheme();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    state.logout();
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  },
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $displayName!',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your room requirements and bookings here.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                
                const SizedBox(height: 32),
                
                _buildBookingProgress(context, user),
                
                const SizedBox(height: 24),

                if (user.assignedRoomId != null) ...[
                  _buildAssignedRoomCard(context, state, user),
                  const SizedBox(height: 24),
                  _buildPaymentStatusCard(context, state, user),
                ] else
                  _buildRecommendationsSection(context, state),
                
                const SizedBox(height: 32),
                const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _QuickActionCard(
                      icon: Icons.people,
                      title: 'Find Match',
                      color: const Color(0xFF6C63FF),
                      onTap: () => Navigator.pushNamed(context, '/matches'),
                    ),
                    _QuickActionCard(
                      icon: Icons.psychology,
                      title: 'Skill Share',
                      color: const Color(0xFF03DAC6),
                      onTap: () => Navigator.pushNamed(context, '/skill-peers'),
                    ),
                    _QuickActionCard(
                      icon: Icons.mail,
                      title: 'Inbox',
                      color: Colors.orange,
                      badgeCount: state.getIncomingRequests().where((r) => r.status == RequestStatus.pending).length,
                      onTap: () => Navigator.pushNamed(context, '/inbox'),
                    ),
                    _QuickActionCard(
                      icon: Icons.contact_support,
                      title: 'Help / Support',
                      color: Colors.blue,
                      onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contacting Admin...')));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildNotificationsPreview(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookingProgress(BuildContext context, Student user) {
    int currentStep = 0;
    final payments = Provider.of<AppState>(context, listen: false).allPayments;
    final userPayment = payments.where((p) => p.userId == user.studentId && p.roomId == user.assignedRoomId).isNotEmpty
      ? payments.firstWhere((p) => p.userId == user.studentId && p.roomId == user.assignedRoomId)
      : null;

    if (user.assignmentStatus == AssignmentStatus.assigned) {
      currentStep = 1;
    }
    if (user.assignmentStatus == AssignmentStatus.accepted) {
      currentStep = 2;
      if (userPayment != null && userPayment.status == PaymentStatus.pending) {
        currentStep = 3;
      }
    }
    if (user.paymentVerified && user.assignmentStatus == AssignmentStatus.confirmed) {
      currentStep = 4;
    }

    final steps = [
      {'label': 'Suggested', 'icon': Icons.lightbulb_outline},
      {'label': 'Assigned', 'icon': Icons.assignment_ind},
      {'label': 'Accepted', 'icon': Icons.check_circle_outline},
      {'label': 'Paid', 'icon': Icons.payment},
      {'label': 'Confirmed', 'icon': Icons.verified_user},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Booking Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              bool isCompleted = index < currentStep;
              bool isCurrent = index == currentStep;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCompleted || isCurrent ? const Color(0xFF6C63FF) : Colors.grey.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: isCurrent ? [
                          BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)
                        ] : null,
                      ),
                      child: Icon(
                        steps[index]['icon'] as IconData,
                        size: 16,
                        color: isCompleted || isCurrent ? Colors.white : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[index]['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? const Color(0xFF6C63FF) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: state.clearNotifications, child: const Text('Clear All')),
                ],
              ),
            ),
            Expanded(
              child: state.getNotificationsForCurrentUser().isEmpty 
                ? const Center(child: Text('No notifications'))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: state.getNotificationsForCurrentUser().length,
                    itemBuilder: (context, index) {
                      final n = state.getNotificationsForCurrentUser()[index];
                      return ListTile(
                        leading: _getNotifIcon(n.type),
                        title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(n.message),
                        trailing: Text('${n.timestamp.hour}:${n.timestamp.minute}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Icon _getNotifIcon(NotificationType type) {
    switch (type) {
      case NotificationType.roomAssigned: return const Icon(Icons.meeting_room, color: Colors.blue);
      case NotificationType.paymentConfirmed: return const Icon(Icons.check_circle, color: Colors.green);
      case NotificationType.roommateMatched: return const Icon(Icons.people, color: Colors.purple);
      case NotificationType.requestReceived: return const Icon(Icons.mail, color: Colors.orange);
      case NotificationType.info: return const Icon(Icons.info, color: Colors.grey);
    }
  }

  Widget _buildAssignedRoomCard(BuildContext context, AppState state, Student user) {
    final room = state.allRooms.firstWhere((r) => r.roomId == user.assignedRoomId);
    final totalPrice = room.calculateTotalPrice();
    final roommate = user.roommateId != null ? state.allStudents.firstWhere((s) => s.studentId == user.roommateId) : null;
    final compatibilityScore = roommate != null ? state.engine.calculateDetailedCompatibility(user, roommate).compatibilityScore : 0.0;
    final sharedInterests = roommate != null ? user.skills.where((skill) => roommate.skills.contains(skill)).toList() : <String>[];

    final String assignmentStatusLabel;
    final Color assignmentStatusColor;
    if (user.paymentVerified && user.assignmentStatus == AssignmentStatus.confirmed) {
      assignmentStatusLabel = 'Booking Confirmed';
      assignmentStatusColor = Colors.green;
    } else if (user.assignmentStatus == AssignmentStatus.accepted) {
      assignmentStatusLabel = 'Room Accepted';
      assignmentStatusColor = Colors.blue;
    } else {
      assignmentStatusLabel = 'Assigned Room';
      assignmentStatusColor = Colors.orange;
    }

    final bool showAcceptReject = user.assignmentStatus == AssignmentStatus.assigned;
    final bool showPaymentButton = user.assignmentStatus == AssignmentStatus.accepted && !user.paymentVerified;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Assigned Room', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: assignmentStatusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  assignmentStatusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: assignmentStatusColor, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 8,
          shadowColor: const Color(0xFF6C63FF).withOpacity(0.25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF6C63FF), width: 1)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (room.imageUrls.isNotEmpty) ...[
                  SizedBox(
                    height: 180,
                    child: PageView.builder(
                      itemCount: room.imageUrls.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            room.imageUrls[index],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) => progress == null
                              ? child
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(child: CircularProgressIndicator()),
                                ),
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(Icons.image, size: 72, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Room ${room.roomId}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('${room.roomType.toUpperCase()} | Floor ${room.floor}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: room.isFull() ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        room.availabilityStatus,
                        style: TextStyle(
                          color: room.isFull() ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                _RoomDetailRow(Icons.confirmation_number, 'Room Number', room.roomNumber),
                _RoomDetailRow(Icons.category, 'Room Type', room.roomType.toUpperCase()),
                _RoomDetailRow(Icons.circle, 'Capacity', '${room.capacity} Person(s)'),
                _RoomDetailRow(Icons.apartment, 'Floor', '${room.floor}'),
                _RoomDetailRow(Icons.payments, 'Rent', 'Rs. ${totalPrice.toInt()}'),
                const SizedBox(height: 16),
                const Text('Facilities', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (room.hasAC) _facilityChip('AC'),
                    if (room.hasAttachedBathroom) _facilityChip('Attached Bathroom'),
                    if (room.hasWifi) _facilityChip('WiFi'),
                    if (room.isFurnished) _facilityChip('Furnished Room'),
                    if (room.hasKitchenAccess) _facilityChip('Kitchen Access'),
                    if (room.hasLaundry) _facilityChip('Laundry'),
                    if (!room.hasAC) _facilityChip('No AC', isActive: false),
                  ],
                ),
                const SizedBox(height: 24),
                if (roommate != null) ...[
                  const Text('Roommate Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _RoommateDetailRow('Compatibility', '${compatibilityScore.toStringAsFixed(0)}%'),
                  _RoommateDetailRow('Shared Interests', sharedInterests.isNotEmpty ? sharedInterests.join(', ') : 'No shared interests yet'),
                  _RoommateDetailRow('Lifestyle', '${roommate.studyEnvironment}, ${roommate.sleepSchedule}, ${roommate.guestPreference} guest policy'),
                  const SizedBox(height: 24),
                ],
                if (showAcceptReject) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            state.acceptAssignedRoom(user);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room accepted. You can now make payment.')));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Accept Room'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            state.rejectAssignedRoom(user);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room rejected. Admin has been notified.')));
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Reject Room', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ],
                  ),
                ] else if (showPaymentButton) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushNamed(context, '/payment'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white),
                          child: const Text('Make Payment'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            state.rejectAssignedRoom(user);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room rejected. Admin has been notified.')));
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Reject Room', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ],
                  ),
                ] else if (user.paymentVerified) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('Payment completed. Booking confirmed.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
                if (roommate != null) ...[
                  const SizedBox(height: 16),
                  _actionChip(context, Icons.people, 'Contact Roommate', () {
                    Navigator.pushNamed(context, '/user-details', arguments: roommate.studentId);
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _RoommateDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _actionChip(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusCard(BuildContext context, AppState state, Student user) {
    if (user.assignedRoomId == null) return const SizedBox.shrink();
    final room = state.allRooms.firstWhere((r) => r.roomId == user.assignedRoomId);
    final payments = state.getPaymentHistoryForUser(user.studentId);
    final payment = payments.isNotEmpty ? payments.first : null;

    final String statusText;
    final Color statusColor;
    if (user.paymentVerified) {
      statusText = 'Paid';
      statusColor = Colors.green;
    } else if (user.assignmentStatus == AssignmentStatus.accepted || user.assignmentStatus == AssignmentStatus.assigned) {
      statusText = 'Pending';
      statusColor = Colors.orange;
    } else {
      statusText = 'Waiting for acceptance';
      statusColor = Colors.blue;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text('Rs. ${room.calculateTotalPrice().toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
              ],
            ),
            const SizedBox(height: 16),
            if (payment != null) ...[
              if (payment.paymentMonth != null)
                Text('Month: ${payment.paymentMonth}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Status: ${payment.statusLabel}', style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
              Text('Last action: ${payment.paymentMethod}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Text('${payments.length} payment(s) on record', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
            ],
            if (state.studentNeedsRentPayment(user))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/payment'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                    child: Text(user.paymentVerified ? 'Pay Monthly Rent' : 'Pay Now'),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/payment-history'),
              child: const Text('View full payment history'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsPreview(BuildContext context, AppState state) {
    final latest = state.getNotificationsForCurrentUser().take(3).toList();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (latest.isEmpty)
              const Text('No recent notifications.', style: TextStyle(color: Colors.grey))
            else
              ...latest.map((n) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: _getNotifIcon(n.type),
                    title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(n.message),
                  )),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showNotifications(context, state),
              child: const Text('View all notifications'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _facilityChip(String label, {bool isActive = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF6C63FF).withOpacity(0.12) : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? const Color(0xFF6C63FF) : Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection(BuildContext context, AppState state) {
    final recommended = state.getRecommendedRooms();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Suggested for You', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/profile'),
              child: const Text('Filter'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recommended.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No room suggestions yet.', style: TextStyle(color: Colors.grey)),
                    Text(
                      'Need hostel approved first. Then rooms matching your profile budget & facilities.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recommended.length,
              itemBuilder: (context, index) {
                final room = recommended[index];
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 16),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(context, '/room-details', arguments: room.roomId),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Room ${room.roomId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text(room.roomType.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const Spacer(),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(room.location, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Rs. ${room.calculateTotalPrice().toInt()}', style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        const Text('Note: Final assignment will be done by the administrator after reviewing your request.', 
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
      ],
    );
  }

}

class _RoomDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RoomDetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(height: 8),
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
