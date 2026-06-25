import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../../../models/student.dart';
import 'widgets/syncstay_app_bar.dart';
import 'widgets/payment_history_list.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final role = state.currentUser?.role;
        final payments = state.getPaymentHistoryForCurrentUser();
        final isWarden = role == UserRole.warden;
        final isAdmin = role == UserRole.admin;
        final isStudent = role == UserRole.student;

        String title = 'Payment History';
        if (isWarden) title = 'Payment History';
        if (isAdmin) title = 'All Payments';
        if (isStudent) title = 'My Payment History';

        return Scaffold(
          appBar: syncStayAppBar(context, screenTitle: title),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isStudent) ...[
                  StudentOutstandingPaymentCard(
                    onPayNow: () => Navigator.pushNamed(context, '/payment'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (isWarden) ...[
                  _infoBanner(
                    context,
                    'Member room payments and your own hostel fee payments are listed below with month and status.',
                  ),
                  const SizedBox(height: 12),
                ],
                PaymentHistoryList(
                  payments: payments,
                  showUserName: isWarden || isAdmin,
                  allowAdminVerify: isAdmin,
                  emptyMessage: isStudent
                      ? 'No payments yet. Pay rent from Payment Status after accepting your room.'
                      : 'No payment records yet.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoBanner(BuildContext context, String text) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
          ],
        ),
      ),
    );
  }
}
