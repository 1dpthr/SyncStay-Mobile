import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/hostel.dart';
import '../../models/student.dart';
import 'widgets/role_bottom_nav_scaffold.dart';
import 'widgets/hostel_reviews_list.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  static const _navItems = [
    RoleNavItem(label: 'Users', icon: Icons.people),
    RoleNavItem(label: 'Hostels', icon: Icons.apartment),
    RoleNavItem(label: 'Wardens', icon: Icons.security),
    RoleNavItem(label: 'Logs', icon: Icons.history),
  ];

  @override
  Widget build(BuildContext context) {
    return RoleBottomNavScaffold(
      title: 'Platform Admin',
      items: _navItems,
      pages: const [
        _AllUsersTab(),
        _HostelSubmissionsTab(),
        _WardenRequestsTab(),
        _StudentLogsTab(),
      ],
    );
  }
}

class _AllUsersTab extends StatelessWidget {
  const _AllUsersTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final owners = state.getAllOwners();
        final others = state.allStudents
            .where((s) => s.role != UserRole.owner)
            .toList()
          ..sort((a, b) => a.role.name.compareTo(b.role.name));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Owners (self-registered)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Owners sign up with @owner.com — no admin creation needed.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (owners.isEmpty)
              const Text('No owners yet.', style: TextStyle(color: Colors.grey))
            else
              ...owners.map(
                (o) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.business)),
                    title: Text(o.name.isNotEmpty ? o.name : o.email),
                    subtitle: Text(
                      '${o.email} · ${state.getWardensAssignedToOwner(o.studentId).length} warden(s) on hostels',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, '/user-details', arguments: o.studentId),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text('All other users', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...others.map(
              (user) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(user.name.isNotEmpty ? user.name : user.email),
                  subtitle: Text('${user.email} · ${state.roleDisplayLabel(user.role)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/user-details', arguments: user.studentId),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HostelSubmissionsTab extends StatelessWidget {
  const _HostelSubmissionsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final pending = state.getPendingOwnerHostelSubmissions();
        final approved = state.hostels
            .where((h) => h.approvalStatus == HostelApprovalStatus.approved)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (pending.isEmpty && approved.isEmpty) {
          return const Center(child: Text('No hostel submissions yet.'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pending.isNotEmpty) ...[
              const Text('Pending approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ...pending.map((h) => _HostelSubmissionCard(hostel: h, showActions: true)),
              const SizedBox(height: 24),
            ],
            const Text('Approved hostels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (approved.isEmpty)
              const Text('No approved hostels yet.', style: TextStyle(color: Colors.grey))
            else
              ...approved.map((h) => _HostelSubmissionCard(hostel: h, showActions: false)),
            const SizedBox(height: 16),
            const Text('Student Hostel Reviews', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const HostelReviewsList(maxItems: 20),
          ],
        );
      },
    );
  }
}

class _HostelSubmissionCard extends StatelessWidget {
  final Hostel hostel;
  final bool showActions;

  const _HostelSubmissionCard({required this.hostel, required this.showActions});

  Future<void> _transferOwner(BuildContext context) async {
    final state = Provider.of<AppState>(context, listen: false);
    final owners = state.getAvailableOwnersForTransfer(excludeOwnerId: hostel.createdByOwner);
    if (owners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other owners available for transfer')),
      );
      return;
    }

    String? selectedId = owners.first.studentId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Transfer hostel to owner'),
          content: DropdownButtonFormField<String>(
            value: selectedId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'New owner'),
            items: owners
                .map(
                  (o) => DropdownMenuItem(
                    value: o.studentId,
                    child: Text(o.name.isNotEmpty ? o.name : o.email, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => selectedId = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Transfer')),
          ],
        ),
      ),
    );
    if (ok != true || selectedId == null || !context.mounted) return;

    final err = state.transferHostelToOwner(hostel.id, selectedId!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Hostel transferred successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final owner = state.getStudentById(hostel.createdByOwner);
        final ownerLabel = owner != null && owner.name.trim().isNotEmpty ? owner.name.trim() : hostel.createdByOwner;

        Color statusColor;
        switch (hostel.approvalStatus) {
          case HostelApprovalStatus.pending:
            statusColor = Colors.orange;
          case HostelApprovalStatus.approved:
            statusColor = Colors.green;
          case HostelApprovalStatus.rejected:
            statusColor = Colors.red;
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
                      child: Text(hostel.hostelName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                    Chip(
                      label: Text(hostel.approvalStatus.displayLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Owner: $ownerLabel'),
                if (hostel.location.isNotEmpty) Text('Location: ${hostel.location}'),
                Text('Rent: Rs.${hostel.rentPerMonth.toInt()}/month · ${hostel.availabilityLabel}'),
                if (hostel.rejectionReason != null) ...[
                  const SizedBox(height: 8),
                  Text('Reason: ${hostel.rejectionReason}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                if (!showActions) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _transferOwner(context),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Transfer Owner'),
                    ),
                  ),
                ],
                if (showActions) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final reasonCtrl = TextEditingController();
                            final reject = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Reject hostel?'),
                                content: TextField(
                                  controller: reasonCtrl,
                                  decoration: const InputDecoration(hintText: 'Reason (optional)'),
                                  maxLines: 2,
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Reject', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (reject != true || !context.mounted) return;
                            final ok = await state.rejectOwnerHostelSubmission(hostel.id, reason: reasonCtrl.text.trim());
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'Hostel rejected' : 'Could not reject hostel')),
                            );
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final ok = await state.approveOwnerHostelSubmission(hostel.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'Hostel approved' : 'Could not approve hostel')),
                            );
                          },
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WardenRequestsTab extends StatelessWidget {
  const _WardenRequestsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final requests = state.getPendingWardenAssignmentRequests();
        if (requests.isEmpty) {
          return const Center(
            child: Text(
              'No pending warden assignment requests.\nWardens sign up with @warden.com and request hostels themselves.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final warden = state.getStudentById(request.adminId);
            final wardenName = state.wardenNameForRequest(request);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/user-details', arguments: request.adminId),
                      child: Text(wardenName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                    Text('${request.hostelName} · ${request.hostelType}'),
                    if (request.location.isNotEmpty) Text(request.location, style: const TextStyle(color: Colors.grey)),
                    if (warden != null && warden.gender.isNotEmpty)
                      Text('Warden gender: ${warden.gender}', style: const TextStyle(fontSize: 12)),
                    if (request.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Note: ${request.description}', style: const TextStyle(fontSize: 13)),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final noteCtrl = TextEditingController();
                              final reject = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Reject request?'),
                                  content: TextField(
                                    controller: noteCtrl,
                                    decoration: const InputDecoration(hintText: 'Message (optional)'),
                                    maxLines: 2,
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Reject', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (reject != true || !context.mounted) return;
                              state.rejectWardenAssignmentRequest(request.id, message: noteCtrl.text.trim());
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Request rejected')),
                              );
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final ok = await state.approveWardenAssignmentRequest(request.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Warden assigned — they must pay to activate'
                                        : 'Could not approve (gender mismatch, hostel booked, or warden already has a hostel)',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
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

class _StudentLogsTab extends StatelessWidget {
  const _StudentLogsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final logs = state.getStudentActivityLogsForAdmin();
        if (logs.isEmpty) {
          return const Center(child: Text('No student activity logs yet.', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(log.title),
                subtitle: Text('${log.detail}\n${DateFormat('MMM dd, yyyy · HH:mm').format(log.time)}'),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
