import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face/services/student_service.dart';
import 'package:face/services/class_service.dart';
import 'package:face/models/student.dart';
import 'package:face/models/class.dart';
import 'package:shimmer/shimmer.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final StudentService _studentService = StudentService();
  final ClassService _classService = ClassService();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Cache for attendance data
  final Map<String, Map<String, dynamic>> _attendanceCache = {};

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registered Students'),
        elevation: 0,
      ),
      body: StreamBuilder<List<Class>>(
        stream: _classService.getClassesByTeacher(currentUser!.uid),
        builder: (context, classSnapshot) {
          if (classSnapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingShimmer();
          }

          if (classSnapshot.hasError) {
            return Center(
              child: Text('Error: ${classSnapshot.error}'),
            );
          }

          final classes = classSnapshot.data ?? [];

          if (classes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.class_,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No classes found',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create a class first to see students',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final classData = classes[index];
              return _buildClassStudentsCard(context, classData);
            },
          );
        },
      ),
    );
  }

  Widget _buildClassStudentsCard(BuildContext context, Class classData) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.class_,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classData.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

           Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<List<Student>>(
              stream: _studentService.getStudentsByClass(classData.id),
              builder: (context, studentSnapshot) {
                if (studentSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildStudentShimmer();
                }

                if (studentSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Error: ${studentSnapshot.error}'),
                    ),
                  );
                }

                final students = studentSnapshot.data ?? [];

                if (students.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No registered students',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                     Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${students.length} Student${students.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                     ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: students.length,
                      separatorBuilder: (context, index) =>
                          Divider(color: Colors.grey[200]),
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return _buildStudentTile(context, student);
                      },
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

  Widget _buildStudentTile(BuildContext context, Student student) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getStudentAttendanceStats(student.id, student.classId),
      builder: (context, snapshot) {
        final attendanceData = snapshot.data ?? {};
        final lastAttendance = attendanceData['lastAttendance'] as DateTime?;
        final totalPresent = attendanceData['totalPresent'] as int? ?? 0;
        final totalClasses = attendanceData['totalClasses'] as int? ?? 0;
        final attendanceRate = totalClasses > 0 
            ? (totalPresent / totalClasses * 100).toStringAsFixed(1)
            : '0.0';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getStudentAvatarColor(student.name),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            title: Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.enrollmentNumber,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStatusChip(
                      attendanceRate: double.tryParse(attendanceRate) ?? 0,
                    ),
                    const SizedBox(width: 8),
                    if (lastAttendance != null)
                      Text(
                        'Last: ${_formatDate(lastAttendance)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(Icons.email_outlined, 'Email', student.email),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      Icons.calendar_today_outlined,
                      'Registered',
                      _formatDate(student.registeredAt),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      Icons.check_circle_outline,
                      'Classes Attended',
                      '$totalPresent / $totalClasses',
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      Icons.percent,
                      'Attendance Rate',
                      '$attendanceRate%',
                    ),
                    const SizedBox(height: 8),
                    if (lastAttendance != null)
                      _buildDetailRow(
                        Icons.access_time,
                        'Last Attendance',
                        _formatDateTime(lastAttendance),
                      )
                    else
                      _buildDetailRow(
                        Icons.warning_amber_outlined,
                        'Status',
                        'No attendance record',
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip({required double attendanceRate}) {
    Color chipColor;
    String status;
    if (attendanceRate >= 75) {
      chipColor = Colors.green;
      status = 'Good';
    } else if (attendanceRate >= 50) {
      chipColor = Colors.orange;
      status = 'Average';
    } else {
      chipColor = Colors.red;
      status = 'Low';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$attendanceRate% $status',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: chipColor,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getStudentAttendanceStats(
    String studentId,
    String classId,
  ) async {
    final cacheKey = '$studentId-$classId';
    
    if (_attendanceCache.containsKey(cacheKey)) {
      return _attendanceCache[cacheKey]!;
    }

    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      // Get attendance records for the student in this class
      final attendanceDocs = await _db
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('classId', isEqualTo: classId)
          .where('date', isGreaterThanOrEqualTo: 
              Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final totalPresent = attendanceDocs.docs
          .where((doc) => doc.data()['status'] == 'present')
          .length;
      final totalClasses = attendanceDocs.docs.length;

      // Get last attendance date
      DateTime? lastAttendance;
      if (attendanceDocs.docs.isNotEmpty) {
        final sortedDocs = attendanceDocs.docs.toList()
          ..sort((a, b) {
            final dateA = (a.data()['date'] as Timestamp?)?.toDate();
            final dateB = (b.data()['date'] as Timestamp?)?.toDate();
            return (dateB ?? DateTime.now()).compareTo(dateA ?? DateTime.now());
          });
        lastAttendance = (sortedDocs.first.data()['date'] as Timestamp?)?.toDate();
      }

      final result = {
        'totalPresent': totalPresent,
        'totalClasses': totalClasses,
        'lastAttendance': lastAttendance,
      };

      _attendanceCache[cacheKey] = result;
      return result;
    } catch (e) {
      return {
        'totalPresent': 0,
        'totalClasses': 0,
        'lastAttendance': null,
      };
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentShimmer() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }

  Color _getStudentAvatarColor(String name) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.amber,
    ];
    final hash = name.hashCode % colors.length;
    return colors[hash];
  }
}
