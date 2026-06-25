import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/payment.dart';
import '../../models/hostel_request.dart';
import 'package:intl/intl.dart';
import 'widgets/syncstay_app_bar.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final adminId = state.currentUser?.studentId ?? '';
        final assignedHostel = state.getAssignedHostelForAdmin(adminId);
        final myHostelRequests = state.getRequestsByAdmin(adminId);

        if (assignedHostel == null) {
          return _buildPreAssignmentView(context, state, myHostelRequests);
        }

        final rooms = state.getRoomsForAdminHostel(adminId);
        final totalRooms = rooms.length;
        final occupiedRooms = rooms.where((r) => r.currentOccupancy > 0).length;
        final occupancyRate = totalRooms > 0 ? (occupiedRooms / totalRooms * 100).toStringAsFixed(1) : '0';
        final totalRevenue = state.getRevenueForAdminHostel(adminId);
        final activeUsers = state.getActiveStudentCountForAdmin(adminId);
        final pendingStudentReqs = state.getStudentHostelRequestsForAdmin(adminId)
            .where((r) => r.status == HostelRequestStatus.pending)
            .length;

        return Scaffold(
          appBar: syncStayAppBar(context, screenTitle: 'Hostel Analytics'),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHostelHeader(assignedHostel.hostelName, assignedHostel.location, assignedHostel.assignedType),
                const SizedBox(height: 20),
                _buildSectionTitle('Overview'),
                const SizedBox(height: 16),
                _buildAnalyticsCard(
                  'Total Revenue',
                  'Rs. ${totalRevenue.toInt()}',
                  Icons.monetization_on,
                  Colors.green,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsCard(
                        'Occupancy',
                        '$occupancyRate%',
                        Icons.pie_chart,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAnalyticsCard(
                        'Active Users',
                        activeUsers.toString(),
                        Icons.trending_up,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAnalyticsCard(
                  'Pending Student Requests',
                  pendingStudentReqs.toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('Room Distribution'),
                const SizedBox(height: 16),
                _buildDistributionBar('Standard', rooms.where((r) => r.roomType == 'standard').length, totalRooms, Colors.orange),
                _buildDistributionBar('Deluxe', rooms.where((r) => r.roomType == 'deluxe').length, totalRooms, Colors.indigo),
                _buildDistributionBar('Suite', rooms.where((r) => r.roomType == 'suite').length, totalRooms, Colors.teal),
                const SizedBox(height: 32),
                _buildSectionTitle('Recent Activity'),
                const SizedBox(height: 16),
                ..._buildHostelActivity(state, adminId, assignedHostel.id),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreAssignmentView(BuildContext context, AppState state, List<HostelRequest> myRequests) {
    final pending = myRequests.where((r) => r.status == HostelRequestStatus.pending).length;
    final booked = myRequests.where((r) => r.status == HostelRequestStatus.booked).length;
    final rejected = myRequests.where((r) => r.status == HostelRequestStatus.rejected).length;

    return Scaffold(
      appBar: syncStayAppBar(context, screenTitle: 'System Analytics'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'No hostel assigned yet. Below is your request status with the Owner. After approval, live hostel analytics will appear here.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Your Requests to Owner'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildAnalyticsCard('Pending', pending.toString(), Icons.hourglass_top, Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: _buildAnalyticsCard('Booked', booked.toString(), Icons.check_circle, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _buildAnalyticsCard('Rejected', rejected.toString(), Icons.cancel, Colors.red)),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Recent Activity'),
            const SizedBox(height: 16),
            if (myRequests.isEmpty)
              const Text('No hostel requests sent yet.', style: TextStyle(color: Colors.grey))
            else
              ...myRequests.take(8).map((r) => _activityTile(
                    r.hostelName,
                    '${r.location.isNotEmpty ? "${r.location} · " : ""}${r.hostelType} — ${r.status.displayLabel}',
                    r.requestedAt,
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildHostelHeader(String name, String location, String? type) {
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

  List<Widget> _buildHostelActivity(AppState state, String adminId, String hostelId) {
    final items = <_ActivityItem>[];

    for (final r in state.getStudentHostelRequestsForAdmin(adminId)) {
      items.add(_ActivityItem(
        title: 'Student Hostel Request',
        message: '${r.studentName.isNotEmpty ? r.studentName : r.studentId} requested ${r.hostelName}',
        time: r.requestedAt,
      ));
    }

    for (final r in state.getRequestsByAdmin(adminId)) {
      items.add(_ActivityItem(
        title: 'Your Owner Request',
        message: '${r.hostelName} (${r.hostelType}) — ${r.status.displayLabel}',
        time: r.requestedAt,
      ));
    }

    for (final p in state.getStudentPaymentsForAdminHostel(adminId).where((pay) =>
        pay.status == PaymentStatus.paid || pay.status == PaymentStatus.confirmed)) {
      try {
        final student = state.allStudents.firstWhere((s) => s.studentId == p.userId);
        items.add(_ActivityItem(
          title: 'Payment Received',
          message: '${student.name} paid Rs. ${p.amount.toInt()} for ${p.roomId}',
          time: p.timestamp,
        ));
      } catch (_) {
        items.add(_ActivityItem(
          title: 'Payment Received',
          message: 'Rs. ${p.amount.toInt()} for ${p.roomId}',
          time: p.timestamp,
        ));
      }
    }

    items.sort((a, b) => b.time.compareTo(a.time));

    if (items.isEmpty) {
      return [const Text('No recent activity for your hostel.', style: TextStyle(color: Colors.grey))];
    }

    return items.take(8).map((i) => _activityTile(i.title, i.message, i.time)).toList();
  }

  Widget _activityTile(String title, String message, DateTime time) {
    return ListTile(
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
      dense: true,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  }

  Widget _buildAnalyticsCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(String label, int count, int total, Color color) {
    double percentage = total > 0 ? count / total : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('$count rooms'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(10),
            minHeight: 10,
          ),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final String title;
  final String message;
  final DateTime time;
  _ActivityItem({required this.title, required this.message, required this.time});
}
