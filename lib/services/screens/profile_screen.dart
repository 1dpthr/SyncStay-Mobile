import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../../models/student.dart';
import 'widgets/hostel_location_picker.dart';
import 'widgets/syncstay_app_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late Student _student;
  bool _isEditMode = false;
  List<String> _selectedSkills = [];
  List<String> _selectedLearningSkills = [];
  String _otherSkills = '';

  final List<String> _departments = [
    'Computer Science',
    'Information Technology',
    'Software Engineering',
    'Electrical Engineering',
    'Mechanical Engineering',
    'Business Administration',
    'Data Science',
    'Cyber Security'
  ];

  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppState>(context, listen: false);
    var current = state.currentUser!;
    _selectedSkills = List.from(current.skills);
    _selectedLearningSkills = List.from(current.learningSkills);
    _otherSkills = current.otherSkills;
    
    _student = Student();
    _student.updateFrom(current);
    _locationController = TextEditingController(text: current.preferredLocation);

    if (current.department.isEmpty) _student.department = _departments[0];
    
    if (!current.profileCompleted) {
      _isEditMode = true;
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_isEditMode && _formKey.currentState!.validate()) {
      _formKey.currentState!.save();
    }
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set preferred location (type or map).')),
      );
      return;
    }
    _student.preferredLocation = _locationController.text.trim();
    _student.skills = List.from(_selectedSkills);
    _student.learningSkills = List.from(_selectedLearningSkills);
    _student.otherSkills = _otherSkills;
    _student.profileCompleted = true;
    Provider.of<AppState>(context, listen: false).updateProfile(_student);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile Saved!')),
    );
    
    final state = Provider.of<AppState>(context, listen: false);
    if (state.currentUser?.profileCompleted ?? false) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      });
    }
    
    setState(() {
      _isEditMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.currentUser?.isAccountBlocked == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/blocked-account');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isNewUser = !state.currentUser!.profileCompleted;

    return Scaffold(
      appBar: syncStayAppBar(
        context,
        screenTitle: isNewUser ? 'Complete Profile' : 'My Profile',
        actions: [
          if (_isEditMode)
            IconButton(icon: const Icon(Icons.save), onPressed: _saveProfile)
          else
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
              onPressed: _toggleEditMode,
            ),
        ],
      ),
      body: _isEditMode ? _buildEditForm() : _buildViewMode(),
    );
  }

  Widget _buildViewMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                      child: Text(
                        _student.name.isNotEmpty 
                            ? _student.name[0].toUpperCase() 
                            : (_student.studentId.isNotEmpty ? _student.studentId[0].toUpperCase() : '?'),
                        style: const TextStyle(fontSize: 40, color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_student.name.isNotEmpty)
                      Text(
                        _student.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    Text('Username: ${_student.studentId}', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Chip(label: Text(_student.occupation), backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.1)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Lifestyle & Habits', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
          const SizedBox(height: 12),
          _viewRow('Social Style', _student.introvertExtrovert),
          _viewRow('Study Environment', _student.studyEnvironment),
          _viewRow('Sleep Schedule', _student.sleepSchedule),
          _viewRow('Guest Preference', _student.guestPreference),
          _viewRow('Cleanliness', '${_student.cleanlinessLevel}/10'),
          _viewRow('Smoking', _student.smoker ? 'Yes' : 'No'),
          
          const SizedBox(height: 24),
          const Text('Room Requirements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
          const SizedBox(height: 12),
          _viewRow('Monthly Budget', 'Rs. ${_student.budget.toInt()}'),
          _viewRow('Preferred Location', _student.preferredLocation),
          _viewRow('Sharing Type', _student.preferredSharing),
          
          const SizedBox(height: 24),
          const Text('My Skills', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _student.skills.map((s) => Chip(label: Text(s))).toList(),
          ),
          if (_student.skills.isEmpty) const Text('No skills added yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          
          const SizedBox(height: 24),
          const Text('Want to Learn', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _student.learningSkills.map((s) => Chip(label: Text(s), backgroundColor: Colors.teal.withValues(alpha: 0.1))).toList(),
          ),
          if (_student.learningSkills.isEmpty) const Text('No learning interests added yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _toggleEditMode,
              icon: const Icon(Icons.edit),
              label: const Text('Update Profile \u0026 Preferences'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Provider.of<AppState>(context, listen: false).logout();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text('Basic Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _student.name,
            decoration: const InputDecoration(labelText: 'Full Name'),
            onSaved: (val) => _student.name = val ?? '',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _student.occupation,
            decoration: const InputDecoration(labelText: 'Occupation Status'),
            items: ['Student', 'Working Professional', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (val) => setState(() => _student.occupation = val!),
          ),
          
          const SizedBox(height: 32),
          const Text('Lifestyle Preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _student.introvertExtrovert,
            decoration: const InputDecoration(labelText: 'Social Personality'),
            items: ['Introvert', 'Extrovert', 'Ambivert'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (val) => setState(() => _student.introvertExtrovert = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _student.studyEnvironment,
            decoration: const InputDecoration(labelText: 'Study Environment'),
            items: ['Quiet', 'Social', 'Music'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (val) => setState(() => _student.studyEnvironment = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _student.sleepSchedule,
            decoration: const InputDecoration(labelText: 'Sleeping Schedule'),
            items: ['Early Sleeper', 'Night Owl', 'Flexible'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (val) => setState(() => _student.sleepSchedule = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _student.guestPreference,
            decoration: const InputDecoration(labelText: 'Guest Preference'),
            items: ['Rarely', 'Sometimes', 'Often'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (val) => setState(() => _student.guestPreference = val!),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Do you smoke?'),
            value: _student.smoker,
            onChanged: (val) => setState(() => _student.smoker = val),
          ),
          const SizedBox(height: 16),
          Text('Cleanliness Level: ${_student.cleanlinessLevel}/10'),
          Slider(
            value: _student.cleanlinessLevel.toDouble(),
            min: 1, max: 10, divisions: 9,
            label: _student.cleanlinessLevel.toString(),
            onChanged: (val) => setState(() => _student.cleanlinessLevel = val.toInt()),
          ),
          const SizedBox(height: 32),
          const Text('Skills & Exchange', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
          const SizedBox(height: 16),
          _buildSkillSelector('My Skills (I can teach)', _selectedSkills),
          const SizedBox(height: 16),
          _buildSkillSelector('I want to learn', _selectedLearningSkills),
          
          const SizedBox(height: 32),
          const Text('Room Requirements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
          const SizedBox(height: 16),
          Text('Monthly Budget: Rs. ${_student.budget.toInt()}'),
          Slider(
            value: _student.budget,
            min: 5000, max: 30000, divisions: 25,
            activeColor: const Color(0xFF6C63FF),
            onChanged: (val) => setState(() => _student.budget = val),
          ),
          const SizedBox(height: 8),
          Text(
            'Room Matching shows rooms in your hostel with monthly rent up to Rs. ${_student.budget.toInt()} — not higher.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const Text('Preferred Hostel Location', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          HostelLocationPicker(
            locationController: _locationController,
            manualFieldLabel: 'Type preferred area / city',
            mapSectionTitle: 'Or pick area on map',
          ),
          const SizedBox(height: 20),
          const Text('Room facilities (required = must have)', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('AC required'),
            value: _student.requiresAC,
            onChanged: (v) => setState(() => _student.requiresAC = v),
          ),
          SwitchListTile(
            title: const Text('Attached bathroom required'),
            value: _student.requiresAttachedBath,
            onChanged: (v) => setState(() => _student.requiresAttachedBath = v),
          ),
          SwitchListTile(
            title: const Text('WiFi required'),
            value: _student.requiresWifi,
            onChanged: (v) => setState(() => _student.requiresWifi = v),
          ),
          SwitchListTile(
            title: const Text('Furnished required'),
            value: _student.requiresFurnished,
            onChanged: (v) => setState(() => _student.requiresFurnished = v),
          ),
          SwitchListTile(
            title: const Text('Kitchen access required'),
            value: _student.requiresKitchen,
            onChanged: (v) => setState(() => _student.requiresKitchen = v),
          ),
          SwitchListTile(
            title: const Text('Laundry required'),
            value: _student.requiresLaundry,
            onChanged: (v) => setState(() => _student.requiresLaundry = v),
          ),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _saveProfile, child: const Text('Save Profile & Preferences')),
        ],
      ),
    );
  }

  Widget _buildSkillSelector(String label, List<String> list) {
    final List<String> defaultSkills = ['Programming', 'Graphic Designing', 'Cooking', 'Language Learning', 'Video Editing', 'Photography', 'Tutoring', 'Music'];
    // Merge default skills with user's custom skills to show all as chips
    final Set<String> allVisibleSkills = {...defaultSkills, ...list};
    final TextEditingController customSkillController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: allVisibleSkills.map((skill) {
            final isSelected = list.contains(skill);
            return FilterChip(
              label: Text(skill),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  if (val) list.add(skill);
                  else list.remove(skill);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customSkillController,
                decoration: const InputDecoration(
                  hintText: 'Add custom skill...',
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF6C63FF)),
              onPressed: () {
                final skill = customSkillController.text.trim();
                if (skill.isNotEmpty && !list.contains(skill)) {
                  setState(() {
                    list.add(skill);
                    customSkillController.clear();
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _viewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
