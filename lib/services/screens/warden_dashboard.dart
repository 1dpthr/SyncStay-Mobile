import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../utils/payment_months.dart';
import '../../utils/responsive.dart';
import '../../models/roommate_request.dart';
import '../../models/room.dart';
import '../../models/student.dart';
import '../../models/hostel_request.dart';
import '../../models/unblock_request.dart';
import 'widgets/role_bottom_nav_scaffold.dart';
import 'widgets/unblock_requests_panel.dart';
import 'widgets/hostel_reviews_list.dart';
import 'widgets/payment_history_list.dart';

class WardenDashboard extends StatelessWidget {
  const WardenDashboard({super.key});

  static const _navItems = [
    RoleNavItem(label: 'Overview', icon: Icons.dashboard),
    RoleNavItem(label: 'Users', icon: Icons.people),
    RoleNavItem(label: 'Matches', icon: Icons.favorite),
    RoleNavItem(label: 'Rooms', icon: Icons.meeting_room),
    RoleNavItem(label: 'Requests', icon: Icons.inbox),
    RoleNavItem(label: 'Payments', icon: Icons.payment),
    RoleNavItem(label: 'More', icon: Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final wardenId = state.currentUser?.studentId ?? '';
        final canRequestHostel = state.wardenCanRequestHostelAssignment(wardenId);

        return RoleBottomNavScaffold(
          title: 'Warden',
          items: _navItems,
          header: const _WardenPaymentBanner(),
          floatingActionButton: canRequestHostel
              ? FloatingActionButton(
                  onPressed: () => Navigator.pushNamed(context, '/hostel-request-form'),
                  backgroundColor: const Color(0xFF6C63FF),
                  child: const Icon(Icons.add_business, color: Colors.white),
                )
              : null,
          pages: [
            const _WardenOverviewTab(),
            _UsersTab(),
            _MatchedPairsTab(),
            _RoomsOverviewTab(),
            _AdminHostelRequestsTab(),
            const _WardenPaymentsTab(),
            _WardenMoreTab(),
          ],
        );
      },
    );
  }
}

class _WardenPaymentBanner extends StatelessWidget {
  const _WardenPaymentBanner();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final wardenId = state.currentUser?.studentId ?? '';
        final hostel = state.getAssignedHostelForAdmin(wardenId);
        if (hostel == null) return const SizedBox.shrink();
        final currentMonth = currentPaymentMonthLabel();
        if (state.wardenHasPaidForMonth(wardenId, hostel.id, currentMonth)) {
          return Container(
            width: double.infinity,
            color: Colors.green.withValues(alpha: 0.12),
            padding: const EdgeInsets.all(12),
            child: Text(
              '${hostel.hostelName} — $currentMonth paid ✓',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
          );
        }
        return Container(
          width: double.infinity,
          color: Colors.orange.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Pay Rs.${hostel.rentPerMonth.toInt()} for $currentMonth — ${hostel.hostelName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/warden-payment'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF6C63FF),
                ),
                child: const Text('Proceed to Payment'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WardenOverviewTab extends StatelessWidget {
  const _WardenOverviewTab();

  static const _usersTab = 1;
  static const _matchesTab = 2;
  static const _roomsTab = 3;
  static const _requestsTab = 4;
  static const _paymentsTab = 5;
  static const _moreTab = 6;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final warden = state.currentUser;
        if (warden == null) return const Center(child: CircularProgressIndicator());

        final wardenId = warden.studentId;
        final displayName = warden.name.isNotEmpty ? warden.name : wardenId.split('@')[0];
        final assignedHostel = state.getAssignedHostelForAdmin(wardenId);
        final myHostelRequests = state.getRequestsByAdmin(wardenId);
        final padding = Responsive.horizontalPadding(context);

        if (assignedHostel == null) {
          return _buildPreAssignmentOverview(
            context,
            state,
            displayName,
            myHostelRequests,
            padding,
            state.wardenCanRequestHostelAssignment(wardenId),
          );
        }

        final rooms = state.getRoomsForAdminHostel(wardenId);
        final totalRooms = rooms.length;
        final occupiedRooms = rooms.where((r) => r.currentOccupancy > 0).length;
        final occupancyRate = totalRooms > 0 ? (occupiedRooms / totalRooms * 100).toStringAsFixed(0) : '0';
        final activeStudents = state.getActiveStudentCountForAdmin(wardenId);
        final revenue = state.getRevenueForAdminHostel(wardenId);
        final pendingStudentReqs = state
            .getStudentHostelRequestsForAdmin(wardenId)
            .where((r) => r.status == HostelRequestStatus.pending)
            .length;
        final matchPairs = state.getEligibleHostelMatchPairs(wardenId).length;
        final unblockPending = state.getPendingUnblockRequestsForWarden(wardenId).length;
        final currentMonth = currentPaymentMonthLabel();
        final monthPaid = state.wardenHasPaidForMonth(wardenId, assignedHostel.id, currentMonth);

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeHeader(context, displayName),
              const SizedBox(height: 16),
              _buildHostelCard(assignedHostel.hostelName, assignedHostel.location, assignedHostel.assignedType),
              const SizedBox(height: 16),
              _buildMonthPaymentChip(currentMonth, monthPaid, assignedHostel.rentPerMonth.toInt()),
              if (unblockPending > 0) ...[
                const SizedBox(height: 16),
                _WardenUnblockBanner(count: unblockPending),
              ],
              const SizedBox(height: 20),
              const Text('Hostel Snapshot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildStatCard('Active Students', activeStudents.toString(), Icons.people, Colors.purple),
                  _buildStatCard('Rooms', totalRooms.toString(), Icons.meeting_room, Colors.blue),
                  _buildStatCard('Occupancy', '$occupancyRate%', Icons.pie_chart, Colors.teal),
                  _buildStatCard('Pending Requests', pendingStudentReqs.toString(), Icons.pending_actions, Colors.orange),
                  _buildStatCard('Match Pairs', matchPairs.toString(), Icons.favorite, Colors.pink),
                  _buildStatCard('Revenue', 'Rs. ${revenue.toInt()}', Icons.monetization_on, Colors.green),
                  if (unblockPending > 0)
                    _buildStatCard('Unblock Queue', unblockPending.toString(), Icons.lock_open, Colors.red),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildActionChip(context, state, Icons.people, 'Manage Users', _usersTab),
                  _buildActionChip(context, state, Icons.favorite, 'View Matches', _matchesTab),
                  _buildActionChip(context, state, Icons.meeting_room, 'Rooms', _roomsTab),
                  _buildActionChip(
                    context,
                    state,
                    Icons.inbox,
                    'Student Requests',
                    _requestsTab,
                    badge: pendingStudentReqs,
                  ),
                  _buildActionChip(context, state, Icons.payment, 'Payments', _paymentsTab),
                  _buildActionChip(
                    context,
                    state,
                    Icons.analytics,
                    'Analytics',
                    _moreTab,
                    onTap: () => Navigator.pushNamed(context, '/admin-analytics'),
                  ),
                  _buildActionChip(
                    context,
                    state,
                    Icons.history,
                    'Payment History',
                    _paymentsTab,
                    onTap: () => Navigator.pushNamed(context, '/payment-history'),
                  ),
                  if (!monthPaid)
                    _buildActionChip(
                      context,
                      state,
                      Icons.credit_card,
                      'Pay Rent',
                      _paymentsTab,
                      onTap: () => Navigator.pushNamed(context, '/warden-payment'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Recent Student Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._buildRecentStudentRequests(state, wardenId),
              const SizedBox(height: 20),
              const Text('Community Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const HostelReviewsList(maxItems: 5),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreAssignmentOverview(
    BuildContext context,
    AppState state,
    String displayName,
    List<HostelRequest> myRequests,
    double padding,
    bool canRequest,
  ) {
    final pending = myRequests.where((r) => r.status == HostelRequestStatus.pending).length;
    final booked = myRequests.where((r) => r.status == HostelRequestStatus.booked).length;
    final rejected = myRequests.where((r) => r.status == HostelRequestStatus.rejected).length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(context, displayName, subtitle: 'Request a hostel from the Owner to unlock management tools.'),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'No hostel assigned yet. Send a request to an Owner and wait for approval. Once assigned, you can manage students, rooms, and payments here.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          if (canRequest) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/hostel-request-form'),
                icon: const Icon(Icons.add_business),
                label: const Text('Request Hostel Assignment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Your Requests to Owner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatCard('Pending', pending.toString(), Icons.hourglass_top, Colors.orange),
              _buildStatCard('Booked', booked.toString(), Icons.check_circle, Colors.green),
              _buildStatCard('Rejected', rejected.toString(), Icons.cancel, Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionChip(
            context,
            state,
            Icons.assignment,
            'My Hostel Requests',
            _requestsTab,
            onTap: () => Navigator.pushNamed(context, '/my-hostel-requests'),
          ),
          const SizedBox(height: 24),
          const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (myRequests.isEmpty)
            const Text('No hostel requests sent yet.', style: TextStyle(color: Colors.grey))
          else
            ...myRequests.take(6).map(
                  (r) => _activityTile(
                    r.hostelName,
                    '${r.location.isNotEmpty ? "${r.location} · " : ""}${r.hostelType} — ${r.status.displayLabel}',
                    r.requestedAt,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, String name, {String? subtitle}) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, $name',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: scheme.onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle ?? 'Your hostel dashboard — students, rooms, payments, and requests at a glance.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildHostelCard(String name, String location, String? type) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Location: $location', style: const TextStyle(color: Colors.grey)),
          if (type != null && type.isNotEmpty)
            Text('Running as: $type', style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMonthPaymentChip(String month, bool paid, int rent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (paid ? Colors.green : Colors.orange).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (paid ? Colors.green : Colors.orange).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(paid ? Icons.check_circle : Icons.schedule, color: paid ? Colors.green : Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              paid ? '$month hostel rent paid (Rs. $rent)' : '$month rent pending — Rs. $rent due',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: paid ? Colors.green.shade800 : Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _buildActionChip(
    BuildContext context,
    AppState state,
    IconData icon,
    String label,
    int tabIndex, {
    int badge = 0,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () => state.jumpToDashboardTab(tabIndex),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (badge > 0) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 10,
                backgroundColor: Colors.red,
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecentStudentRequests(AppState state, String wardenId) {
    final requests = state.getStudentHostelRequestsForAdmin(wardenId).toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    if (requests.isEmpty) {
      return [const Text('No student hostel requests yet.', style: TextStyle(color: Colors.grey))];
    }

    return requests.take(5).map((r) {
      return _activityTile(
        r.studentName.isNotEmpty ? r.studentName : r.studentId,
        '${r.hostelName} — ${r.status.displayLabel}',
        r.requestedAt,
      );
    }).toList();
  }

  Widget _activityTile(String title, String message, DateTime time) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.notifications_active, color: Colors.amber, size: 20),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 12)),
            Text(
              DateFormat('MMM dd, yyyy · hh:mm a').format(time),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHostelRequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final myRequests = state.getRequestsByAdmin(state.currentUser?.studentId ?? '');

        final wardenId = state.currentUser?.studentId ?? '';
        final assigned = state.getAssignedHostelForAdmin(wardenId);
        final canRequest = state.wardenCanRequestHostelAssignment(wardenId);

        if (myRequests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    assigned != null
                        ? 'You manage ${assigned.hostelName}.\nLeave it first to request another hostel.'
                        : 'No hostel requests yet',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (canRequest) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/hostel-request-form'),
                      child: const Text('Request Your First Hostel'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: myRequests.length,
          itemBuilder: (context, index) {
            final request = myRequests[index];
            return _buildRequestCard(context, request);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, HostelRequest request) {
    final state = Provider.of<AppState>(context, listen: false);
    final status = state.effectiveWardenRequestStatus(request);
    final Color statusColor;
    switch (status) {
      case HostelRequestStatus.booked:
        statusColor = Colors.green;
        break;
      case HostelRequestStatus.rejected:
        statusColor = Colors.red;
        break;
      case HostelRequestStatus.pending:
        statusColor = Colors.orange;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(request.hostelName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${request.location.isNotEmpty ? "${request.location} · " : ""}${request.hostelType} — ${status.displayLabel}',
        ),
        trailing: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        onTap: () => Navigator.pushNamed(context, '/my-hostel-requests'),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _searchQuery = '';
  Room? _selectedRoom;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final adminId = state.currentUser?.studentId ?? '';
        final assignedHostel = state.getAssignedHostelForAdmin(adminId);

        if (assignedHostel == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hostel assigned yet.\nRequest a hostel from the Owner and wait for approval to manage users.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        final studentRequests = state.getStudentHostelRequestsForAdmin(adminId);
        final users = state.getStudentsForAdminUsersTab(adminId).where((u) {
          return u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              u.studentId.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        final availableRooms = state.getRoomsForAdminHostel(adminId).where((r) => !r.isFull()).toList();

        final pendingUnblocks = state.getPendingUnblockRequestsForWarden(adminId);

        if (users.isEmpty && _searchQuery.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pendingUnblocks.isNotEmpty) ...[
                _WardenUnblockBanner(count: pendingUnblocks.length),
                const SizedBox(height: 8),
                const UnblockRequestsPanel(
                  pendingOnly: true,
                  emptyMessage: 'No pending unblock requests.',
                ),
                const SizedBox(height: 16),
              ],
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No students have requested your hostel yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            if (pendingUnblocks.isNotEmpty) ...[
              _WardenUnblockBanner(count: pendingUnblocks.length),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: UnblockRequestsPanel(
                  pendingOnly: true,
                  emptyMessage: 'No pending unblock requests.',
                ),
              ),
              const SizedBox(height: 8),
            ],
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final hostelReq = state.getStudentHostelRequestRecord(adminId, user.studentId);
                  final reqStatus = hostelReq?.status;
                  bool hasRoom = user.assignedRoomId != null;
                  String cleanUsername = user.studentId.split('@')[0];
                  final bool isApproved = reqStatus == HostelRequestStatus.booked;
                  final bool isPending = reqStatus == HostelRequestStatus.pending;
                  final bool isRejected = reqStatus == HostelRequestStatus.rejected;
                  final pendingUnblock = state.getPendingUnblockRequestForStudent(user.studentId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => Navigator.pushNamed(context, '/user-details', arguments: user.studentId),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : cleanUsername[0].toUpperCase(),
                                style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(user.name.isNotEmpty ? user.name : 'User: $cleanUsername', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Budget: Rs. ${user.budget.toInt()} | Hostel: ${hostelReq?.hostelName ?? "—"}'
                              '${user.isAccountBlocked ? "\nBlocked: ${user.blockReason ?? "—"}" : ""}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (user.isAccountBlocked)
                                  const Chip(
                                    label: Text('BLOCKED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.redAccent,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  )
                                else if (reqStatus != null)
                                  _hostelReqStatusChip(reqStatus),
                                const SizedBox(width: 6),
                                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary, size: 22),
                              ],
                            ),
                          ),
                          if (isRejected && hostelReq?.adminFeedback != null && hostelReq!.adminFeedback!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(hostelReq.adminFeedback!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                          const Divider(),
                          if (!user.isAccountBlocked)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showBlockUserDialog(context, state, user),
                                icon: const Icon(Icons.block, size: 18, color: Colors.red),
                                label: const Text('Block User', style: TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                            ),
                          if (user.isAccountBlocked) ...[
                            Text(
                              'Account blocked${user.lastLeftRoomId != null ? " (left ${user.lastLeftRoomId})" : ""}. Data is saved.',
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                            if (pendingUnblock != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Unblock request received',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      pendingUnblock.message,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => state.rejectUnblockRequest(pendingUnblock.id),
                                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                            child: const Text('Reject'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              final ok = await state.approveUnblockRequest(pendingUnblock.id);
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    ok
                                                        ? '${user.name.isNotEmpty ? user.name : cleanUsername} unblocked'
                                                        : 'Could not unblock — check internet',
                                                  ),
                                                ),
                                              );
                                            },
                                            child: const Text('Approve Unblock'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  final ok = await state.wardenUnblockStudent(user.studentId);
                                  if (!context.mounted) return;
                                  if (ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${user.name.isNotEmpty ? user.name : cleanUsername} unblocked')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not unblock — check internet and try again')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.lock_open, size: 18, color: Colors.green),
                                label: const Text('Unblock Now (no request needed)', style: TextStyle(color: Colors.green, fontSize: 12)),
                              ),
                            ),
                          ] else if (isPending && hostelReq != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      state.rejectStudentHostelRequest(hostelReq.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${user.name} request rejected')),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Reject'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      state.approveStudentHostelRequest(hostelReq.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${user.name} approved — assign room when ready')),
                                      );
                                    },
                                    child: const Text('Approve'),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (isApproved && !hasRoom) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<Room>(
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    hint: const Text('Assign Room'),
                                    value: user.requestedRoomId != null ? availableRooms.where((r) => r.roomId == user.requestedRoomId).firstOrNull : null,
                                    items: availableRooms.map((r) => DropdownMenuItem(
                                      value: r,
                                      child: Text('Room ${r.roomId} (Rs.${r.calculateTotalPrice().toInt()})'),
                                    )).toList(),
                                    onChanged: (val) => setState(() => _selectedRoom = val),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    final roomToAssign = _selectedRoom ?? (user.requestedRoomId != null ? availableRooms.where((r) => r.roomId == user.requestedRoomId).firstOrNull : null);
                                    if (roomToAssign != null) {
                                      state.assignStudentToRoom(user, roomToAssign);
                                      setState(() => _selectedRoom = null);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room ${roomToAssign.roomId} assigned to ${user.name}')));
                                    }
                                  },
                                  child: const Text('Assign'),
                                ),
                              ],
                            ),
                          ] else if (isRejected) ...[
                            const Text(
                              'Hostel request rejected — not eligible for room assignment.',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ] else if (isApproved && hasRoom) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Room: ${user.assignedRoomId}',
                                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      user.paymentVerified
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Paid',
                                                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            )
                                          : Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Pending',
                                                style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => state.unassignFromRoom(user),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Unassign', style: TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _hostelReqStatusChip(HostelRequestStatus? status) {
    if (status == null) return const SizedBox.shrink();
    Color color;
    switch (status) {
      case HostelRequestStatus.booked:
        color = Colors.green;
        break;
      case HostelRequestStatus.rejected:
        color = Colors.red;
        break;
      case HostelRequestStatus.pending:
        color = Colors.orange;
        break;
    }
    return Chip(
      label: Text(status.displayLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.2),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _showBlockUserDialog(BuildContext context, AppState state, Student user) {
    final detailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${user.name.isNotEmpty ? user.name : user.studentId}?'),
        content: TextField(
          controller: detailController,
          decoration: const InputDecoration(
            labelText: 'Short reason (required)',
            hintText: 'e.g. Policy violation',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (detailController.text.trim().isEmpty) return;
              final ok = await state.wardenBlockStudent(user.studentId, detailController.text.trim());
              if (!context.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? '${user.name} has been blocked' : 'Could not block — check internet',
                  ),
                ),
              );
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRemoveUserDialog(BuildContext context, AppState state, String fullUsername) {
    String cleanName = fullUsername.split('@')[0];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove User'),
        content: Text('Are you sure you want to remove user $cleanName? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              state.removeUser(fullUsername);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User $cleanName has been removed')));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _MatchedPairsTab extends StatefulWidget {
  const _MatchedPairsTab();

  @override
  State<_MatchedPairsTab> createState() => _MatchedPairsTabState();
}

class _MatchedPairsTabState extends State<_MatchedPairsTab> {
  final Map<String, Room?> _selectedRoomByPair = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final adminId = state.currentUser?.studentId ?? '';
        final assignedHostel = state.getAssignedHostelForAdmin(adminId);

        if (assignedHostel == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hostel assigned yet.\nMatched pairs can be managed after the Owner approves your hostel request.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        final matchPairs = state.getEligibleHostelMatchPairs(adminId);
        final availableRooms = state.getRoomsForAdminHostel(adminId).where((r) => !r.isFull() && r.capacity >= 2).toList();

        if (matchPairs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No matched pairs yet.\nBoth students need: approved hostel (same), 75%+ match, and an accepted roommate request between them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matchPairs.length,
          itemBuilder: (context, index) {
            final pair = matchPairs[index];
            final selectedRoom = _selectedRoomByPair[pair.pairKey];

            String nameA = pair.studentA.name.isNotEmpty ? pair.studentA.name : pair.studentA.studentId.split('@')[0];
            String nameB = pair.studentB.name.isNotEmpty ? pair.studentB.name : pair.studentB.studentId.split('@')[0];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.pink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              InkWell(
                                onTap: () => Navigator.pushNamed(context, '/user-details', arguments: pair.studentA.studentId),
                                child: Text(
                                  nameA,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const Text('&', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              InkWell(
                                onTap: () => Navigator.pushNamed(context, '/user-details', arguments: pair.studentB.studentId),
                                child: Text(
                                  nameB,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Compatibility: ${pair.compatibilityScore.toInt()}%'),
                    Text(
                      'Same hostel: ${assignedHostel.hostelName}',
                      style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12),
                    ),
                    const Divider(height: 24),
                    const Text('Assign Room:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Room>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      hint: const Text('Select an available room'),
                      value: selectedRoom,
                      items: availableRooms.map((room) {
                        return DropdownMenuItem(
                          value: room,
                          child: Text('Room ${room.roomId} (${room.roomType})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedRoomByPair[pair.pairKey] = val),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedRoom == null
                            ? null
                            : () {
                                final success = state.assignRoom(pair.studentA, pair.studentB, selectedRoom!);
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Room assigned successfully!')),
                                  );
                                  setState(() => _selectedRoomByPair.remove(pair.pairKey));
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Confirm Assignment'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RoomsOverviewTab extends StatelessWidget {
  const _RoomsOverviewTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final adminId = state.currentUser?.studentId ?? '';
        final assignedHostel = state.getAssignedHostelForAdmin(adminId);
        final rooms = state.getRoomsForAdminHostel(adminId);

        if (assignedHostel == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hostel assigned yet.\nRoom overview will appear after the Owner approves your hostel request.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        if (rooms.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No rooms found for ${assignedHostel.hostelName}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/room-details',
                    arguments: room.roomId,
                  );
                },
                child: ListTile(
                  leading: Icon(
                    room.isFull() ? Icons.door_front_door : Icons.meeting_room,
                    color: room.isFull() ? Colors.red : Colors.green,
                  ),
                  title: Text('Room ${room.roomId} (${room.block}-${room.roomNumber})'),
                  subtitle: Text('Type: ${room.roomType.toUpperCase()} | AC: ${room.hasAC ? "Yes" : "No"}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${room.currentOccupancy}/${room.capacity}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: room.isFull() ? Colors.red : Colors.green,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WardenUnblockBanner extends StatelessWidget {
  final int count;

  const _WardenUnblockBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_open, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count student unblock ${count == 1 ? 'request' : 'requests'} waiting — approve below',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _WardenPaymentsTab extends StatelessWidget {
  const _WardenPaymentsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final wardenId = state.currentUser?.studentId ?? '';
        final hostel = state.getAssignedHostelForAdmin(wardenId);
        final payments = state.getWardenFullPaymentHistory(wardenId);
        final currentMonth = currentPaymentMonthLabel();
        final currentMonthPaid = hostel != null &&
            state.wardenHasPaidForMonth(wardenId, hostel.id, currentMonth);
        final availableMonths = hostel != null
            ? state.getAvailablePaymentMonthsForWarden(wardenId, hostel.id)
            : <String>[];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Payment History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your hostel fee + student rent payments for your hostel. Each month can be paid only once.',
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 16),
              if (hostel == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No hostel assigned yet. After admin approves your assignment, monthly payments will appear here.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hostel.hostelName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        if (hostel.location.isNotEmpty)
                          Text(hostel.location, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              currentMonthPaid ? Icons.check_circle : Icons.schedule,
                              color: currentMonthPaid ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentMonthPaid
                                    ? '$currentMonth — hostel fee paid'
                                    : '$currentMonth — hostel fee pending (Rs.${hostel.rentPerMonth.toInt()})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: currentMonthPaid ? Colors.green : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!currentMonthPaid && availableMonths.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pushNamed(context, '/warden-payment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Pay for $currentMonth'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PaymentHistoryList(
                  payments: payments,
                  showUserName: true,
                  emptyMessage: 'No payment records yet for your hostel.',
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WardenMoreTab extends StatelessWidget {
  const _WardenMoreTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Quick Tools', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _toolTile(context, Icons.exit_to_app, 'Leave Assigned Hostel', () => _confirmLeaveHostel(context)),
        _toolTile(context, Icons.lock_open, 'Unblock Requests', () => _openUnblockSheet(context)),
        _toolTile(context, Icons.analytics, 'Analytics', () => Navigator.pushNamed(context, '/admin-analytics')),
        _toolTile(context, Icons.assignment, 'Match & Room Requests', () => Navigator.pushNamed(context, '/admin-requests')),
        _toolTile(context, Icons.history_edu, 'My Hostel Requests', () => Navigator.pushNamed(context, '/my-hostel-requests')),
        _toolTile(context, Icons.description, 'Reports', () => Navigator.pushNamed(context, '/admin-reports')),
        const SizedBox(height: 20),
        const Text('Student Hostel Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const HostelReviewsList(maxItems: 20),
      ],
    );
  }

  Widget _toolTile(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF6C63FF)),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _confirmLeaveHostel(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final me = state.currentUser;
    if (me == null) return;
    final hostel = state.getAssignedHostelForAdmin(me.studentId);
    if (hostel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assigned hostel to leave.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave hostel?'),
        content: Text(
          'You are leaving ${hostel.hostelName}.\n\n'
          'Your account will be blocked and owner/admin can assign a new warden.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final err = state.wardenLeaveAssignedHostel(me);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err ?? 'Hostel left successfully.')),
              );
            },
            child: const Text('Leave Hostel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openUnblockSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Unblock Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: const UnblockRequestsPanel(
                    emptyMessage: 'No student unblock requests yet.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
