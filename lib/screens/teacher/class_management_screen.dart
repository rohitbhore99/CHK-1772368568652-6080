import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:face/services/class_service.dart';
import 'package:face/models/class.dart';
import 'classroom_location_picker.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final ClassService _classService = ClassService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  Map<String, double>? _selectedLocation;
  String _locationDisplayText = 'GPS Location: Not set';
  final _subjectController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Management'),
        elevation: 0,
      ),
      body: Column(
        children: [
           Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Class',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Class Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter class name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // GPS Location Picker
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _locationDisplayText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_selectedLocation != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Lat: ${_selectedLocation!['lat']?.toStringAsFixed(4)}\n'
                                  'Lng: ${_selectedLocation!['lng']?.toStringAsFixed(4)}\n'
                                  'Radius: ${_selectedLocation!['radius']?.toStringAsFixed(1)}m',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _pickClassroomLocation,
                                icon: const Icon(Icons.gps_fixed),
                                label: const Text('Set GPS Location'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter subject';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createClass,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Create Class'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
           Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Classes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<List<Class>>(
                      stream: _classService.getClassesByTeacher(currentUser!.uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        final classes = snapshot.data ?? [];

                        if (classes.isEmpty) {
                          return const Center(
                            child: Text('No classes created yet'),
                          );
                        }

                        return ListView.builder(
                          itemCount: classes.length,
                          itemBuilder: (context, index) {
                            final classData = classes[index];
                            final hasLocation = classData.location.isNotEmpty &&
                                classData.location['lat'] != 0.0 &&
                                classData.location['lng'] != 0.0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                classData.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${classData.students.length} students',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () => deleteClass(
                                              classData.id, classData.name),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: hasLocation
                                            ? Colors.green.shade50
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: hasLocation
                                              ? Colors.green.shade300
                                              : Colors.orange.shade300,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 16,
                                                color: hasLocation
                                                    ? Colors.green.shade700
                                                    : Colors.orange.shade700,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                hasLocation
                                                    ? 'GPS Location: Configured ✓'
                                                    : 'GPS Location: Not Set',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: hasLocation
                                                      ? Colors.green.shade700
                                                      : Colors.orange.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (hasLocation) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'Lat: ${classData.location['lat']?.toStringAsFixed(4)}, '
                                              'Lng: ${classData.location['lng']?.toStringAsFixed(4)}\n'
                                              'Radius: ${classData.location['radius']?.toStringAsFixed(1)}m',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            editClassLocation(classData),
                                        icon: const Icon(Icons.edit_location),
                                        label: const Text(
                                            'Edit Location'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createClass() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set GPS location for the classroom')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final classData = Class(
        id: '',
        name: _nameController.text.trim(),
        teacherId: FirebaseAuth.instance.currentUser!.uid,
        subject: _subjectController.text.trim(),
        schedule: [],
        location: _selectedLocation!,
      );

      await _classService.createClass(classData);

      _nameController.clear();
      _subjectController.clear();
      setState(() {
        _selectedLocation = null;
        _locationDisplayText = 'GPS Location: Not set';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class created successfully with GPS location!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickClassroomLocation() async {
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (context) => ClassroomLocationPicker(
          initialLat: _selectedLocation?['lat'],
          initialLng: _selectedLocation?['lng'],
          initialRadius: _selectedLocation?['radius'] ?? 100.0,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result;
        _locationDisplayText =
            'GPS Location: Set ✓ (Lat: ${result['lat']!.toStringAsFixed(4)}, '
            'Lng: ${result['lng']!.toStringAsFixed(4)})';
      });
    }
  }

  Future<void> editClassLocation(Class classData) async {
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (context) => ClassroomLocationPicker(
          initialLat: classData.location['lat'],
          initialLng: classData.location['lng'],
          initialRadius: classData.location['radius'] ?? 100.0,
        ),
      ),
    );

    if (result != null) {
      try {
        await _classService.updateClass(classData.id, {
          'location': result,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Class location updated successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating location: $e')),
          );
        }
      }
    }
  }

  void deleteClass(String classId, String className) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Are you sure you want to delete "$className"? This will also delete all attendance records for this class.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _classService.deleteClass(classId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

