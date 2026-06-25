import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../supabase_config.dart';
import '../app_state.dart';
import '../supabase_storage_service.dart';
import 'widgets/hostel_location_picker.dart';
import 'widgets/syncstay_app_bar.dart';

class AddHostelScreen extends StatefulWidget {
  const AddHostelScreen({super.key});

  @override
  State<AddHostelScreen> createState() => _AddHostelScreenState();
}

class _AddHostelScreenState extends State<AddHostelScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _rentController = TextEditingController(text: '25000');
  int _floorCount = 1;
  final Map<int, int> _roomsPerFloor = {};
  Uint8List? _hostelImageBytes;
  Uint8List? _paperImageBytes;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isPaper) async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 70);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      if (isPaper) {
        _paperImageBytes = bytes;
      } else {
        _hostelImageBytes = bytes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: syncStayAppBar(context, screenTitle: 'Add New Hostel'),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading photos to Supabase...'),
                ],
              ),
            )
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 0) {
                  if (_nameController.text.trim().isEmpty || _locationController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter hostel name and location (type manually or use map)')),
                    );
                    return;
                  }
                }
                if (_currentStep == 1) {
                  if (_hostelImageBytes == null || _paperImageBytes == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please upload hostel photo and registration paper')),
                    );
                    return;
                  }
                }
                if (_currentStep < 4) {
                  setState(() => _currentStep++);
                } else {
                  _submit();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) setState(() => _currentStep--);
              },
              steps: [
                Step(
                  title: const Text('Hostel Info'),
                  content: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Hostel Name',
                          hintText: 'e.g. Sunshine Hostel',
                        ),
                      ),
                      const SizedBox(height: 16),
                      HostelLocationPicker(locationController: _locationController),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _rentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Rent per Month (Rs.)',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Hostel type (Girls/Boys) is chosen by warden when they request this hostel.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  isActive: _currentStep >= 0,
                ),
                Step(
                  title: const Text('Photos & Documents'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(false),
                        icon: const Icon(Icons.photo_camera),
                        label: Text(_hostelImageBytes == null ? 'Upload Hostel Photo' : 'Hostel Photo ✓'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(true),
                        icon: const Icon(Icons.description),
                        label: Text(_paperImageBytes == null ? 'Upload Registration Paper' : 'Paper Uploaded ✓'),
                      ),
                    ],
                  ),
                  isActive: _currentStep >= 1,
                ),
                Step(
                  title: const Text('Floors'),
                  content: Column(
                    children: [
                      const Text('How many floors?'),
                      Slider(
                        value: _floorCount.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _floorCount.toString(),
                        onChanged: (val) => setState(() => _floorCount = val.toInt()),
                      ),
                      Text('$_floorCount Floors selected'),
                    ],
                  ),
                  isActive: _currentStep >= 2,
                ),
                Step(
                  title: const Text('Rooms per Floor'),
                  content: Column(
                    children: List.generate(_floorCount, (index) {
                      int floorNum = index + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TextFormField(
                          initialValue: (_roomsPerFloor[floorNum] ?? 10).toString(),
                          decoration: InputDecoration(labelText: 'Rooms on Floor $floorNum'),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            _roomsPerFloor[floorNum] = int.tryParse(val) ?? 0;
                          },
                        ),
                      );
                    }),
                  ),
                  isActive: _currentStep >= 3,
                ),
                Step(
                  title: const Text('Summary'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: ${_nameController.text}'),
                      Text('Location: ${_locationController.text}'),
                      Text('Rent: Rs.${_rentController.text}/month'),
                      Text('Total Floors: $_floorCount'),
                      const SizedBox(height: 8),
                      const Text(
                        'Submission goes to Platform Admin for approval before wardens can see it.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ],
                  ),
                  isActive: _currentStep >= 4,
                ),
              ],
            ),
    );
  }

  Future<void> _submit() async {
    for (int i = 1; i <= _floorCount; i++) {
      if (!_roomsPerFloor.containsKey(i)) _roomsPerFloor[i] = 10;
    }

    final rent = double.tryParse(_rentController.text.trim()) ?? 25000;
    final hostelId = 'H${DateTime.now().millisecondsSinceEpoch}';

    setState(() => _isSubmitting = true);

    try {
      String? photoUrl;
      String? paperUrl;

      if (SupabaseConfig.isConfigured) {
        photoUrl = await SupabaseStorageService.uploadHostelPhoto(_hostelImageBytes!, hostelId);
        paperUrl = await SupabaseStorageService.uploadHostelPaper(_paperImageBytes!, hostelId);
      }

      if (!mounted) return;

      Provider.of<AppState>(context, listen: false).submitHostelForApproval(
        _nameController.text.trim(),
        _locationController.text.trim(),
        _floorCount,
        _roomsPerFloor,
        rentPerMonth: rent,
        hostelId: hostelId,
        hostelImageUrl: photoUrl,
        paperImageUrl: paperUrl,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SupabaseConfig.isConfigured
                ? 'Hostel submitted — photos uploaded, pending admin approval.'
                : 'Hostel submitted — add Supabase keys in supabase_config.dart to upload photos.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
