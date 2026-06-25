import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/room.dart';
import '../../models/student.dart';
import 'widgets/syncstay_app_bar.dart';

class RoomDetailsScreen extends StatelessWidget {
  final String roomId;
  
  const RoomDetailsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        Room? room;
        try {
          room = state.allRooms.firstWhere((r) => r.roomId == roomId);
        } catch (e) {
          return Scaffold(
            appBar: syncStayAppBar(context, screenTitle: 'Room Details'),
            body: const Center(child: Text('Room not found')),
          );
        }

        final occupants = state.allStudents
            .where((s) => s.assignedRoomId == roomId)
            .toList();

        return Scaffold(
          appBar: syncStayAppBar(
            context,
            screenTitle: 'Room ${room.roomId} Details',
            actions: [
              if (state.currentUser?.role == UserRole.warden)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditFacilitiesDialog(context, state, room!),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.meeting_room,
                              size: 40,
                              color: room.isFull() ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Room ${room.roomId}',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${room.location} | Block ${room.block}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: room.isFull() ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${room.currentOccupancy}/${room.capacity}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: room.isFull() ? Colors.red : Colors.green),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        _DetailRow(icon: Icons.hotel, label: 'Type', value: room.roomType.toUpperCase()),
                        _DetailRow(icon: Icons.ac_unit, label: 'AC', value: room.hasAC ? 'Yes' : 'No', valueColor: room.hasAC ? Colors.green : null),
                        _DetailRow(icon: Icons.bathroom, label: 'Attached Bath', value: room.hasAttachedBathroom ? 'Yes' : 'No', valueColor: room.hasAttachedBathroom ? Colors.green : null),
                        _DetailRow(icon: Icons.wifi, label: 'WiFi', value: room.hasWifi ? 'Yes' : 'No', valueColor: room.hasWifi ? Colors.green : null),
                        _DetailRow(icon: Icons.chair, label: 'Furnished', value: room.isFurnished ? 'Yes' : 'No', valueColor: room.isFurnished ? Colors.green : null),
                        _DetailRow(icon: Icons.kitchen, label: 'Kitchen Access', value: room.hasKitchenAccess ? 'Yes' : 'No', valueColor: room.hasKitchenAccess ? Colors.green : null),
                        _DetailRow(icon: Icons.local_laundry_service, label: 'Laundry', value: room.hasLaundry ? 'Yes' : 'No', valueColor: room.hasLaundry ? Colors.green : null),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Monthly Price', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Rs. ${room.calculateTotalPrice().toInt()}', 
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                          ],
                        ),
                        if (state.currentUser?.role != UserRole.warden && state.currentUser?.assignedRoomId == null) ...[
                          const SizedBox(height: 24),
                          if (state.currentUser?.role == UserRole.student &&
                              !state.roomMatchesStudentGender(room!.roomId, state.currentUser!.gender))
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'This room belongs to a hostel for a different gender and cannot be requested.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    state.rejectRoom(room!.roomId);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Room suggestion rejected.')),
                                    );
                                  },
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  label: const Text('Reject Room', style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: (state.currentUser?.requestedRoomId == room.roomId) ? null : () {
                                    state.requestRoom(room!.roomId);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Request for Room ${room.roomId} sent to admin!')),
                                    );
                                  },
                                  icon: const Icon(Icons.send),
                                  label: Text(state.currentUser?.requestedRoomId == room.roomId ? 'Requested' : 'Request Room'),
                                ),
                              ),
                            ],
                          ),
                        ] else if (state.currentUser?.assignedRoomId == room.roomId) ...[
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Assigned room status: ${state.currentUser!.assignmentStatus.name.toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (state.currentUser!.assignmentStatus == AssignmentStatus.assigned) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      state.acceptAssignedRoom(state.currentUser!);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room accepted. Please make payment.')));
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6C63FF),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.check, color: Colors.white),
                                    label: const Text('Accept Room', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      state.rejectAssignedRoom(state.currentUser!);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room rejected. Admin has been notified.')));
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    label: const Text('Reject Room', style: TextStyle(color: Colors.red)),
                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (state.currentUser!.assignmentStatus == AssignmentStatus.accepted && !state.currentUser!.paymentVerified) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.pushNamed(context, '/payment'),
                                    icon: const Icon(Icons.payment),
                                    label: const Text('Pay Now'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      state.rejectAssignedRoom(state.currentUser!);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room rejected. Admin has been notified.')));
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    label: const Text('Reject Room', style: TextStyle(color: Colors.red)),
                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (state.currentUser!.paymentVerified) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text('Payment completed and booking confirmed.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          ],
                          if (state.currentUser!.roommateId != null) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.pushNamed(context, '/user-details', arguments: state.currentUser!.roommateId),
                                icon: const Icon(Icons.people),
                                label: const Text('Contact Roommate'),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Room Occupants', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (occupants.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No occupants yet', style: TextStyle(color: Colors.grey))),
                    ),
                  )
                else
                  ...occupants.map((student) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => Navigator.pushNamed(context, '/user-details', arguments: student.studentId),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                        child: Text(student.name.isNotEmpty ? student.name[0] : student.studentId[0]),
                      ),
                      title: Text(student.name.isNotEmpty ? student.name : student.studentId),
                      subtitle: Text(student.paymentVerified ? 'Payment Verified' : 'Payment Pending',
                        style: TextStyle(color: student.paymentVerified ? Colors.green : Colors.orange, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditFacilitiesDialog(BuildContext context, AppState state, Room room) {
    bool ac = room.hasAC;
    bool wifi = room.hasWifi;
    bool furn = room.isFurnished;
    bool kitchen = room.hasKitchenAccess;
    bool laundry = room.hasLaundry;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Room Facilities'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text('AC'),
                      value: ac,
                      onChanged: (val) => setState(() => ac = val),
                    ),
                    SwitchListTile(
                      title: const Text('WiFi'),
                      value: wifi,
                      onChanged: (val) => setState(() => wifi = val),
                    ),
                    SwitchListTile(
                      title: const Text('Furnished'),
                      value: furn,
                      onChanged: (val) => setState(() => furn = val),
                    ),
                    SwitchListTile(
                      title: const Text('Kitchen Access'),
                      value: kitchen,
                      onChanged: (val) => setState(() => kitchen = val),
                    ),
                    SwitchListTile(
                      title: const Text('Laundry'),
                      value: laundry,
                      onChanged: (val) => setState(() => laundry = val),
                    ),
                    const Divider(),
                    const Text('Note: Attached Bath cannot be modified.', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    state.updateRoomFacilities(
                      room.roomId,
                      ac: ac,
                      wifi: wifi,
                      furn: furn,
                      kitchen: kitchen,
                      laundry: laundry,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Facilities updated successfully')));
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor, fontSize: 14)),
        ],
      ),
    );
  }
}
