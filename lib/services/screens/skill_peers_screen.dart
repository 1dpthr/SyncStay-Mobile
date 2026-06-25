import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'widgets/syncstay_app_bar.dart';
import '../../models/student.dart';
import '../../models/roommate_request.dart';

class SkillPeersScreen extends StatefulWidget {
  const SkillPeersScreen({super.key});

  @override
  State<SkillPeersScreen> createState() => _SkillPeersScreenState();
}

class _SkillPeersScreenState extends State<SkillPeersScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All', 'Coding', 'Sports', 'Gaming', 'Art & Design', 
    'Photography', 'Cooking', 'Music', 'Language', 'Fitness', 'Other'
  ];

  Map<String, List<String>> _categorySkills = {
    'Coding': ['Programming', 'Web Development', 'App Development', 'Python', 'Java', 'C++'],
    'Sports': ['Cricket', 'Football', 'Badminton', 'Table Tennis'],
    'Gaming': ['E-sports', 'Chess', 'PUBG', 'Valorant'],
    'Art & Design': ['Graphic Designing', 'UI/UX', 'Painting', 'Sketching'],
    'Photography': ['Photography', 'Video Editing'],
    'Cooking': ['Baking', 'Cooking'],
    'Music': ['Guitar', 'Singing', 'Drums'],
    'Language': ['Language Learning', 'English', 'Urdu'],
    'Fitness': ['Gym', 'Yoga'],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: syncStayAppBar(context, screenTitle: 'Skill Peers'),
      body: Consumer<AppState>(
        builder: (context, state, child) {
          final allPeers = state.getSkillPeers();
          final peers = allPeers.where((p) {
            bool matchesQuery = true;
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              matchesQuery = p.skills.any((s) => s.toLowerCase().contains(query)) ||
                             p.learningSkills.any((s) => s.toLowerCase().contains(query)) ||
                             p.name.toLowerCase().contains(query);
            }

            bool matchesCategory = true;
            if (_selectedCategory != 'All') {
              if (_selectedCategory == 'Other') {
                // Check if skill doesn't belong to any defined category
                matchesCategory = p.skills.any((s) => !_isDefinedSkill(s));
              } else {
                final catSkills = _categorySkills[_selectedCategory] ?? [];
                matchesCategory = p.skills.any((s) => catSkills.contains(s) || s == _selectedCategory);
              }
            }

            return matchesQuery && matchesCategory;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by skill (e.g. Flutter, Cooking)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    filled: true,
                    fillColor: state.isDarkMode ? Colors.grey[900] : Colors.grey[100],
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildPeersList(context, state, peers),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeersList(BuildContext context, AppState state, List<Student> peers) {
          if (state.currentUser?.skills.isEmpty ?? true) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.psychology_alt, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No skills added.', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Update your profile with skills to find peers!'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/profile'),
                    child: const Text('Update Profile'),
                  )
                ],
              ),
            );
          }

          if (peers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No skill peers found.', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Try a different search or add more skills!'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: peers.length,
            itemBuilder: (context, index) {
              final peer = peers[index];
              final mySkills = state.currentUser!.skills.toSet();
              final myLearning = state.currentUser!.learningSkills.toSet();
              final theirSkills = peer.skills.toSet();
              final theirLearning = peer.learningSkills.toSet();
              final commonSkills = mySkills.intersection(theirSkills).toList();
              final skillsTheyCanTeachMe = theirSkills.difference(mySkills).toList();
              final skillsICanTeachThem = mySkills.difference(theirSkills).toList();
              final skillsIWantToLearn = myLearning.intersection(theirSkills).toList();
              final skillsTheyWantToLearn = theirLearning.intersection(mySkills).toList();
              final suggestedShareSkills = <String>[];
              suggestedShareSkills.addAll(skillsIWantToLearn);
              suggestedShareSkills.addAll(skillsTheyWantToLearn);
              suggestedShareSkills.addAll(skillsTheyCanTeachMe.where((skill) => !suggestedShareSkills.contains(skill)).toList());
              suggestedShareSkills.addAll(skillsICanTeachThem.where((skill) => !suggestedShareSkills.contains(skill)).toList());
              String cleanUsername = peer.studentId.split('@')[0];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => Navigator.pushNamed(context, '/user-details', arguments: peer.studentId),
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color(0xFF03DAC6).withValues(alpha: 0.2),
                          child: Text(
                            peer.name.isNotEmpty ? peer.name[0].toUpperCase() : cleanUsername[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              color: Color(0xFF03DAC6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              peer.name.isNotEmpty ? peer.name : 'User: $cleanUsername',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: peer.isOnline ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text('Username: $cleanUsername', style: const TextStyle(color: Colors.grey)),
                        trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                      ),
                      const Divider(),
                      if (commonSkills.isNotEmpty) ...[
                        const Text('Shared Skills:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: commonSkills.map((skill) {
                            return ActionChip(
                              label: Text(state.hasPendingSkillRequestTo(peer, skill) ? 'Pending...' : skill),
                              backgroundColor: state.hasPendingSkillRequestTo(peer, skill) 
                                ? Colors.orange.withOpacity(0.3)
                                : const Color(0xFF6C63FF).withValues(alpha: 0.1),
                              labelStyle: TextStyle(
                                color: state.hasPendingSkillRequestTo(peer, skill) 
                                  ? Colors.orange 
                                  : const Color(0xFF6C63FF), 
                                fontSize: 12,
                              ),
                              onPressed: state.hasPendingSkillRequestTo(peer, skill) 
                                ? null 
                                : () => _showRequestDialog(context, state, peer, skill),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (skillsIWantToLearn.isNotEmpty) ...[
                        const Text('You can learn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skillsIWantToLearn.map((skill) {
                            return ActionChip(
                              label: Text(state.hasPendingSkillRequestTo(peer, skill) ? 'Pending...' : skill),
                              backgroundColor: state.hasPendingSkillRequestTo(peer, skill) 
                                ? Colors.orange.withOpacity(0.3)
                                : const Color(0xFF03DAC6).withValues(alpha: 0.1),
                              labelStyle: TextStyle(
                                color: state.hasPendingSkillRequestTo(peer, skill) 
                                  ? Colors.orange 
                                  : const Color(0xFF03DAC6), 
                                fontSize: 12,
                              ),
                              onPressed: state.hasPendingSkillRequestTo(peer, skill) 
                                ? null 
                                : () => _showRequestDialog(context, state, peer, skill),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (skillsTheyWantToLearn.isNotEmpty) ...[
                        const Text('They want to learn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skillsTheyWantToLearn.map((skill) {
                            return ActionChip(
                              label: Text(state.hasPendingSkillRequestTo(peer, skill) ? 'Pending...' : skill),
                              backgroundColor: state.hasPendingSkillRequestTo(peer, skill) 
                                ? Colors.orange.withOpacity(0.3)
                                : const Color(0xFF6C63FF).withValues(alpha: 0.1),
                              labelStyle: TextStyle(
                                color: state.hasPendingSkillRequestTo(peer, skill) 
                                  ? Colors.orange 
                                  : const Color(0xFF6C63FF), 
                                fontSize: 12,
                              ),
                              onPressed: state.hasPendingSkillRequestTo(peer, skill) 
                                ? null 
                                : () => _showRequestDialog(context, state, peer, skill),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (skillsTheyCanTeachMe.isNotEmpty && skillsIWantToLearn.isEmpty) ...[
                        const Text('Different skills they have:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skillsTheyCanTeachMe.map((skill) {
                            return ActionChip(
                              label: Text(state.hasPendingSkillRequestTo(peer, skill) ? 'Pending...' : skill),
                              backgroundColor: state.hasPendingSkillRequestTo(peer, skill) 
                                ? Colors.orange.withOpacity(0.3)
                                : const Color(0xFF6C63FF).withValues(alpha: 0.1),
                              labelStyle: TextStyle(
                                color: state.hasPendingSkillRequestTo(peer, skill) 
                                  ? Colors.orange 
                                  : const Color(0xFF6C63FF), 
                                fontSize: 12,
                              ),
                              onPressed: state.hasPendingSkillRequestTo(peer, skill) 
                                ? null 
                                : () => _showRequestDialog(context, state, peer, skill),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (skillsICanTeachThem.isNotEmpty) ...[
                        const Text('You can teach them:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skillsICanTeachThem.map((skill) {
                            return ActionChip(
                              label: Text(state.hasPendingSkillRequestTo(peer, skill) ? 'Pending...' : skill),
                              backgroundColor: state.hasPendingSkillRequestTo(peer, skill) 
                                ? Colors.orange.withOpacity(0.3)
                                : const Color(0xFF03DAC6).withValues(alpha: 0.1),
                              labelStyle: TextStyle(
                                color: state.hasPendingSkillRequestTo(peer, skill) 
                                  ? Colors.orange 
                                  : const Color(0xFF03DAC6), 
                                fontSize: 12,
                              ),
                              onPressed: state.hasPendingSkillRequestTo(peer, skill) 
                                ? null 
                                : () => _showRequestDialog(context, state, peer, skill),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: suggestedShareSkills.isEmpty ? null : () {
                            _showRequestDialog(context, state, peer, suggestedShareSkills.first);
                          },
                          icon: const Icon(Icons.send),
                          label: const Text('Request Skill Share'),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
  }

  void _showRequestDialog(BuildContext context, AppState state, Student peer, String skill) {
    final isPending = state.hasPendingSkillRequestTo(peer, skill);
    if (isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request already pending for this skill!')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Skill Share'),
        content: Text('Do you want to send a request to ${peer.name.isNotEmpty ? peer.name : peer.studentId.split('@')[0]} to collaborate on "$skill"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              state.sendSkillShareRequest(peer, skill);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Request sent for $skill!')),
              );
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }
  bool _isDefinedSkill(String skill) {
    for (var skills in _categorySkills.values) {
      if (skills.contains(skill)) return true;
    }
    return false;
  }
}
