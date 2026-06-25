import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/notification.dart';
import 'package:intl/intl.dart';
import 'widgets/syncstay_app_bar.dart';

class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: syncStayAppBar(
        context,
        screenTitle: 'System Notifications',
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all read',
            onPressed: () => Provider.of<AppState>(context, listen: false).markAllNotificationsRead(),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final notifications = state.getNotificationsForCurrentUser();

          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No system notifications yet.\nActivity from users, hostels, payments, and blocks will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: notif.isRead ? null : Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                child: ListTile(
                  leading: _notifIcon(notif.type),
                  title: Text(notif.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(notif.message),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy · hh:mm a').format(notif.timestamp),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      if (notif.targetUserId != null)
                        Text('For: ${notif.targetUserId}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  onTap: () => state.markNotificationRead(notif.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Icon _notifIcon(NotificationType type) {
    switch (type) {
      case NotificationType.paymentConfirmed:
        return const Icon(Icons.payment, color: Colors.green);
      case NotificationType.roomAssigned:
        return const Icon(Icons.meeting_room, color: Colors.blue);
      case NotificationType.roommateMatched:
        return const Icon(Icons.favorite, color: Colors.pink);
      case NotificationType.requestReceived:
        return const Icon(Icons.mail, color: Colors.orange);
      case NotificationType.info:
        return const Icon(Icons.info_outline, color: Colors.amber);
    }
  }
}

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _filter = 'All';

  static const _categories = ['All', 'Alert', 'Hostel', 'Student', 'Payment', 'Account'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: syncStayAppBar(context, screenTitle: 'Reports & Logs'),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          var logs = state.getActivityLogsVisibleToCurrentUser();
          if (_filter != 'All') {
            logs = logs.where((l) => l.category == _filter).toList();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: _categories.map((cat) {
                    final selected = _filter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (_) => setState(() => _filter = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Text(
                          _filter == 'All' ? 'No activity logs yet.' : 'No $_filter logs.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                child: Text(log.category[0], style: const TextStyle(fontSize: 12)),
                              ),
                              title: Text(log.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(log.detail),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy · hh:mm a').format(log.time),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(log.category, style: const TextStyle(fontSize: 10)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
