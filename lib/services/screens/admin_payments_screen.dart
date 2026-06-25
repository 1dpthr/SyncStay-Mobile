import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'widgets/syncstay_app_bar.dart';
import 'widgets/payment_history_list.dart';
import '../../models/student.dart';

class AdminPaymentsScreen extends StatefulWidget {
  final String? initialFilter;
  const AdminPaymentsScreen({super.key, this.initialFilter});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final isWarden = state.currentUser?.role == UserRole.warden;
        final wardenId = state.currentUser?.studentId ?? '';
        final assignedHostel = isWarden ? state.getAssignedHostelForAdmin(wardenId) : null;
        final payments = state.getPaymentsVisibleToCurrentUser();

        return Scaffold(
          appBar: syncStayAppBar(
            context,
            screenTitle: isWarden ? 'Payment History' : 'Payment Management',
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isWarden) ...[
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.apartment, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              assignedHostel != null
                                  ? '${assignedHostel.hostelName}: member payments + your hostel fees. Each row shows month, paid/pending status, amount & method.'
                                  : 'No hostel assigned yet.',
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                PaymentHistoryList(
                  payments: payments,
                  showUserName: isWarden || state.currentUser?.role == UserRole.admin,
                  allowAdminVerify: state.currentUser?.role == UserRole.admin,
                  emptyMessage: isWarden
                      ? (assignedHostel == null
                          ? 'Assign a hostel first to see payments.'
                          : 'No payment records yet.')
                      : 'No payments recorded.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
