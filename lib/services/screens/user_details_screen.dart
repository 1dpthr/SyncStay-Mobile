import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/hostel_request.dart';
import '../../models/student.dart';
import 'widgets/syncstay_app_bar.dart';
class UserDetailsScreen extends StatelessWidget {
  final String studentId;

  const UserDetailsScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        Student? found;
        try {
          found = state.allStudents.firstWhere((s) => s.studentId == studentId);
        } catch (e) {
          if (state.currentUser?.studentId == studentId) {
            found = state.currentUser;
          }
        }

        if (found == null) {
          return Scaffold(
            appBar: syncStayAppBar(context, screenTitle: 'User Details'),
            body: const Center(child: Text('User not found')),
          );
        }

        final student = found;
        final currentUser = state.currentUser;
        
        final isMe = currentUser?.studentId == student.studentId;
        final isWarden = currentUser?.role == UserRole.warden;
        final isAdmin = currentUser?.role == UserRole.admin;
        final isStaffViewer = isWarden || isAdmin || currentUser?.role == UserRole.owner;
        final isStudentProfile = student.role == UserRole.student;

        final List<String> theyCanTeachMe;
        final List<String> iCanTeachThem;

        if (isMe || currentUser == null) {
          theyCanTeachMe = [];
          iCanTeachThem = [];
        } else {
          final mySkillsSet = currentUser.skills.toSet();
          final theirSkillsSet = student.skills.toSet();
          
          theyCanTeachMe = theirSkillsSet.where((s) => !mySkillsSet.contains(s)).toList();
          iCanTeachThem = mySkillsSet.where((s) => !theirSkillsSet.contains(s)).toList();
        }

        Student? roommate;
        final roommateId = student.roommateId;
        if (roommateId != null) {
          try {
            roommate = state.allStudents.firstWhere((s) => s.studentId == roommateId);
          } catch (e) {
            // Roommate not found
          }
        }

        String cleanUsername = student.studentId.split('@')[0];

        return Scaffold(
          appBar: syncStayAppBar(
            context,
            screenTitle: student.name.isNotEmpty ? student.name : 'User Details',
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                          child: Text(
                            (student.name.isNotEmpty ? student.name[0] : cleanUsername[0]).toUpperCase(),
                            style: const TextStyle(fontSize: 40, color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          student.name.isNotEmpty ? student.name : 'Not Set',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Username: $cleanUsername',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusChip(
                              label: student.profileCompleted ? 'Profile Complete' : 'Profile Incomplete',
                              color: student.profileCompleted ? Colors.green : Colors.orange,
                            ),
                            if (student.isAccountBlocked)
                              _StatusChip(label: 'Blocked', color: Colors.red)
                            else if (student.assignedRoomId != null)
                              _StatusChip(
                                label: 'Room: ${student.assignedRoomId}',
                                color: Colors.blue,
                                maxWidth: MediaQuery.sizeOf(context).width - 80,
                              )
                            else
                              const _StatusChip(label: 'No Room', color: Colors.grey),
                          ],
                        ),
                        if (!isMe && !isStaffViewer && currentUser != null) ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showSkillSharePicker(context, state, student, theyCanTeachMe, "Request to Learn"),
                                  icon: const Icon(Icons.school),
                                  label: const Text('Learn from them'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF03DAC6),
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showSkillSharePicker(context, state, student, iCanTeachThem, "Offer to Teach", isOffering: true),
                                  icon: const Icon(Icons.volunteer_activism),
                                  label: const Text('Offer to Teach'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6C63FF),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (!isMe && !isStaffViewer && currentUser != null && (theyCanTeachMe.isNotEmpty || iCanTeachThem.isNotEmpty)) ...[
                  const Text('Skill Compatibility', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF03DAC6))),
                  const SizedBox(height: 12),
                  if (theyCanTeachMe.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('They can teach you: ${theyCanTeachMe.take(3).join(", ")}${theyCanTeachMe.length > 3 ? "..." : ""}', style: const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  if (iCanTeachThem.isNotEmpty)
                    Text('You can teach them: ${iCanTeachThem.take(3).join(", ")}${iCanTeachThem.length > 3 ? "..." : ""}', style: const TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 24),
                ],

                Text(
                  'Academic Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _DetailRow(icon: Icons.email, label: 'Email', value: student.email.isNotEmpty ? student.email : 'Not set'),
                _DetailRow(icon: Icons.business, label: 'Department', value: student.department.isNotEmpty ? student.department : 'Not set'),
                if (isStaffViewer)
                  _DetailRow(icon: Icons.badge_outlined, label: 'Role', value: state.roleDisplayLabel(student.role)),

                if (isStaffViewer && isStudentProfile) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Hostel Preferences',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(icon: Icons.location_on_outlined, label: 'Preferred Location', value: student.preferredLocation),
                  _DetailRow(icon: Icons.account_balance_wallet_outlined, label: 'Budget', value: 'Rs. ${student.budget.toInt()} / month'),
                  _DetailRow(icon: Icons.people_outline, label: 'Sharing', value: student.preferredSharing),
                  const SizedBox(height: 8),
                  Text(
                    'Requirements',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (student.requiresAC) _RequirementChip('AC'),
                      if (student.requiresAttachedBath) _RequirementChip('Attached Bath'),
                      if (student.requiresWifi) _RequirementChip('WiFi'),
                      if (student.requiresFurnished) _RequirementChip('Furnished'),
                      if (student.requiresKitchen) _RequirementChip('Kitchen'),
                      if (student.requiresLaundry) _RequirementChip('Laundry'),
                      if (!student.requiresAC &&
                          !student.requiresAttachedBath &&
                          !student.requiresWifi &&
                          !student.requiresFurnished &&
                          !student.requiresKitchen &&
                          !student.requiresLaundry)
                        const Text('No special requirements', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  if (isAdmin || isWarden) ...[
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final bookedReq = state.getBookedHostelRequestForStudent(student.studentId);
                        final pendingReq = state.getPendingHostelRequestForStudent(student.studentId);
                        final req = bookedReq ?? pendingReq;
                        if (req == null) {
                          return const Text('No hostel request yet', style: TextStyle(color: Colors.grey));
                        }
                        return _DetailRow(
                          icon: Icons.apartment,
                          label: 'Hostel Request',
                          value: '${req.hostelName} · ${req.status.displayLabel}',
                        );
                      },
                    ),
                  ],
                ],

                const SizedBox(height: 24),
                const Text('Personal Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                const SizedBox(height: 12),
                _DetailRow(icon: Icons.cake, label: 'Age', value: student.age > 0 ? '${student.age}' : 'Not set'),
                _DetailRow(icon: Icons.person_outline, label: 'Gender', value: student.gender.isNotEmpty ? student.gender : 'Not set'),

                if (roommate != null && student.assignedRoomId != null) ...[
                  const SizedBox(height: 24),
                  const Text('Pair / Roommate Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.05),
                    child: ListTile(
                      leading: const Icon(Icons.favorite, color: Colors.pink),
                      title: Text(roommate.name.isNotEmpty ? roommate.name : 'User: ${roommate.studentId.split('@')[0]}'),
                      subtitle: const Text('Click to view paired roommate'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/user-details',
                          arguments: roommate!.studentId,
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                if (student.assignedRoomId != null) ...[
                  const Text('Room Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.blue.withValues(alpha: 0.05),
                    child: ListTile(
                      leading: const Icon(Icons.meeting_room, color: Colors.blue),
                      title: Text('Room ${student.assignedRoomId}'),
                      subtitle: const Text('Click to view room details'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/room-details',
                          arguments: student.assignedRoomId,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (isStudentProfile) ...[
                  const Text('Habits & Preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                  const SizedBox(height: 12),
                  _DetailRow(icon: Icons.bedtime, label: 'Sleep Schedule', value: student.sleepSchedule.replaceAll('_', ' ').toUpperCase()),
                  _DetailRow(icon: Icons.book, label: 'Study Hours', value: '${student.studyHoursPerDay} hrs/day'),
                  _DetailRow(icon: Icons.cleaning_services, label: 'Cleanliness', value: '${student.cleanlinessLevel}/10'),
                  _DetailRow(icon: Icons.volume_up, label: 'Noise Tolerance', value: '${student.noiseTolerance}/10'),
                  _DetailRow(icon: Icons.people_alt, label: 'Guest Policy', value: student.guestPolicy.toUpperCase()),
                  _DetailRow(icon: Icons.smoke_free, label: 'Smoker', value: student.smoker ? 'Yes' : 'No'),
                  _DetailRow(icon: Icons.local_bar, label: 'Drinker', value: student.drinker ? 'Yes' : 'No'),
                  const SizedBox(height: 24),
                  const Text('Skills', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                  const SizedBox(height: 12),
                  if (student.skills.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: student.skills.map((s) => Chip(
                        label: Text(s),
                        backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                      )).toList(),
                    )
                  else
                    const Text('No skills listed', style: TextStyle(color: Colors.grey)),
                  if (student.otherSkills.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Other: ${student.otherSkills}', style: const TextStyle(color: Colors.grey)),
                  ],
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSkillSharePicker(BuildContext context, AppState state, Student target, List<String> skills, String title, {bool isOffering = false}) {
    if (skills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isOffering ? 'You have no unique skills to offer.' : 'This user has no unique skills to teach.')));
        return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: skills.length,
                  itemBuilder: (context, index) {
                    final skill = skills[index];
                    return ListTile(
                      leading: Icon(isOffering ? Icons.volunteer_activism : Icons.school, color: isOffering ? const Color(0xFF6C63FF) : const Color(0xFF03DAC6)),
                      title: Text(skill),
                      onTap: () {
                        if (isOffering) {
                          state.sendSkillShareRequest(target, "Offering to teach: $skill");
                        } else {
                          state.sendSkillShareRequest(target, skill);
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skill share request sent!')));
                      },
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
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementChip extends StatelessWidget {
  final String label;
  const _RequirementChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final double? maxWidth;

  const _StatusChip({required this.label, required this.color, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
