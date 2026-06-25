import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/hostel.dart';
import '../../models/hostel_request.dart';
import '../../models/student.dart';
import '../../utils/responsive.dart';
import 'widgets/role_bottom_nav_scaffold.dart';
import 'widgets/hostel_reviews_list.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  static const _navItems = [
    RoleNavItem(label: 'Overview', icon: Icons.dashboard),
    RoleNavItem(label: 'Hostels', icon: Icons.apartment),
    RoleNavItem(label: 'Requests', icon: Icons.inbox),
    RoleNavItem(label: 'Wardens', icon: Icons.security),
    RoleNavItem(label: 'Revenue', icon: Icons.payments),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final ownerId = state.currentUser?.studentId ?? '';
        final myHostels = state.getHostelsForOwner(ownerId);
        final wardenRequests = state.getWardenRequestsForOwner(ownerId);
        final revenue = state.getOwnerRevenueTotal(ownerId);

        return RoleBottomNavScaffold(
          title: 'Owner',
          items: _navItems,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, '/add-hostel'),
            icon: const Icon(Icons.add),
            label: const Text('Add Hostel'),
          ),
          pages: [
            const _OwnerOverviewTab(),
            _HostelsList(hostels: myHostels, wardens: state.getWardensForOwner(ownerId), state: state),
            _WardenRequestsList(requests: wardenRequests, state: state),
            _WardensTab(ownerId: ownerId, hostels: myHostels),
            _OwnerRevenueTab(revenue: revenue, hostelCount: myHostels.length),
          ],
        );
      },
    );
  }
}

class _OwnerOverviewTab extends StatelessWidget {
  const _OwnerOverviewTab();

  static const _hostelsTab = 1;
  static const _requestsTab = 2;
  static const _wardensTab = 3;
  static const _revenueTab = 4;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final owner = state.currentUser;
        if (owner == null) return const Center(child: CircularProgressIndicator());

        final ownerId = owner.studentId;
        final displayName = owner.name.isNotEmpty ? owner.name : ownerId.split('@')[0];
        final myHostels = state.getHostelsForOwner(ownerId);
        final wardenRequests = state.getWardenRequestsForOwner(ownerId);
        final wardens = state.getWardensForOwner(ownerId);
        final revenue = state.getOwnerRevenueTotal(ownerId);
        final padding = Responsive.horizontalPadding(context);

        final pendingApproval = myHostels.where((h) => h.approvalStatus == HostelApprovalStatus.pending).length;
        final approvedHostels = myHostels.where((h) => h.approvalStatus == HostelApprovalStatus.approved).length;
        final rejectedHostels = myHostels.where((h) => h.approvalStatus == HostelApprovalStatus.rejected).length;
        final assignedWardens = myHostels
            .where((h) => h.assignedAdminId != null && h.assignedAdminId!.trim().isNotEmpty)
            .length;
        final pendingWardenReqs = wardenRequests
            .where((r) => state.effectiveWardenRequestStatus(r) == HostelRequestStatus.pending)
            .length;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeHeader(context, displayName),
              const SizedBox(height: 16),
              _buildRevenueHighlight(revenue),
              if (myHostels.isEmpty) ...[
                const SizedBox(height: 16),
                _buildEmptyHostelsCard(context),
              ],
              const SizedBox(height: 20),
              const Text('Portfolio Snapshot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildStatCard('Total Hostels', myHostels.length.toString(), Icons.apartment, Colors.indigo),
                  _buildStatCard('Approved', approvedHostels.toString(), Icons.check_circle, Colors.green),
                  _buildStatCard('Pending Admin', pendingApproval.toString(), Icons.hourglass_top, Colors.orange),
                  if (rejectedHostels > 0)
                    _buildStatCard('Rejected', rejectedHostels.toString(), Icons.cancel, Colors.red),
                  _buildStatCard('Wardens Assigned', assignedWardens.toString(), Icons.security, Colors.purple),
                  _buildStatCard('Warden Requests', wardenRequests.length.toString(), Icons.inbox, Colors.blue),
                  if (pendingWardenReqs > 0)
                    _buildStatCard('Pending Requests', pendingWardenReqs.toString(), Icons.pending_actions, Colors.deepOrange),
                  _buildStatCard('Revenue (80%)', 'Rs. ${revenue.toInt()}', Icons.monetization_on, Colors.green),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildActionChip(
                    context,
                    state,
                    Icons.add_business,
                    'Add Hostel',
                    _hostelsTab,
                    onTap: () => Navigator.pushNamed(context, '/add-hostel'),
                  ),
                  _buildActionChip(context, state, Icons.apartment, 'My Hostels', _hostelsTab),
                  _buildActionChip(
                    context,
                    state,
                    Icons.inbox,
                    'Warden Requests',
                    _requestsTab,
                    badge: pendingWardenReqs,
                  ),
                  _buildActionChip(context, state, Icons.security, 'Wardens', _wardensTab, badge: wardens.length),
                  _buildActionChip(context, state, Icons.payments, 'Revenue', _revenueTab),
                ],
              ),
              if (myHostels.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Your Hostels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...myHostels.take(4).map((h) => _hostelSummaryTile(h)),
                if (myHostels.length > 4)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => state.jumpToDashboardTab(_hostelsTab),
                      child: Text('View all ${myHostels.length} hostels'),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              const Text('Recent Warden Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._buildRecentWardenRequests(state, wardenRequests),
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

  Widget _buildWelcomeHeader(BuildContext context, String name) {
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
          'Manage hostels, warden assignments, and revenue from one place.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildRevenueHighlight(double revenue) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.15),
            Colors.green.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.green, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Revenue (80%)', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'Rs. ${revenue.toInt()}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHostelsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No hostels yet. Add your first hostel and wait for admin approval. Wardens can then request assignment.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/add-hostel'),
            icon: const Icon(Icons.add),
            label: const Text('Add Hostel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
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

  Widget _hostelSummaryTile(Hostel hostel) {
    Color statusColor;
    String statusLabel;
    switch (hostel.approvalStatus) {
      case HostelApprovalStatus.pending:
        statusColor = Colors.orange;
        statusLabel = 'Pending Admin';
      case HostelApprovalStatus.rejected:
        statusColor = Colors.red;
        statusLabel = 'Rejected';
      case HostelApprovalStatus.approved:
        statusColor = hostel.isBooked ? Colors.green : Colors.blue;
        statusLabel = hostel.isBooked ? 'Booked' : 'Available';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.apartment, color: Color(0xFF6C63FF)),
        title: Text(hostel.hostelName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${hostel.location.isNotEmpty ? hostel.location : "No location"} · Rs.${hostel.rentPerMonth.toInt()}/mo',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRecentWardenRequests(AppState state, List<HostelRequest> requests) {
    final sorted = requests.toList()..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    if (sorted.isEmpty) {
      return [const Text('No warden requests yet.', style: TextStyle(color: Colors.grey))];
    }

    return sorted.take(5).map((r) {
      final status = state.effectiveWardenRequestStatus(r);
      final wardenName = state.wardenNameForRequest(r);
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.security, color: Color(0xFF6C63FF), size: 20),
          title: Text(wardenName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r.hostelName} — ${status.displayLabel}', style: const TextStyle(fontSize: 12)),
              Text(
                DateFormat('MMM dd, yyyy · hh:mm a').format(r.requestedAt),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _OwnerRevenueTab extends StatelessWidget {
  final double revenue;
  final int hostelCount;

  const _OwnerRevenueTab({required this.revenue, required this.hostelCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 48, color: Colors.green),
                  const SizedBox(height: 12),
                  const Text('Total Revenue (80%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'Rs.${revenue.toInt()}',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.apartment),
              title: const Text('Your Hostels'),
              trailing: Text('$hostelCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Revenue updates when wardens pay for assigned hostels.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmRemoveHostel(BuildContext context, AppState state, Hostel hostel) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove hostel?'),
      content: Text(
        'Delete "${hostel.hostelName}" permanently?\n\n'
        'This removes it from Admin, Warden, and Student views, including requests, reviews, and payments for this hostel.\n\n'
        'Not allowed if a warden is assigned or students are linked.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Remove', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  final err = await state.removeHostelByOwner(hostel.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(err ?? '${hostel.hostelName} removed.')),
  );
}

class _HostelsList extends StatelessWidget {
  final List<Hostel> hostels;
  final List<Student> wardens;
  final AppState state;

  const _HostelsList({
    required this.hostels,
    required this.wardens,
    required this.state,
  });

  String _personLabel(String? id, {String fallback = '—'}) {
    if (id == null || id.isEmpty) return fallback;
    final person = state.getStudentById(id);
    if (person != null && person.name.trim().isNotEmpty) return person.name.trim();
    return id.split('@').first;
  }

  String _wardenLabel(Hostel hostel) {
    if (hostel.assignedAdminId != null && hostel.assignedAdminId!.isNotEmpty) {
      final name = _personLabel(hostel.assignedAdminId);
      final type = hostel.assignedType?.trim();
      return type != null && type.isNotEmpty ? '$name ($type)' : name;
    }
    final pending = state.getPendingRequestsForHostel(hostel.id);
    if (pending.isNotEmpty) {
      return 'Pending: ${state.wardenNameForRequest(pending.first)}';
    }
    return 'Not assigned yet';
  }

  void _openUserProfile(BuildContext context, String? userId) {
    if (userId == null || userId.isEmpty) return;
    Navigator.pushNamed(context, '/user-details', arguments: userId);
  }

  @override
  Widget build(BuildContext context) {
    if (hostels.isEmpty) {
      return const Center(child: Text('No hostels submitted yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hostels.length + 1,
      itemBuilder: (context, index) {
        if (index == hostels.length) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              Text('Student Hostel Reviews', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              HostelReviewsList(maxItems: 20),
            ],
          );
        }
        final hostel = hostels[index];
        final wardenName = _wardenLabel(hostel);

        Color statusColor;
        String statusLabel;
        if (hostel.approvalStatus == HostelApprovalStatus.pending) {
          statusLabel = 'PENDING ADMIN';
          statusColor = Colors.orange;
        } else if (hostel.approvalStatus == HostelApprovalStatus.rejected) {
          statusLabel = 'REJECTED';
          statusColor = Colors.red;
        } else if (hostel.isBooked) {
          statusLabel = 'BOOKED';
          statusColor = Colors.green;
        } else {
          statusLabel = 'AVAILABLE';
          statusColor = Colors.blue;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hostel.hostelName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hostel.location.isNotEmpty ? hostel.location : 'Location not set',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _OwnerPersonRow(
                  icon: Icons.security_outlined,
                  label: 'Warden',
                  value: wardenName,
                  onTap: () {
                    if (hostel.assignedAdminId != null && hostel.assignedAdminId!.isNotEmpty) {
                      _openUserProfile(context, hostel.assignedAdminId);
                      return;
                    }
                    final pending = state.getPendingRequestsForHostel(hostel.id);
                    if (pending.isNotEmpty) {
                      _openUserProfile(context, pending.first.adminId);
                    }
                  },
                ),
                Text('Rent: Rs.${hostel.rentPerMonth.toInt()}/month'),
                if (hostel.rejectionReason != null)
                  Text('Rejection: ${hostel.rejectionReason}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _confirmRemoveHostel(context, state, hostel),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    label: const Text('Remove Hostel', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WardenRequestsList extends StatelessWidget {
  final List<HostelRequest> requests;
  final AppState state;

  const _WardenRequestsList({required this.requests, required this.state});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Text('No warden requests yet.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        Color statusColor;
        final status = state.effectiveWardenRequestStatus(request);
        switch (status) {
          case HostelRequestStatus.booked:
            statusColor = Colors.green;
          case HostelRequestStatus.rejected:
            statusColor = Colors.red;
          case HostelRequestStatus.pending:
            statusColor = Colors.orange;
        }

        final wardenName = state.wardenNameForRequest(request);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.pushNamed(context, '/user-details', arguments: request.adminId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(wardenName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        ),
                        Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Hostel: ${request.hostelName}'),
                if (request.location.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(child: Text(request.location, style: const TextStyle(color: Colors.grey))),
                    ],
                  ),
                Text('Type: ${request.hostelType}'),
                const SizedBox(height: 8),
                Text(
                  'Status: ${status.displayLabel}',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Admin approval required — you can only view status here.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WardensTab extends StatelessWidget {
  final String ownerId;
  final List<Hostel> hostels;

  const _WardensTab({required this.ownerId, required this.hostels});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final wardens = state.getWardensForOwner(ownerId);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Wardens on your hostels',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Wardens sign up with @warden.com and request assignment from admin. '
              'Each warden manages one hostel at a time (same gender as their profile).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (wardens.isEmpty)
              const Text(
                'No wardens assigned to your hostels yet.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...wardens.map((warden) {
                Hostel? hostel;
                for (final h in hostels) {
                  if (h.assignedAdminId == warden.studentId) {
                    hostel = h;
                    break;
                  }
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.security)),
                    title: Text(warden.name.isNotEmpty ? warden.name : warden.email),
                    subtitle: Text(
                      '${hostel != null ? "${warden.email} · ${hostel.hostelName}" : "${warden.email} · not assigned yet"}'
                      '${warden.gender.isNotEmpty ? "\nGender: ${warden.gender}" : ""}'
                      '${hostel != null && hostel.assignedType != null ? "\nType: ${hostel.assignedType}" : ""}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, '/user-details', arguments: warden.studentId),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _OwnerPersonRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _OwnerPersonRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: onTap != null ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ),
        if (onTap != null) Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.primary),
      ],
    );

    if (onTap == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 4), child: content);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: content,
        ),
      ),
    );
  }
}
