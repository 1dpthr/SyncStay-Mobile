import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'widgets/syncstay_app_bar.dart';
import '../../models/room.dart';
import '../../models/roommate_request.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Room? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final matches = state.allRequests.where((r) => 
          r.type == RequestType.roommate && 
          r.status == RequestStatus.accepted && 
          r.adminStatus == AdminStatus.pending
        ).toList();

        final roomRequests = state.allStudents.where((s) => s.requestedRoomId != null && s.assignedRoomId == null).toList();

        final availableRooms = state.allRooms.where((r) => !r.isFull()).toList();

        return Scaffold(
          appBar: syncStayAppBar(
            context,
            screenTitle: 'Admin Requests',
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Match Requests'),
                Tab(text: 'Room Requests'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Match Requests Tab
              matches.isEmpty
                  ? const Center(child: Text('No matches pending review.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        final suitableRooms = state.allRooms.where((r) => r.capacity - r.currentOccupancy >= 2).toList();
                        
                        final studentA = state.allStudents.firstWhere((s) => s.studentId == match.senderId);
                        final studentB = state.allStudents.firstWhere((s) => s.studentId == match.receiverId);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          CircleAvatar(child: Text(match.senderName.isNotEmpty ? match.senderName[0] : 'U')),
                                          const SizedBox(height: 4),
                                          Text(match.senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.compare_arrows, size: 32, color: Color(0xFF6C63FF)),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          CircleAvatar(child: Text(match.receiverName.isNotEmpty ? match.receiverName[0] : 'U')),
                                          const SizedBox(height: 4),
                                          Text(match.receiverName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1), 
                                      borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: Text('Compatibility: ${match.compatibilityScore}%', 
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  ),
                                ),
                                const Divider(height: 32),
                                const Text('Assign a Room', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<Room>(
                                  isExpanded: true,
                                  hint: const Text('Select a Room with 2+ capacity'),
                                  items: suitableRooms.map((r) => DropdownMenuItem(
                                    value: r,
                                    child: Text('Room ${r.roomId} (${r.location} - Rs.${r.calculateTotalPrice().toInt()})'),
                                  )).toList(),
                                  onChanged: (val) => setState(() => _selectedRoom = val),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => state.rejectRoommateRequest(match.id),
                                        child: const Text('Reject Match'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _selectedRoom == null ? null : () {
                                          state.approveMatch(match.id);
                                          state.assignRoom(studentA, studentB, _selectedRoom!);
                                          setState(() => _selectedRoom = null);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Match Approved & Room Assigned!'))
                                          );
                                        },
                                        child: const Text('Approve & Assign'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              
              // Room Requests Tab
              roomRequests.isEmpty
                  ? const Center(child: Text('No individual room requests.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: roomRequests.length,
                      itemBuilder: (context, index) {
                        final student = roomRequests[index];
                        final requestedRoom = state.allRooms.firstWhere((r) => r.roomId == student.requestedRoomId);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () => Navigator.pushNamed(context, '/user-details', arguments: student.studentId),
                                  leading: CircleAvatar(child: Text(student.name.isNotEmpty ? student.name[0] : 'U')),
                                  title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(student.email),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('Requested: Room ${student.requestedRoomId}', 
                                      style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const Divider(),
                                const Text('Room Info:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Location: ${requestedRoom.location}'),
                                Text('Type: ${requestedRoom.roomType} | Price: Rs. ${requestedRoom.calculateTotalPrice().toInt()}'),
                                Text('Occupancy: ${requestedRoom.currentOccupancy}/${requestedRoom.capacity}'),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => state.rejectRoomRequest(student.studentId),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('Reject Request'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: requestedRoom.isFull() ? null : () {
                                          state.assignStudentToRoom(student, requestedRoom);
                                          // Clear the request after assignment
                                          student.requestedRoomId = null;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Room ${requestedRoom.roomId} assigned to ${student.name}!'))
                                          );
                                        },
                                        child: Text(requestedRoom.isFull() ? 'Room Full' : 'Approve & Assign'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }
}
