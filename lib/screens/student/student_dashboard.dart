import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:face/services/auth_service.dart';
import 'package:face/services/attendance_service.dart';
import 'package:face/models/attendance.dart';
import 'package:face/screens/student/face_scan_screen.dart';
import 'package:face/screens/student/attendance_history_screen.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:page_transition/page_transition.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final AuthService _authService = AuthService();
  final AttendanceService _attendanceService = AttendanceService();

  int present = 0;
  int absent = 0;

  double get attendancePercentage {
    final total = present + absent;
    if (total == 0) return 0;
    return (present / total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEBEE),
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
      
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4F46E5),
                  Color(0xFF6366F1),
                ],
              ),
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Student Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currentUser?.email ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.2),

          const SizedBox(height: 10),

           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Attendance Rate',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${attendancePercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text('Present: $present'),
                        Text('Absent: $absent'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: attendancePercentage / 100,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
              ),
            ).animate().scale(),
          ),

          const SizedBox(height: 10),

           Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildActionCard(
                  context,
                  icon: Iconsax.camera,
                  title: 'Mark Attendance',
                  subtitle: 'Scan your face',
                  onTap: () {
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.leftToRight,
                        child: const FaceScanScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  icon: Iconsax.clock,
                  title: 'Attendance History',
                  subtitle: 'View your records',
                  onTap: () {
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.rightToLeft,
                        child: const AttendanceHistoryScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

           Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Attendance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<List<Attendance>>(
                      stream: _attendanceService.getStudentAttendance(
                        currentUser!.uid,
                        limit: 10,
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
                            child: Text('No attendance records'),
                          );
                        }

                         present = attendance.where((a) => a.status == 'present').length;
                        absent = attendance.where((a) => a.status != 'present').length;

                        return ListView.builder(
                          itemCount: attendance.length,
                          itemBuilder: (context, index) {
                            final record = attendance[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  record.status == 'present'
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: record.status == 'present'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                title: Text(
                                  'Class: ${record.classId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Date: ${record.date.toLocal().toString().split(' ')[0]} - Status: ${record.status}',
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

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _authService.logout();
              Navigator.of(ctx)
                  .pushNamedAndRemoveUntil('/', (route) => false);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
