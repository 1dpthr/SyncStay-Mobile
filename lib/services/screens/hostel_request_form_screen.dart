import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'widgets/syncstay_app_bar.dart';
import '../../models/hostel.dart';

class HostelRequestFormScreen extends StatefulWidget {
  const HostelRequestFormScreen({super.key});

  @override
  State<HostelRequestFormScreen> createState() => _HostelRequestFormScreenState();
}

class _HostelRequestFormScreenState extends State<HostelRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  String? _selectedHostelId;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    final gender = Provider.of<AppState>(context, listen: false).currentUser?.gender ?? 'Female';
    _selectedType = Provider.of<AppState>(context, listen: false).defaultHostelTypeForGender(gender);
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _submit(AppState state) {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHostelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hostel')),
      );
      return;
    }

    final error = state.sendHostelAssignmentRequest(
      _selectedHostelId!,
      _selectedType,
      _descController.text.trim(),
    );

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request sent for admin approval!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: syncStayAppBar(context, screenTitle: 'Request Hostel Assignment'),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final warden = state.currentUser;
          final wardenId = warden?.studentId ?? '';
          final blockReason = state.wardenHostelRequestBlockReason(wardenId);
          final available = state.getHostelsAvailableForAdminRequest();
          final ids = <String>{};
          final hostels = <Hostel>[];
          for (final h in available) {
            if (ids.add(h.id)) hostels.add(h);
          }
          final dropdownValue = _selectedHostelId != null && ids.contains(_selectedHostelId)
              ? _selectedHostelId
              : null;

          if (warden != null && warden.gender.isNotEmpty) {
            final lockedType = state.defaultHostelTypeForGender(warden.gender);
            if (_selectedType != lockedType) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedType = lockedType);
              });
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (blockReason != null) ...[
                    Card(
                      color: Colors.orange.withValues(alpha: 0.12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange),
                            const SizedBox(width: 10),
                            Expanded(child: Text(blockReason)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Select an admin-approved hostel. You can manage only one hostel at a time, '
                    'and only the type that matches your gender.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  if (blockReason != null)
                    const SizedBox.shrink()
                  else if (hostels.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No approved, unbooked hostels available right now. '
                          'Check back when owners add new hostels.',
                        ),
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      value: dropdownValue,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Hostel',
                        prefixIcon: Icon(Icons.business),
                      ),
                      hint: const Text('Choose hostel'),
                      items: hostels.map((h) {
                        return DropdownMenuItem(
                          value: h.id,
                          child: Text(
                            '${h.hostelName} — ${h.location}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (id) => setState(() => _selectedHostelId = id),
                      validator: (v) => v == null ? 'Please select a hostel' : null,
                    ),
                    const SizedBox(height: 20),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hostel type (from your gender)',
                        prefixIcon: Icon(Icons.category),
                      ),
                      child: Text(
                        _selectedType,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => _submit(state),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Send Request',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
