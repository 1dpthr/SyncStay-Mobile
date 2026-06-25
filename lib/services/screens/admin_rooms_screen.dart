import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/room.dart';
import 'widgets/syncstay_app_bar.dart';

class AdminRoomsScreen extends StatefulWidget {
  final String? initialFilter;
  const AdminRoomsScreen({super.key, this.initialFilter});

  @override
  State<AdminRoomsScreen> createState() => _AdminRoomsScreenState();
}

class _AdminRoomsScreenState extends State<AdminRoomsScreen> {
  late String _filterStatus;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilter ?? 'All';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final rooms = state.allRooms.where((r) {
          final matchesSearch = r.roomId.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                               r.location.toLowerCase().contains(_searchQuery.toLowerCase());
          
          bool matchesFilter = true;
          if (_filterStatus == 'Available') {
            matchesFilter = !r.isFull();
          } else if (_filterStatus == 'Occupied') {
            matchesFilter = r.currentOccupancy > 0;
          }

          return matchesSearch && matchesFilter;
        }).toList();

        return Scaffold(
          appBar: syncStayAppBar(context, screenTitle: 'Room Management'),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search rooms...',
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
                      items: ['All', 'Available', 'Occupied'].map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      )).toList(),
                      onChanged: (val) => setState(() => _filterStatus = val!),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: rooms.isEmpty
                    ? const Center(child: Text('No rooms found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              leading: Icon(Icons.meeting_room, 
                                color: room.isFull() ? Colors.red : Colors.green),
                              title: Text('Room ${room.roomId} (${room.location})'),
                              subtitle: Text('Price: Rs. ${room.calculateTotalPrice().toInt()} | Occupancy: ${room.currentOccupancy}/${room.capacity}'),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Facility Management', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      _facilitySwitch(state, room, 'AC', room.hasAC, (val) => state.updateRoomFacilities(room.roomId, ac: val)),
                                      _facilitySwitch(state, room, 'Attached Bath', room.hasAttachedBathroom, (val) => state.updateRoomFacilities(room.roomId, bath: val)),
                                      _facilitySwitch(state, room, 'WiFi', room.hasWifi, (val) => state.updateRoomFacilities(room.roomId, wifi: val)),
                                      _facilitySwitch(state, room, 'Furnished', room.isFurnished, (val) => state.updateRoomFacilities(room.roomId, furn: val)),
                                      const Divider(),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => Navigator.pushNamed(context, '/room-details', arguments: room.roomId),
                                            icon: const Icon(Icons.visibility),
                                            label: const Text('View Details'),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => state.deleteRoom(room.roomId),
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            label: const Text('Delete Room', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add Room feature coming soon!')));
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _facilitySwitch(AppState state, Room room, String label, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
