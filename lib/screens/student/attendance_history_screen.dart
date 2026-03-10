import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:face/services/attendance_service.dart';
import 'package:face/models/attendance.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final AttendanceService _attendanceService = AttendanceService();
 

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        elevation: 0,
      ),
      body: StreamBuilder<List<Attendance>>(
        stream: _attendanceService.getStudentAttendance(currentUser!.uid),
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
              child: Text('No attendance records found'),
            );
          }

           final groupedAttendance = _groupAttendanceByMonth(attendance);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedAttendance.length,
            itemBuilder: (context, index) {
              final month = groupedAttendance.keys.elementAt(index);
              final monthAttendance = groupedAttendance[month]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      month,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  ...monthAttendance.map((record) => Card(
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
                          title: Text(
                            'Class: ${record.classId}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${record.date.day}/${record.date.month}/${record.date.year}',
                              ),
                              Text(
                                'Method: ${record.verificationMethod} • Confidence: ${(record.confidence * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: record.status == 'present'
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : record.status == 'late'
                                      ? Colors.orange.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              record.status.toUpperCase(),
                              style: TextStyle(
                                color: record.status == 'present'
                                    ? Colors.green
                                    : record.status == 'late'
                                        ? Colors.orange
                                        : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<Attendance>> _groupAttendanceByMonth(List<Attendance> attendance) {
    final grouped = <String, List<Attendance>>{};

    for (final record in attendance) {
      final monthName = _getMonthName(record.date.month);

      if (!grouped.containsKey(monthName)) {
        grouped[monthName] = [];
      }
      grouped[monthName]!.add(record);
    }

     for (final month in grouped.keys) {
      grouped[month]!.sort((a, b) => b.date.compareTo(a.date));
    }

    return grouped;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
