import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:face/services/attendance_service.dart';
import 'package:face/services/class_service.dart';
import 'package:face/models/attendance.dart';
import 'package:face/models/class.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final ClassService _classService = ClassService();

  String? _selectedClassId;
  DateTime _selectedDate = DateTime.now();
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Reports'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _selectedClassId != null ? _exportReport : null,
            tooltip: 'Export Report',
          ),
        ],
      ),
      body: Column(
        children: [
           Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<Class>>(
                    stream: _classService.getClassesByTeacher(currentUser!.uid),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return DropdownButtonFormField<String>(
                          value: _selectedClassId,
                          decoration: const InputDecoration(
                            labelText: 'Select Class',
                            border: OutlineInputBorder(),
                          ),
                          items: snapshot.data!.map((classData) {
                            return DropdownMenuItem(
                              value: classData.id,
                              child: Text('${classData.name} - ${classData.subject}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedClassId = value);
                          },
                        );
                      }
                      return const Text('No classes available');
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Select Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
           Expanded(
            child: _selectedClassId == null
                ? const Center(
                    child: Text('Please select a class to view attendance'),
                  )
                : StreamBuilder<List<Attendance>>(
                    stream: _attendanceService.getClassAttendance(
                      _selectedClassId!,
                      _selectedDate,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      final attendance = snapshot.data ?? [];

                      if (attendance.isEmpty) {
                        return const Center(
                          child: Text('No attendance records for selected date'),
                        );
                      }

                       final presentCount = attendance.where((a) => a.status == 'present').length;
                      final absentCount = attendance.where((a) => a.status == 'absent').length;
                      final lateCount = attendance.where((a) => a.status == 'late').length;

                      return Column(
                        children: [
                           Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _buildStatCard('Present', presentCount, Colors.green),
                                const SizedBox(width: 8),
                                _buildStatCard('Absent', absentCount, Colors.red),
                                const SizedBox(width: 8),
                                _buildStatCard('Late', lateCount, Colors.orange),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                           Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: attendance.length,
                              itemBuilder: (context, index) {
                                final record = attendance[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Icon(
                                      record.status == 'present'
                                          ? Icons.check_circle
                                          : record.status == 'late'
                                              ? Icons.schedule
                                              : Icons.cancel,
                                      color: record.status == 'present'
                                          ? Colors.green
                                          : record.status == 'late'
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                    title: Text('Student ID: ${record.studentId}'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Status: ${record.status.toUpperCase()}',
                                          style: TextStyle(
                                            color: record.status == 'present'
                                                ? Colors.green
                                                : record.status == 'late'
                                                    ? Colors.orange
                                                    : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Time: ${record.timestamp.hour}:${record.timestamp.minute.toString().padLeft(2, '0')} • Method: ${record.verificationMethod}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (record.confidence > 0)
                                          Text(
                                            'Confidence: ${(record.confidence * 100).toStringAsFixed(1)}%',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon!')),
    );
  }
}

