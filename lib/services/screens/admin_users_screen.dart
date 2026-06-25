import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/student.dart';
import '../../models/room.dart';
import 'widgets/syncstay_app_bar.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _searchQuery = '';
  String _filterStatus = 'All';
  Room? _selectedRoom;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final users = state.allStudents.where((u) {
          if (u.role != UserRole.student) return false;
          
          final matchesSearch = u.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                               u.studentId.toLowerCase().contains(_searchQuery.toLowerCase());
          
          bool matchesFilter = true;
          if (_filterStatus == 'Assigned') {
            matchesFilter = u.assignedRoomId != null;
          } else if (_filterStatus == 'Pending') {
            matchesFilter = u.assignedRoomId == null;
          }

          return matchesSearch && matchesFilter;
        }).toList();

        final availableRooms = state.allRooms.where((r) => !r.isFull()).toList();

        return Scaffold(
          appBar: syncStayAppBar(context, screenTitle: 'User Management'),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _filterStatus,
                      items: ['All', 'Assigned', 'Pending'].map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      )).toList(),
                      onChanged: (val) => setState(() => _filterStatus = val!),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? const Center(child: Text('No users found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          bool hasRoom = user.assignedRoomId != null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    onTap: () => Navigator.pushNamed(context, '/user-details', arguments: user.studentId),
                                    title: Text(user.name.isNotEmpty ? user.name : user.studentId, 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    subtitle: Text('Budget: Rs. ${user.budget.toInt()} | Location: ${user.preferredLocation}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        hasRoom
                                            ? const Chip(label: Text('Assigned'), backgroundColor: Colors.greenAccent)
                                            : const Chip(label: Text('Pending'), backgroundColor: Colors.orangeAccent),
                                        const SizedBox(width: 4),
                                        Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                                      ],
                                    ),
                                  ),
                                  const Divider(),
                                  const Text('Requirements:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (user.requiresAC) _smallChip('AC'),
                                      if (user.requiresAttachedBath) _smallChip('Bath'),
                                      if (user.requiresWifi) _smallChip('WiFi'),
                                      if (user.requiresFurnished) _smallChip('Furn'),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (!hasRoom) ...[
                                    if (user.requestedRoomId != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.info_outline, size: 16, color: Color(0xFF6C63FF)),
                                              const SizedBox(width: 8),
                                              Text('Requested: Room ${user.requestedRoomId}', 
                                                style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<Room>(
                                            isExpanded: true,
                                            hint: const Text('Assign Room'),
                                            value: user.requestedRoomId != null ? availableRooms.where((r) => r.roomId == user.requestedRoomId).firstOrNull : null,
                                            items: availableRooms.map((r) => DropdownMenuItem(
                                              value: r,
                                              child: Text('Room ${r.roomId} (Rs.${r.calculateTotalPrice().toInt()})'),
                                            )).toList(),
                                            onChanged: (val) => setState(() => _selectedRoom = val),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () {
                                            // If no new room selected, use the one already in value (requested room) or _selectedRoom
                                            final roomToAssign = _selectedRoom ?? (user.requestedRoomId != null ? availableRooms.where((r) => r.roomId == user.requestedRoomId).firstOrNull : null);
                                            if (roomToAssign != null) {
                                              state.assignStudentToRoom(user, roomToAssign);
                                              setState(() => _selectedRoom = null);
                                            }
                                          },
                                          child: const Text('Assign'),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Room: ${user.assignedRoomId}',
                                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              user.paymentVerified
                                                  ? Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Text('Paid', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                                    )
                                                  : Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                                    ),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => state.unassignFromRoom(user),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text('Unassign', style: TextStyle(color: Colors.red, fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => Navigator.pushNamed(context, '/user-details', arguments: user.studentId),
                                        icon: const Icon(Icons.visibility, size: 18),
                                        label: const Text('View Details', style: TextStyle(fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => _confirmDeleteUser(context, state, user.studentId),
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                        label: const Text('Delete User', style: TextStyle(color: Colors.red, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteUser(BuildContext context, AppState state, String studentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: const Text('This will remove all their requests and room assignments. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              state.removeUser(studentId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _smallChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}
