import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/payment.dart';
import '../../../models/room.dart';
import '../../../models/student.dart';
import '../../../utils/payment_months.dart';
import '../../app_state.dart';

/// Full payment history with month, paid/pending status, and filters.
class PaymentHistoryList extends StatefulWidget {
  final List<Payment> payments;
  final bool showUserName;
  final bool allowAdminVerify;
  final String emptyMessage;
  final VoidCallback? onPayNow;

  const PaymentHistoryList({
    super.key,
    required this.payments,
    this.showUserName = false,
    this.allowAdminVerify = false,
    this.emptyMessage = 'No payments recorded yet.',
    this.onPayNow,
  });

  @override
  State<PaymentHistoryList> createState() => _PaymentHistoryListState();
}

class _PaymentHistoryListState extends State<PaymentHistoryList> {
  String _filter = 'All';

  List<Payment> get _filtered {
    return widget.payments.where((p) {
      if (_filter == 'Pending') return !p.isSettled && p.status != PaymentStatus.failed;
      if (_filter == 'Paid') return p.isSettled;
      if (_filter == 'Failed') return p.status == PaymentStatus.failed;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final counts = state.paymentHistoryCounts(widget.payments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryStrip(counts: counts),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'All', label: Text('All')),
            ButtonSegment(value: 'Paid', label: Text('Paid')),
            ButtonSegment(value: 'Pending', label: Text('Pending')),
            ButtonSegment(value: 'Failed', label: Text('Failed')),
          ],
          selected: {_filter},
          onSelectionChanged: (v) => setState(() => _filter = v.first),
        ),
        const SizedBox(height: 12),
        if (_filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                widget.payments.isEmpty ? widget.emptyMessage : 'No $_filter payments.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final payment = _filtered[index];
              return _PaymentHistoryCard(
                payment: payment,
                showUserName: widget.showUserName,
                allowAdminVerify: widget.allowAdminVerify,
              );
            },
          ),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final ({int paid, int pending, int failed, int total}) counts;

  const _SummaryStrip({required this.counts});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(context, '${counts.total} Total', Colors.blueGrey),
        _chip(context, '${counts.paid} Paid', Colors.green),
        _chip(context, '${counts.pending} Pending', Colors.orange),
        if (counts.failed > 0) _chip(context, '${counts.failed} Failed', Colors.red),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  final Payment payment;
  final bool showUserName;
  final bool allowAdminVerify;

  const _PaymentHistoryCard({
    required this.payment,
    required this.showUserName,
    required this.allowAdminVerify,
  });

  Color _statusColor(PaymentStatus status) {
    if (status.isSettled) return Colors.green;
    if (status == PaymentStatus.failed) return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(payment.status);

    Student? payer;
    if (showUserName) {
      payer = state.getStudentById(payment.userId);
    }

    final month = payment.paymentMonth?.trim().isNotEmpty == true
        ? payment.paymentMonth!
        : 'Month not set';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(
                    payment.isSettled ? Icons.check_circle : Icons.schedule,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        month,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (showUserName)
                        Text(
                          payer?.name.isNotEmpty == true ? payer!.name : payment.userId,
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      Text(
                        payment.kindLabel,
                        style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    payment.statusLabel.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  backgroundColor: statusColor,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _detailRow(Icons.payments_outlined, 'Amount', 'Rs. ${payment.amount.toInt()}'),
            if (payment.roomId.isNotEmpty)
              _detailRow(Icons.meeting_room_outlined, 'Room', payment.roomId),
            if (payment.hostelId != null && payment.hostelId!.isNotEmpty)
              _detailRow(
                Icons.apartment_outlined,
                'Hostel',
                state.getHostelNameById(payment.hostelId) ?? payment.hostelId!,
              ),
            _detailRow(Icons.credit_card_outlined, 'Method', payment.paymentMethod),
            if (payment.cardLast4Digits != null)
              _detailRow(Icons.lock_outline, 'Card', '**** ${payment.cardLast4Digits}'),
            _detailRow(
              Icons.calendar_today_outlined,
              'Paid on',
              DateFormat('dd MMM yyyy · hh:mm a').format(payment.timestamp),
            ),
            if (allowAdminVerify && payment.status == PaymentStatus.pending) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    state.verifyPayment(payment.paymentId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment marked as paid')),
                    );
                  },
                  child: const Text('Verify Payment'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey),
          const SizedBox(width: 6),
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Student outstanding payment hint when room accepted but not paid.
class StudentOutstandingPaymentCard extends StatelessWidget {
  final VoidCallback? onPayNow;

  const StudentOutstandingPaymentCard({super.key, this.onPayNow});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final user = state.currentUser;
    if (user == null) return const SizedBox.shrink();
    if (user.assignedRoomId == null) return const SizedBox.shrink();
    if (user.assignmentStatus != AssignmentStatus.accepted &&
        user.assignmentStatus != AssignmentStatus.confirmed) {
      return const SizedBox.shrink();
    }

    final currentMonth = currentPaymentMonthLabel();
    if (state.studentHasPaidForMonth(user.studentId, currentMonth, roomId: user.assignedRoomId)) {
      return const SizedBox.shrink();
    }

    Room? room;
    try {
      room = state.allRooms.firstWhere((r) => r.roomId == user.assignedRoomId);
    } catch (_) {
      room = null;
    }
    final amount = room?.calculateTotalPrice() ?? 0.0;
    final month = currentPaymentMonthLabel();

    return Card(
      color: Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$month — Pending',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const Chip(
                  label: Text('PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  backgroundColor: Colors.orange,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Room rent: Rs. ${amount.toInt()} · not paid yet', style: const TextStyle(fontSize: 13)),
            if (onPayNow != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: onPayNow, child: const Text('Pay Now')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
