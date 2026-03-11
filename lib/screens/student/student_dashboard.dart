import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:face/services/auth_service.dart';
import 'package:face/services/attendance_service.dart';
import 'package:face/services/student_service.dart';
import 'package:face/services/class_service.dart';
import 'package:face/models/attendance.dart';
import 'package:face/models/class.dart';
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
  final StudentService _studentService = StudentService();
  final ClassService _classService = ClassService();

  int present = 0;
  int absent = 0;
  List<Class> enrolledClasses = [];
  bool _isLoadingClasses = true;
  Map<String, dynamic>? _studentRank;
  bool _isLoadingRank = true;

  double get attendancePercentage {
    final total = present + absent;
    if (total == 0) return 0;
    return (present / total) * 100;
  }

  @override
  void initState() {
    super.initState();
    _loadEnrolledClasses();
    _loadStudentRank();
  }

  Future<void> _loadEnrolledClasses() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Get student data using userId (auth user id)
      final student = await _studentService.getStudentByUserId(currentUser.uid);
      
      if (student != null && student.classId.isNotEmpty) {
        // Get the class details
        final classData = await _classService.getClassById(student.classId);
        
        if (mounted) {
          setState(() {
            if (classData != null) {
              enrolledClasses = [classData];
            }
            _isLoadingClasses = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingClasses = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingClasses = false;
        });
      }
    }
  }

  Future<void> _loadStudentRank() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final rankData = await _studentService.getStudentRank(currentUser.uid);
      
      if (mounted) {
        setState(() {
          _studentRank = rankData;
          _isLoadingRank = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRank = false;
        });
      }
    }
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
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadEnrolledClasses();
          await _loadStudentRank();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
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

              // Student Rank Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _isLoadingRank
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _studentRank != null
                            ? _buildRankCard()
                            : _buildNoRankCard(),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Enrolled Classes Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.school,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'My Classes',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _loadEnrolledClasses,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingClasses)
                          const Center(child: CircularProgressIndicator())
                        else if (enrolledClasses.isEmpty)
                          const Center(
                            child: Text(
                              'No classes enrolled',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: enrolledClasses.length,
                            itemBuilder: (context, index) {
                              final classItem = enrolledClasses[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.class_,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            classItem.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (classItem.subject.isNotEmpty)
                                            Text(
                                              classItem.subject,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          PageTransition(
                                            type: PageTransitionType.leftToRight,
                                            child: const FaceScanScreen(),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      child: const Text('Mark Attendance'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Attendance Stats Card
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

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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

              // Recent Attendance
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Attendance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 300, // Fixed height for the attendance list
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
                            shrinkWrap: true,
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankCard() {
    final rank = _studentRank!['rank'] as int;
    final totalStudents = _studentRank!['totalStudents'] as int;
    final percentage = _studentRank!['attendancePercentage'] as double;
    final presentCount = _studentRank!['presentCount'] as int;
    final totalClasses = _studentRank!['totalClasses'] as int;

    Color rankColor;
    IconData rankIcon;
    
    if (rank == 1) {
      rankColor = Colors.amber;
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey.shade400;
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = Colors.brown.shade300;
      rankIcon = Icons.emoji_events;
    } else {
      rankColor = Colors.blue;
      rankIcon = Icons.star;
    }

    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: rankColor,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Icon(rankIcon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rank #$rank',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                ),
              ),
              Text(
                'Out of $totalStudents students',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: percentage >= 75 ? Colors.green : percentage >= 50 ? Colors.orange : Colors.red,
              ),
            ),
            Text(
              '$presentCount/$totalClasses classes',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoRankCard() {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Center(
            child: Icon(Icons.emoji_events, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No Ranking Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Attend more classes to get ranked!',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
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

