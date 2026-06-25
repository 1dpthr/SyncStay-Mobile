import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/hostel.dart';
import '../../models/hostel_request.dart';
import '../../models/student.dart';
import 'widgets/syncstay_app_bar.dart';

class DistrictAdminDashboard extends StatelessWidget {
  const DistrictAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: syncStayAppBar(
        context,
        screenTitle: 'District Admin Dashboard',
        role: UserRole.admin,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AppState>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, child) {
          final assignedHostels = state.getAdminAssignedHostels(state.currentUser?.studentId ?? '');
          final requests = state.getAdminRequests(state.currentUser?.studentId ?? '');

          return DefaultTabController(
            length: 5,
            child: Column(
              children: [
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'My Hostels'),
                    Tab(text: 'Requests'),
                    Tab(text: 'Matches'),
                    Tab(text: 'Assignments'),
                    Tab(text: 'Payments'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _MyHostelsTab(hostels: assignedHostels),
                      _RequestsTab(requests: requests),
                      const Center(child: Text('Roommate Matching Requests')),
                      const Center(child: Text('Room Assignments')),
                      const Center(child: Text('Payment Status')),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MyHostelsTab extends StatelessWidget {
  final List<Hostel> hostels;
  const _MyHostelsTab({required this.hostels});

  @override
  Widget build(BuildContext context) {
    if (hostels.isEmpty) {
      return const Center(child: Text('No hostels assigned to you yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hostels.length,
      itemBuilder: (context, index) {
        final hostel = hostels[index];
        return Card(
          child: ListTile(
            title: Text(hostel.hostelName),
            subtitle: Text('Floors: ${hostel.totalFloors} | Rooms: ${hostel.totalRooms}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to hostel floor overview
            },
          ),
        );
      },
    );
  }
}

class _RequestsTab extends StatelessWidget {
  final List<HostelRequest> requests;
  const _RequestsTab({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(child: Text('No pending requests.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return Card(
          child: ListTile(
            title: Text(request.studentName),
            subtitle: Text('Requested: ${request.hostelName}'),
            onTap: request.studentId.isNotEmpty
                ? () => Navigator.pushNamed(context, '/user-details', arguments: request.studentId)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () {
                    // Approve logic
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    // Reject logic
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
