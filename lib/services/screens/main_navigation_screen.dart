import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../matching_engine.dart';
import '../../models/student.dart';
import '../../models/room.dart';
import '../../models/payment.dart';
import '../../models/roommate_request.dart';
import '../../models/notification.dart';
import '../../models/hostel.dart';
import 'widgets/match_breakdown_chart.dart';
import 'widgets/hostel_reviews_list.dart';
import 'widgets/syncstay_app_bar.dart';
import 'widgets/payment_history_list.dart';
import 'inbox_screen.dart';
import '../../utils/responsive.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final PageController _pageController = PageController();
  int _hoveredIndex = -1;

  final _navItems = const [
    _NavItem(label: 'Home', icon: Icons.home),
    _NavItem(label: 'Room Matching', icon: Icons.meeting_room),
    _NavItem(label: 'Roommates', icon: Icons.people),
    _NavItem(label: 'Skills', icon: Icons.psychology),
    _NavItem(label: 'Notifications', icon: Icons.notifications),
    _NavItem(label: 'Profile', icon: Icons.person),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToTab(int index, AppState state) {
    state.setSelectedNavIndex(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final currentUser = state.currentUser;
        if (currentUser == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (currentUser.isAccountBlocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/blocked-account');
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final activeIndex = state.selectedNavIndex;
        final title = _navItems[activeIndex].label;

        return Scaffold(
          extendBody: true,
          appBar: syncStayAppBar(
            context,
            screenTitle: title,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Requests Inbox',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen())),
                icon: Badge(
                  isLabelVisible: state.pendingIncomingRequestCount > 0,
                  label: Text('${state.pendingIncomingRequestCount}'),
                  child: const Icon(Icons.inbox_outlined),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.brightness_6),
                onPressed: state.toggleTheme,
                tooltip: 'Toggle Theme',
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () => _showNotifications(context, state),
                tooltip: 'Notifications',
              ),
            ],
          ),
          drawer: _buildAppDrawer(state),
          body: PageView(
            controller: _pageController,
            onPageChanged: state.setSelectedNavIndex,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildHomeTab(state),
              _buildRoomMatchingTab(state),
              _buildRoommatesTab(state),
              _buildSkillsExchangeTab(state),
              _buildNotificationsTab(state),
              _buildProfileTab(state),
            ],
          ),
          bottomNavigationBar: _buildBottomNavigationBar(state),
        );
      },
    );
  }

  Widget _buildAppDrawer(AppState state) {
    final user = state.currentUser!;
    final displayName = user.name.isNotEmpty ? user.name : user.studentId.split('@')[0];

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text('${syncStaySiteLabel(user.role)}\n$user.studentId'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                displayName[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 32,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              _jumpToTab(0, state);
            },
          ),
          ListTile(
            leading: const Icon(Icons.meeting_room),
            title: const Text('Room Matching'),
            onTap: () {
              Navigator.pop(context);
              _jumpToTab(1, state);
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Roommates'),
            onTap: () {
              Navigator.pop(context);
              _jumpToTab(2, state);
            },
          ),
          ListTile(
            leading: const Icon(Icons.psychology),
            title: const Text('Skills Exchange'),
            onTap: () {
              Navigator.pop(context);
              _jumpToTab(3, state);
            },
          ),
          ListTile(
            leading: const Icon(Icons.inbox),
            title: const Text('Requests Inbox'),
            trailing: state.pendingIncomingRequestCount > 0
                ? CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.red,
                    child: Text(
                      '${state.pendingIncomingRequestCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()));
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
    );
  }

  Widget _buildBottomNavigationBar(AppState state) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final active = state.selectedNavIndex == index;
                  final hover = _hoveredIndex == index;

                  return Expanded(
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hoveredIndex = index),
                      onExit: (_) => setState(() => _hoveredIndex = -1),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                          hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                          onTap: () => _jumpToTab(index, state),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                            decoration: BoxDecoration(
                              color: active ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: active ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                width: 1,
                              ),
                              boxShadow: hover
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 22,
                                  color: active
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    item.label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isCompact ? 9 : 11,
                                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                                      color: active
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
      ),
    );
  }

  Widget _buildHomeTab(AppState state) {
    final user = state.currentUser!;
    final hostelApproved = state.studentHasBookedHostel(user.studentId);
    final recommendedCount =
        hostelApproved ? state.getRecommendedRooms().length : 0;
    final assignedCount = user.assignedRoomId != null ? 1 : 0;
    final pendingPayments = state.allPayments
        .where((payment) => payment.userId == user.studentId && payment.status == PaymentStatus.pending)
        .length;

    return SingleChildScrollView(
      key: const ValueKey('home-tab'),
      padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChipHeader('Welcome back, ${user.name.isNotEmpty ? user.name : user.studentId.split('@')[0]}'),
          if (state.pendingIncomingRequestCount > 0) ...[
            const SizedBox(height: 16),
            _buildPendingInboxBanner(state),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard('Suggested Rooms', recommendedCount, Colors.blue),
              _buildStatCard('Assigned Rooms', assignedCount, Colors.green),
              _buildStatCard('Payments Pending', pendingPayments, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          _buildBookingProgress(state),
          const SizedBox(height: 24),
          if (user.assignedRoomId != null) ...[
            _buildAssignedRoomCard(context, state, user),
            const SizedBox(height: 22),
            _buildPaymentStatusPanel(state),
            const HostelReviewPromptCard(),
            const SizedBox(height: 20),
            const Text('Community Hostel Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const HostelReviewsList(maxItems: 15),
          ] else ...[
            _buildHostelsSection(state),
            const SizedBox(height: 20),
            const Text('Community Hostel Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const HostelReviewsList(maxItems: 15),
          ],
          const SizedBox(height: 28),
          const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildQuickActions(state),
        ],
      ),
    );
  }

  Widget _buildRoomMatchingTab(AppState state) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          _buildSecondaryTabBar(['Suggested Rooms', 'Requested Rooms', 'Assigned Room', 'Payment Status']),
          Expanded(
            child: TabBarView(
              children: [
                _buildSuggestedRoomsList(state),
                _buildRequestedRoomsList(state),
                _buildAssignedRoomSummary(state),
                _buildPaymentStatusPanel(state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoommatesTab(AppState state) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          _buildSecondaryTabBar(['Suggested Matches', 'Sent Requests', 'Received Requests', 'Accepted Matches', 'Rejected Matches']),
          Expanded(
            child: TabBarView(
              children: [
                _buildSuggestedMatches(state),
                _buildSentRequests(state),
                _buildReceivedRequests(state),
                _buildFilteredRequests(state, RequestStatus.accepted, 'No accepted matches yet'),
                _buildFilteredRequests(state, RequestStatus.rejected, 'No rejected matches yet'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsExchangeTab(AppState state) {
    final user = state.currentUser!;
    final suggestedPartners = state.getSkillPeers();

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          _buildSecondaryTabBar(['Skills I Teach', 'Skills I Learn', 'Suggested Partners', 'Custom Skills']),
          Expanded(
            child: TabBarView(
              children: [
                _buildSkillListTab(user.skills, 'Add skills in your profile to teach others.'),
                _buildSkillListTab(user.learningSkills, 'Add learning skills in your profile.'),
                _buildSuggestedSkillPartners(state, suggestedPartners),
                _buildSkillListTab([user.otherSkills].where((s) => s.isNotEmpty).toList(), 'Add custom skills in your profile.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab(AppState state) {
    final notifications = state.getNotificationsForCurrentUser();

    return Container(
      key: const ValueKey('notifications-tab'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: notifications.isEmpty
                ? const Center(child: Text('No notifications available.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: notification.isRead ? Theme.of(context).cardColor : Theme.of(context).colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey.withOpacity(0.08)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _getNotifIcon(notification.type),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(notification.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(notification.message, style: const TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${notification.timestamp.hour.toString().padLeft(2, '0')}:${notification.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(AppState state) {
    final user = state.currentUser!;
    final displayName = user.name.isNotEmpty ? user.name : user.studentId.split('@')[0];

    return SingleChildScrollView(
      key: const ValueKey('profile-tab'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  displayName[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 34,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(user.department.isNotEmpty ? user.department : user.preferredLocation, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Profile Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildInfoField('Email', user.email),
          _buildInfoField('Phone', user.phoneNumber),
          _buildInfoField('Budget', 'Rs. ${user.budget.toInt()}'),
          _buildInfoField('Preferences', '${user.preferredLocation} • ${user.preferredSharing}'),
          const SizedBox(height: 24),
          const Text('Skills', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: user.skills.map((skill) => Chip(label: Text(skill))).toList()),
          if (user.skills.isEmpty) const Text('No skills defined yet. Update your profile.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          const Text('Learning Goals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: user.learningSkills.map((skill) => Chip(label: Text(skill))).toList()),
          if (user.learningSkills.isEmpty) const Text('No learning goals defined. Update your profile.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/profile'),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile & Preferences'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      builder: (context, animatedValue, child) {
        final onSurface = Theme.of(context).colorScheme.onSurface;
        return Container(
          width: Responsive.statCardWidth(context),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                animatedValue.toInt().toString(),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: onSurface),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecondaryTabBar(List<String> tabs) {
    return Material(
      color: Theme.of(context).cardColor,
      elevation: 4,
      child: TabBar(
        isScrollable: true,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Colors.grey,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
        ),
        tabs: tabs.map((label) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Tab(text: label))).toList(),
      ),
    );
  }

  Widget _buildSuggestedRoomsList(AppState state) {
    final user = state.currentUser!;
    final rooms = state.getRecommendedRooms();
    if (rooms.isEmpty) {
      final profileDone = user.profileCompleted;
      final booked = state.getBookedHostelRequestForStudent(user.studentId);
      final hasHostels = state.getHostelsByGender(user.gender, preferredLocation: user.preferredLocation).isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            !profileDone
                ? 'Complete your profile first (location, budget, AC/bath, etc.).'
                : booked == null
                    ? 'Room suggestions appear after a warden approves your hostel request.'
                    : !hasHostels
                        ? 'No hostels in your preferred location yet. Update location in Profile.'
                        : 'No rooms within your monthly budget (Rs.${user.budget.toInt()}) in this hostel. Increase budget in Profile or pick a room with fewer facilities.',
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
        return _buildAnimatedRoomCard(room, state);
      },
    );
  }

  Widget _buildHostelsSection(AppState state) {
    final hostels = state.getHostelsByGender(
      state.currentUser?.gender ?? 'Female',
      preferredLocation: state.currentUser?.preferredLocation,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Available Hostels', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        if (hostels.isEmpty)
          Center(
            child: Text(
              (state.currentUser?.preferredLocation.trim().isEmpty ?? true)
                  ? 'Set your preferred city/area in Profile to see hostels in that location.'
                  : 'No hostels in "${state.currentUser!.preferredLocation}" for your gender yet. Try a nearby city or area name in Profile.',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: hostels.length,
            itemBuilder: (context, index) {
              final hostel = hostels[index];
              return _buildHostelCard(hostel, state);
            },
          ),
      ],
    );
  }

  Widget _buildHostelCard(Hostel hostel, AppState state) {
    final studentId = state.currentUser?.studentId ?? '';
    final pendingReq = state.getPendingHostelRequestForStudent(studentId);
    final bookedReq = state.getBookedHostelRequestForStudent(studentId);
    final blockReason = state.studentHostelRequestBlockReason(studentId, forHostelId: hostel.id);
    final alreadyRequested = state.hostelRequests.any(
      (r) => r.isStudentJoinRequest && r.hostelId == hostel.id && r.studentId == studentId,
    );
    final isThisPending = pendingReq?.hostelId == hostel.id;
    final isThisBooked = bookedReq?.hostelId == hostel.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(hostel.hostelName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Chip(
                  label: Text(
                    (hostel.assignedType ?? 'Hostel').toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${hostel.location}'),
            Text('Floors: ${hostel.totalFloors} | Total Rooms: ${hostel.totalRooms}'),
            if (blockReason != null && !isThisBooked && !isThisPending) ...[
              const SizedBox(height: 8),
              Text(blockReason, style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (alreadyRequested || isThisBooked || !state.studentCanRequestHostel(studentId, hostelId: hostel.id))
                    ? null
                    : () {
                        final err = state.sendHostelRequest(hostel.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(err ?? 'Hostel request sent to warden!'),
                          ),
                        );
                      },
                child: Text(
                  isThisBooked
                      ? 'Hostel Approved'
                      : isThisPending
                          ? 'Awaiting Warden Approval'
                          : alreadyRequested
                              ? 'Request Sent'
                              : 'Send Hostel Request',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestedRoomsList(AppState state) {
    final user = state.currentUser!;
    if (user.requestedRoomId == null) {
      return const Center(child: Text('No requested rooms yet.', style: TextStyle(color: Colors.grey)));
    }
    final room = state.allRooms.firstWhere((room) => room.roomId == user.requestedRoomId);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _buildAnimatedRoomCard(room, state),
    );
  }

  Widget _buildAssignedRoomSummary(AppState state) {
    final user = state.currentUser!;
    if (user.assignedRoomId == null) {
      return const Center(child: Text('No assigned room yet.', style: TextStyle(color: Colors.grey)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildAssignedRoomCard(context, state, user),
    );
  }

  Widget _buildPaymentStatusPanel(AppState state) {
    final user = state.currentUser!;
    Room? room;
    if (user.assignedRoomId != null) {
      try {
        room = state.allRooms.firstWhere((r) => r.roomId == user.assignedRoomId);
      } catch (_) {
        room = null;
      }
    }
    final payments = state.getPaymentHistoryForUser(user.studentId);

    if (room == null && payments.isEmpty) {
      return const Center(child: Text('No payment status available yet.', style: TextStyle(color: Colors.grey)));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChipHeader('Payment History'),
          const SizedBox(height: 12),
          if (room != null) ...[
            _buildInfoField('Room ID', room.roomId),
            _buildInfoField('Monthly Rent', 'Rs. ${room.calculateTotalPrice().toInt()}'),
          ],
          StudentOutstandingPaymentCard(
            onPayNow: () => Navigator.pushNamed(context, '/payment'),
          ),
          const SizedBox(height: 12),
          if (user.assignmentStatus == AssignmentStatus.assigned) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      state.acceptAssignedRoom(user);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Room accepted. Payment is now available.')),
                      );
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Room rejected. Admin has been notified.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    child: const Text('Reject Room', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ] else if (state.studentNeedsRentPayment(user))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/payment'),
                  child: Text(
                    user.paymentVerified ? 'Pay Monthly Rent' : 'Go to Payment',
                  ),
                ),
              ),
            ),
          PaymentHistoryList(
            payments: payments,
            emptyMessage: 'No payments yet. Pay rent after accepting your room.',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/payment-history'),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Full Payment History'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedMatches(AppState state) {
    final matches = state.getSuggestedRoommatesForCurrentUser(topN: 10);
    if (matches.isEmpty) {
      final hasBookedHostel = state.getBookedHostelRequestForStudent(state.currentUser?.studentId ?? '') != null;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            hasBookedHostel
                ? 'No suggested users yet.\nOthers need the same approved hostel and 75%+ compatibility with you.'
                : 'Suggested users appear after the Warden approves your hostel request.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return _buildMatchCard(match, state);
      },
    );
  }

  Widget _buildSentRequests(AppState state) {
    final sent = state.getOutgoingRequests().where((r) => r.type == RequestType.roommate).toList();
    if (sent.isEmpty) {
      return const Center(child: Text('No sent roommate requests.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sent.length,
      itemBuilder: (context, index) {
        final request = sent[index];
        return _buildRequestCard(request, state, isOutgoing: true);
      },
    );
  }

  Widget _buildReceivedRequests(AppState state) {
    final incoming = state.getIncomingRoommateRequests();
    if (incoming.isEmpty) {
      return const Center(child: Text('No incoming roommate requests.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: incoming.length,
      itemBuilder: (context, index) {
        final request = incoming[index];
        return _buildRequestCard(request, state, isOutgoing: false);
      },
    );
  }

  Widget _buildFilteredRequests(AppState state, RequestStatus status, String emptyMessage) {
    final userId = state.currentUser!.studentId;
    final filtered = state.allRequests
        .where((request) =>
            request.type == RequestType.roommate &&
            request.status == status &&
            (request.senderId == userId || request.receiverId == userId))
        .toList();
    if (filtered.isEmpty) {
      return Center(child: Text(emptyMessage, style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final request = filtered[index];
        return _buildRequestCard(request, state, isOutgoing: request.senderId == state.currentUser!.studentId);
      },
    );
  }

  Widget _buildSkillListTab(List<String> items, String emptyMessage) {
    if (items.isEmpty) {
      return Center(child: Text(emptyMessage, style: const TextStyle(color: Colors.grey)));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((skill) => Chip(label: Text(skill))).toList(),
      ),
    );
  }

  Widget _buildSuggestedSkillPartners(AppState state, List<Student> partners) {
    if (partners.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No suggested partners found.\nOnly students with the same gender as you are shown here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: partners.length,
      itemBuilder: (context, index) {
        final peer = partners[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: ListTile(
            leading: CircleAvatar(child: Text(peer.name.isNotEmpty ? peer.name[0] : peer.studentId[0])),
            title: Text(peer.name.isNotEmpty ? peer.name : peer.studentId.split('@')[0]),
            subtitle: Text('Skills: ${peer.skills.join(', ')}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/user-details', arguments: peer.studentId),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(AppState state) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildActionCard(Icons.people_alt, 'Find Roommates', () => _jumpToTab(2, state)),
        _buildActionCard(Icons.meeting_room, 'Room Matching', () => _jumpToTab(1, state)),
        _buildActionCard(Icons.psychology, 'Skill Exchange', () => _jumpToTab(3, state)),
        _buildActionCard(Icons.inbox, 'Requests Inbox', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()));
        }, badgeCount: state.pendingIncomingRequestCount),
        _buildActionCard(Icons.payment, 'Payment History', () {
          Navigator.pushNamed(context, '/payment-history');
        }),
        _buildActionCard(Icons.notifications, 'Notifications', () => _jumpToTab(4, state)),
      ],
    );
  }

  Widget _buildPendingInboxBanner(AppState state) {
    final count = state.pendingIncomingRequestCount;
    final roommate = state.getIncomingRoommateRequests().length;
    final skill = state.getIncomingSkillRequests().length;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.inbox, color: scheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count pending request${count == 1 ? '' : 's'}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: scheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (roommate > 0) '$roommate roommate',
                        if (skill > 0) '$skill skill',
                      ].join(' • '),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to open Inbox — Accept / Reject karein',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String label, VoidCallback onTap, {int badgeCount = 0}) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;
    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: scheme.primary.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: Responsive.quickActionCardWidth(context),
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 22, color: scheme.primary),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  height: 1.25,
                  color: scheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingProgress(AppState state) {
    final user = state.currentUser!;
    final hostelBooked = state.studentHasBookedHostel(user.studentId);
    final hostelPending = state.getPendingHostelRequestForStudent(user.studentId) != null;

    int currentStep = -1;
    if (hostelBooked && user.assignedRoomId == null) {
      currentStep = 0;
    }
    if (user.assignmentStatus == AssignmentStatus.assigned) {
      currentStep = 1;
    }
    if (user.assignmentStatus == AssignmentStatus.accepted) {
      currentStep = 2;
      Payment? payment;
      try {
        payment = state.allPayments.firstWhere(
          (payment) => payment.userId == user.studentId && payment.roomId == user.assignedRoomId,
        );
      } catch (_) {
        payment = null;
      }
      if (payment != null && payment.status == PaymentStatus.pending) {
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
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Booking Journey', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (hostelPending && !hostelBooked) ...[
            const SizedBox(height: 8),
            Text(
              'Hostel request pending warden approval — room suggestions unlock after approval.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final step = steps[index];
              final completed = currentStep >= 0 && index <= currentStep;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: completed ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(step['icon'] as IconData, color: Colors.white, size: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(step['label'] as String, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: completed ? Theme.of(context).colorScheme.primary : Colors.grey)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedRoomCard(BuildContext context, AppState state, Student user) {
    final room = state.allRooms.firstWhere((room) => room.roomId == user.assignedRoomId);
    final roommate = user.roommateId != null ? state.allStudents.firstWhere((stu) => stu.studentId == user.roommateId) : null;
    final compatibility = roommate != null
        ? state.engine.calculateDetailedCompatibility(user, roommate).compatibilityScore
        : 0.0;
    final sharedInterests = roommate != null
        ? user.skills.where((skill) => roommate.skills.contains(skill)).toList()
        : <String>[];

    final assignmentLabel = user.paymentVerified && user.assignmentStatus == AssignmentStatus.confirmed
        ? 'Booking Confirmed'
        : user.assignmentStatus == AssignmentStatus.accepted
            ? 'Room Accepted'
            : 'Assigned Room';
    final assignmentColor = user.paymentVerified && user.assignmentStatus == AssignmentStatus.confirmed
        ? Colors.green
        : user.assignmentStatus == AssignmentStatus.accepted
            ? Colors.blue
            : Colors.orange;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Assigned Room', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: assignmentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      assignmentLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: assignmentColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (room.imageUrls.isNotEmpty)
              SizedBox(
                height: 180,
                child: PageView.builder(
                  itemCount: room.imageUrls.length,
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
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
            const SizedBox(height: 20),
            _buildInfoField('Room Number', room.roomNumber),
            _buildInfoField('Room Type', room.roomType.toUpperCase()),
            _buildInfoField('Floor', room.floor.toString()),
            _buildInfoField('Capacity', '${room.capacity} Person(s)'),
            _buildInfoField('Status', room.availabilityStatus),
            _buildInfoField('Rent', 'Rs. ${room.calculateTotalPrice().toInt()}'),
            const SizedBox(height: 16),
            const Text('Facilities', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                if (room.hasAC) _buildFacilityChip('AC'),
                if (room.hasAttachedBathroom) _buildFacilityChip('Attached Bathroom'),
                if (room.hasWifi) _buildFacilityChip('WiFi'),
                if (room.isFurnished) _buildFacilityChip('Furnished Room'),
                if (room.hasKitchenAccess) _buildFacilityChip('Kitchen Access'),
                if (room.hasLaundry) _buildFacilityChip('Laundry'),
              ],
            ),
            if (roommate != null) ...[
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 14),
              const Text('Roommate Info', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildInfoField('Roommate', roommate.name.isNotEmpty ? roommate.name : roommate.studentId.split('@')[0]),
              _buildInfoField('Compatibility', '${compatibility.toStringAsFixed(0)}%'),
              _buildInfoField('Shared Interests', sharedInterests.isNotEmpty ? sharedInterests.join(', ') : 'None yet'),
              _buildInfoField('Lifestyle', '${roommate.studyEnvironment}, ${roommate.sleepSchedule}, ${roommate.guestPreference}'),
            ],
            const SizedBox(height: 20),
            if (user.assignmentStatus == AssignmentStatus.assigned) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        state.acceptAssignedRoom(user);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Room accepted. Payment is now available.')),
                        );
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Room rejected. Admin has been notified.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                      child: const Text('Reject Room', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _showAssignedRoomActions(user, state),
                      child: Text(
                        user.assignmentStatus == AssignmentStatus.accepted && !user.paymentVerified
                            ? 'Proceed to Payment'
                            : 'View Room Details',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (roommate != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pushNamed(context, '/user-details', arguments: roommate.studentId),
                        child: const Text('Contact Roommate'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  VoidCallback? _showAssignedRoomActions(Student user, AppState state) {
    if (user.assignmentStatus == AssignmentStatus.accepted && !user.paymentVerified) {
      return () => Navigator.pushNamed(context, '/payment');
    }
    if (user.assignedRoomId != null) {
      return () => Navigator.pushNamed(context, '/room-details', arguments: user.assignedRoomId);
    }
    return null;
  }

  Widget _buildAnimatedRoomCard(Room room, AppState state) {
    final available = !room.isFull();
    final user = state.currentUser!;
    final roomPrice = room.calculateTotalPrice();
    final matchScore = state.getRoomPreferenceScore(room, user);
    final withinBudget = AppState.roomFitsBudget(roomPrice, user.budget);
    final alreadyRequested = state.hasRequestedRoom(room.roomId);
    final hostel = state.getHostelForRoom(room.roomId);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 450),
        builder: (context, progress, child) {
          return Transform.scale(
            scale: 0.95 + (progress * 0.05),
            child: child,
          );
        },
        child: Card(
          margin: const EdgeInsets.only(bottom: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 8,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.pushNamed(context, '/room-details', arguments: room.roomId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (room.imageUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    child: Image.network(
                      room.imageUrls.first,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Room ${room.roomId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: available ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(available ? 'Available' : 'Full', style: TextStyle(color: available ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (hostel != null)
                        Text(hostel.hostelName, style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 13)),
                      Text('${room.roomType.toUpperCase()} • Floor ${room.floor}', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$matchScore% profile match',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          if (withinBudget) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '≤ Rs.${user.budget.toInt()} budget',
                                style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFacilityChip('AC', active: room.hasAC),
                          _buildFacilityChip('WiFi', active: room.hasWifi),
                          if (room.hasAttachedBathroom) _buildFacilityChip('Bath', active: true),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Rs. ${roomPrice.toInt()} / month', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6C63FF))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pushNamed(context, '/room-details', arguments: room.roomId),
                              child: const Text('Details'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (!available || alreadyRequested)
                                  ? null
                                  : () {
                                      state.requestRoom(room.roomId);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Request sent to Admin for Room ${room.roomId}')),
                                      );
                                    },
                              child: Text(alreadyRequested ? 'Requested' : 'Request'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchCard(StudentMatch match, AppState state) {
    final outgoingStatus = state.getOutgoingRoommateRequestStatusTo(match.student);
    final isBest = match.compatibilityScore >= 75;
    final color = isBest ? Colors.purple : Colors.blueGrey;

    // Check for incoming requests
    final incomingRequests = state.allRequests.where((r) => 
      r.type == RequestType.roommate && 
      r.senderId == match.student.studentId && 
      r.receiverId == state.currentUser!.studentId &&
      r.status == RequestStatus.pending
    ).toList();
    final hasIncoming = incomingRequests.isNotEmpty;

    final isCurrentUserMatched = state.isAlreadyMatched(state.currentUser!.studentId);
    final isMatchUserMatched = state.isAlreadyMatched(match.student.studentId);
    final areMatchedWithEachOther = state.currentUser!.roommateId == match.student.studentId;

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: match.compatibilityScore / 100,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                    Text('${match.compatibilityScore.toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pushNamed(context, '/user-details', arguments: match.student.studentId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              match.student.name.isNotEmpty ? match.student.name : match.student.studentId.split('@')[0],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isBest)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                    child: const Text('Best Match', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            MatchBreakdownChart(match: match),
            const SizedBox(height: 14),
            Row(
              children: [
                if (hasIncoming) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final ok = state.approveRoommateRequest(incomingRequests.first.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Roommate request accepted!' : 'Could not accept request.')),
                        );
                      },
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final ok = state.rejectRoommateRequest(incomingRequests.first.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Request rejected.' : 'Could not reject request.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (areMatchedWithEachOther || isCurrentUserMatched || isMatchUserMatched || outgoingStatus != null)
                          ? null
                          : () {
                              state.sendRoommateRequest(match.student.studentId, match.compatibilityScore);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 Compatibility Match Found! Request Sent.')));
                            },
                      child: Text(
                        areMatchedWithEachOther
                            ? 'Matched'
                            : (isCurrentUserMatched || isMatchUserMatched
                                ? 'Unavailable'
                                : (outgoingStatus == null ? 'Send Request' : outgoingStatus.name.toUpperCase()))
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(RoommateRequest request, AppState state, {required bool isOutgoing}) {
    final scheme = Theme.of(context).colorScheme;
    final color = request.status == RequestStatus.accepted
        ? Colors.green
        : request.status == RequestStatus.rejected
            ? Colors.red
            : Colors.blueGrey;

    String displayName = isOutgoing ? request.receiverName : request.senderName;
    if (displayName.isEmpty) {
      displayName = isOutgoing ? request.receiverId.split('@')[0] : request.senderId.split('@')[0];
    }

    final profileId = isOutgoing ? request.receiverId : request.senderId;
    final isPending = request.status == RequestStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.pushNamed(context, '/user-details', arguments: profileId),
              child: Row(
                children: [
                  CircleAvatar(child: Text(profileId[0].toUpperCase())),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOutgoing ? 'To: $displayName' : 'From: $displayName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Compatibility ${request.compatibilityScore.toInt()}%',
                          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (!isPending) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              request.status.name.toUpperCase(),
                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.primary, size: 20),
                ],
              ),
            ),
            if (isPending && !isOutgoing) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final ok = state.approveRoommateRequest(request.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Roommate request accepted!' : 'Could not accept request.')),
                        );
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final ok = state.rejectRoommateRequest(request.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Request rejected.' : 'Could not reject request.')),
                        );
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ],
            if (isPending && isOutgoing) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final ok = state.rejectRoommateRequest(request.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Request cancelled.' : 'Could not cancel request.')),
                    );
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel Request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 125, child: Text('$label:', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildChipHeader(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: scheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          'Everything you need for rooms, matches and payments.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildFacilityChip(String label, {bool active = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF6C63FF).withOpacity(0.12) : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: active ? const Color(0xFF6C63FF) : Colors.grey)),
    );
  }

  Icon _getNotifIcon(NotificationType type) {
    switch (type) {
      case NotificationType.roomAssigned:
        return const Icon(Icons.meeting_room, color: Colors.blue);
      case NotificationType.paymentConfirmed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case NotificationType.roommateMatched:
        return const Icon(Icons.people, color: Colors.purple);
      case NotificationType.requestReceived:
        return const Icon(Icons.mail, color: Colors.orange);
      case NotificationType.info:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }

  void _showNotifications(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(12)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: state.getNotificationsForCurrentUser().length,
                    itemBuilder: (context, index) {
                      final notif = state.getNotificationsForCurrentUser()[index];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: notif.isRead ? Colors.grey.withOpacity(0.08) : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          leading: _getNotifIcon(notif.type),
                          title: Text(notif.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(notif.message),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}
