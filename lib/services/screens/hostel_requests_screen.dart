import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/hostel_request.dart';
import 'widgets/syncstay_app_bar.dart';
import 'package:intl/intl.dart';

class HostelRequestsScreen extends StatelessWidget {
  const HostelRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final wardenId = state.currentUser?.studentId ?? '';
        final myRequests = state.getRequestsByAdmin(wardenId);
        final canRequest = state.wardenCanRequestHostelAssignment(wardenId);

        return Scaffold(
          appBar: syncStayAppBar(context, screenTitle: 'My Hostel Requests'),
          body: myRequests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No requests found', style: TextStyle(color: Colors.grey, fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: myRequests.length,
                  itemBuilder: (context, index) => _buildRequestCard(context, myRequests[index]),
                ),
          floatingActionButton: canRequest
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.pushNamed(context, '/hostel-request-form'),
                  label: const Text('New Request'),
                  icon: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, HostelRequest request) {
    final state = Provider.of<AppState>(context, listen: false);
    final status = state.effectiveWardenRequestStatus(request);
    Color statusColor;
    IconData statusIcon;
    final statusText = status.displayLabel;

    switch (status) {
      case HostelRequestStatus.booked:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case HostelRequestStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case HostelRequestStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    request.hostelName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Location: ${request.location}', style: const TextStyle(color: Colors.grey)),
            Text('Your requested type: ${request.hostelType}', style: const TextStyle(color: Colors.grey)),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(request.requestedAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (request.description.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Note:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(request.description, style: const TextStyle(fontSize: 14)),
            ],
            if (status == HostelRequestStatus.rejected &&
                request.ownerMessage != null &&
                request.ownerMessage!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Owner Message:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(request.ownerMessage!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
            if (status == HostelRequestStatus.booked) ...[
              const SizedBox(height: 16),
              const Text(
                'This hostel is booked for you with your requested type. You can manage it from District Hostels.',
                style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
