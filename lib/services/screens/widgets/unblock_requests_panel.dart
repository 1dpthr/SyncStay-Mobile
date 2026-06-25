import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/student.dart';
import '../../../models/unblock_request.dart';
import '../../app_state.dart';

/// Lists unblock requests the current user may review (approve/reject if allowed).
class UnblockRequestsPanel extends StatelessWidget {
  final String emptyMessage;
  final bool pendingOnly;

  const UnblockRequestsPanel({
    super.key,
    this.emptyMessage = 'No unblock requests yet.',
    this.pendingOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        var requests = state.getUnblockRequestsForCurrentApprover();
        if (pendingOnly) {
          requests = requests.where((r) => r.status == UnblockRequestStatus.pending).toList();
        }

        if (requests.isEmpty) {
          return Center(child: Text(emptyMessage, style: const TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) => _UnblockRequestCard(request: requests[index]),
        );
      },
    );
  }
}

class _UnblockRequestCard extends StatelessWidget {
  final UnblockRequest request;

  const _UnblockRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final target = state.getStudentById(request.studentId);
        final canAct = state.canApproveUnblockRequest(request.id);

        Color statusColor;
        switch (request.status) {
          case UnblockRequestStatus.approved:
            statusColor = Colors.green;
          case UnblockRequestStatus.rejected:
            statusColor = Colors.red;
          case UnblockRequestStatus.pending:
            statusColor = Colors.orange;
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
                        request.studentName.isNotEmpty ? request.studentName : request.studentId,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Chip(
                      label: Text(request.status.displayLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      backgroundColor: statusColor.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                Text(
                  '${_roleLabel(request.targetRole)} · ${DateFormat('MMM dd, yyyy').format(request.requestedAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (target?.blockReason != null)
                  Text('Block reason: ${target!.blockReason}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                const SizedBox(height: 8),
                Text(request.message, style: const TextStyle(fontSize: 13)),
                if (request.adminNote != null && request.adminNote!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Note: ${request.adminNote}', style: TextStyle(fontSize: 12, color: statusColor)),
                  ),
                if (request.status == UnblockRequestStatus.pending && canAct) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _reject(context, state, request.id),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final ok = await state.approveUnblockRequest(request.id);
                            if (!context.mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${request.studentName} unblocked')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not unblock — check internet and try again')),
                              );
                            }
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

  void _reject(BuildContext context, AppState state, String requestId) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject unblock request?'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(hintText: 'Optional note'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              state.rejectUnblockRequest(requestId, adminNote: noteController.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Student';
      case UserRole.warden:
        return 'Warden';
      case UserRole.owner:
        return 'Owner';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
