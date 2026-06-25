import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../../models/unblock_request.dart';
import '../../models/student.dart';
import 'widgets/syncstay_app_bar.dart';

class BlockedAccountScreen extends StatefulWidget {
  const BlockedAccountScreen({super.key});

  @override
  State<BlockedAccountScreen> createState() => _BlockedAccountScreenState();
}

class _BlockedAccountScreenState extends State<BlockedAccountScreen> {
  final _messageController = TextEditingController();
  bool _wasBlocked = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshStatus());
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshStatus());
  }

  Future<void> _refreshStatus() async {
    if (!mounted) return;
    final state = Provider.of<AppState>(context, listen: false);
    await state.refreshCurrentUserFromRemote();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final user = state.currentUser;
        if (user == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!user.isAccountBlocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_wasBlocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account unblocked — welcome back!')),
              );
              _wasBlocked = false;
            }
            _goHome(context, user);
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        _wasBlocked = true;

        final approverLabel = state.unblockApproverLabelForRole(user.role, target: user);
        final unblockReq = state.getUnblockRequestForStudent(user.studentId);
        final hasPending = state.hasPendingUnblockRequest(user.studentId);
        final canSubmit = state.canSubmitUnblockRequest(user.studentId);

        return Scaffold(
          appBar: syncStayAppBar(
            context,
            screenTitle: 'Account Blocked',
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  state.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.block, size: 72, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Your account is blocked',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                if (user.blockReason != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Reason: ${user.blockReason}',
                      style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                if (user.lastLeftRoomId != null) ...[
                  const SizedBox(height: 8),
                  Text('Last room: ${user.lastLeftRoomId}', style: const TextStyle(color: Colors.grey)),
                ],
                const SizedBox(height: 24),
                Text(
                  'Unblock request ($approverLabel)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                if (unblockReq == null)
                  Text(
                    'Send a request to $approverLabel to restore your account.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  )
                else
                  _buildRequestStatusCard(unblockReq),
                const SizedBox(height: 24),
                if (canSubmit) ...[
                  TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Message to $approverLabel',
                      hintText: 'Why should your account be unblocked?',
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_messageController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a message')),
                        );
                        return;
                      }
                      final err = await state.submitUnblockRequest(_messageController.text);
                      if (!mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      } else {
                        _messageController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Unblock request sent to $approverLabel')),
                        );
                      }
                    },
                    child: Text('Request Unblock from $approverLabel'),
                  ),
                ],
                if (hasPending)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Your request is pending. $approverLabel will approve or reject it.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _goHome(BuildContext context, Student user) {
    switch (user.role) {
      case UserRole.admin:
        Navigator.pushReplacementNamed(context, '/admin');
      case UserRole.warden:
        Navigator.pushReplacementNamed(context, '/warden-dashboard');
      case UserRole.owner:
        Navigator.pushReplacementNamed(context, '/owner-dashboard');
      case UserRole.student:
        Navigator.pushReplacementNamed(
          context,
          user.profileCompleted ? '/dashboard' : '/profile',
        );
    }
  }

  Widget _buildRequestStatusCard(UnblockRequest req) {
    Color color;
    switch (req.status) {
      case UnblockRequestStatus.approved:
        color = Colors.green;
      case UnblockRequestStatus.rejected:
        color = Colors.red;
      case UnblockRequestStatus.pending:
        color = Colors.orange;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(req.status.displayLabel, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(DateFormat('MMM dd, yyyy').format(req.requestedAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Your message: ${req.message}'),
            if (req.adminNote != null && req.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: ${req.adminNote}', style: TextStyle(color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
