import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:face/services/auth_service.dart';
import 'package:face/screens/student_registration_page.dart';
import 'package:face/screens/teacher/class_management_screen.dart';
import 'package:face/screens/teacher/attendance_report_screen.dart';
import 'package:face/screens/teacher/student_list_screen.dart';
import 'package:face/services/student_service.dart';
import 'package:face/services/class_service.dart';
import 'package:face/models/student.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:page_transition/page_transition.dart';
import 'package:vibration/vibration.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AuthService _authService = AuthService();
  final StudentService _studentService = StudentService();
  final ClassService _classService = ClassService();
  
  int totalStudents = 0;
  int presentToday = 0;
  int absentToday = 0;
  int totalClasses = 0;
  bool _isLoadingStats = true;
  List<Map<String, dynamic>> _topStudents = [];
  bool _isLoadingTopStudents = true;

  @override
  void initState() {
    super.initState();
    _loadAttendanceStats();
  }

  Future<void> _loadAttendanceStats() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Get attendance stats
      final stats = await _studentService.getTeacherAttendanceStats(currentUser.uid);
      
      // Get class count
      final classes = await _classService.getClassesByTeacher(currentUser.uid).first;
      
      // Get top students
      final topStudents = await _studentService.getTopStudents(currentUser.uid, limit: 3);
      
      if (mounted) {
        setState(() {
          totalStudents = stats['totalStudents'] ?? 0;
          presentToday = stats['presentToday'] ?? 0;
          absentToday = stats['absentToday'] ?? 0;
          totalClasses = classes.length;
          _topStudents = topStudents;
          _isLoadingStats = false;
          _isLoadingTopStudents = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 235, 233, 234),
      appBar: AppBar(
        title: const Text('Attendance System '),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAttendanceStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header
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
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Teacher Dashboard",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentUser?.email ?? "",
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.analytics,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Today's Attendance",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _loadAttendanceStats,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isLoadingStats)
                          const Center(child: CircularProgressIndicator())
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                icon: Icons.people,
                                label: 'Total',
                                value: totalStudents.toString(),
                                color: Colors.blue,
                              ),
                              _buildStatItem(
                                icon: Icons.check_circle,
                                label: 'Present',
                                value: presentToday.toString(),
                                color: Colors.green,
                              ),
                              _buildStatItem(
                                icon: Icons.cancel,
                                label: 'Absent',
                                value: absentToday.toString(),
                                color: Colors.red,
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        // Progress bar showing attendance percentage
                        if (totalStudents > 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: totalStudents > 0 ? presentToday / totalStudents : 0,
                              minHeight: 10,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                presentToday / totalStudents >= 0.75 
                                    ? Colors.green 
                                    : presentToday / totalStudents >= 0.5 
                                        ? Colors.orange 
                                        : Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            totalStudents > 0 
                                ? '${(presentToday / totalStudents * 100).toStringAsFixed(1)}% Attendance Rate'
                                : 'No students registered',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn().slideY(begin: -0.1),

              const SizedBox(height: 16),

              // Quick Stats Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildQuickStatCard(
                        icon: Icons.school,
                        label: 'Total Students',
                        value: totalStudents.toString(),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickStatCard(
                        icon: Icons.class_,
                        label: 'Classes',
                        value: totalClasses.toString(),
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Top Students Ranking Card
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.emoji_events,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Top Performers',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Last 30 days',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isLoadingTopStudents)
                          const Center(child: CircularProgressIndicator())
                        else if (_topStudents.isEmpty)
                          const Center(
                            child: Text(
                              'No student data available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          ...List.generate(_topStudents.length, (index) {
                            final studentData = _topStudents[index];
                            final student = studentData['student'] as Student;
                            final percentage = studentData['attendancePercentage'] as double;
                            final presentCount = studentData['presentCount'] as int;
                            final totalClasses = studentData['totalClasses'] as int;
                            
                            return _buildTopStudentTile(
                              rank: index + 1,
                              name: student.name,
                              enrollmentNumber: student.enrollmentNumber,
                              percentage: percentage,
                              presentCount: presentCount,
                              totalClasses: totalClasses,
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action Cards
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
                      icon: Icons.person_add_outlined,
                      title: 'Register Student',
                      subtitle: 'Add new student',
                      onTap: () {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.leftToRight,
                            child: const StudentRegistrationPage(),
                          ),
                        ).then((_) => _loadAttendanceStats());
                      },
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.class_outlined,
                      title: 'Manage Classes',
                      subtitle: 'Create & edit classes',
                      onTap: (){
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.rightToLeft,
                            child: const ClassManagementScreen(),
                          ),
                        ).then((_) => _loadAttendanceStats());
                      },
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.analytics_outlined,
                      title: 'Attendance Reports',
                      subtitle: 'View & export reports',
                      onTap: () {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.leftToRight,
                            child: const AttendanceReportScreen(),
                          ),
                        );
                      },
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.people_outline,
                      title: 'Student List',
                      subtitle: 'View all students & attendance',
                      onTap: () {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.rightToLeft,
                            child: const StudentListScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStudentTile({
    required int rank,
    required String name,
    required String enrollmentNumber,
    required double percentage,
    required int presentCount,
    required int totalClasses,
  }) {
    Color rankColor;
    IconData? rankIcon;
    
    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = Colors.grey.shade400;
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = Colors.brown.shade300;
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = Colors.blue;
        rankIcon = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rankColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rankColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rankColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: rankIcon != null 
                  ? Icon(rankIcon, color: Colors.white, size: 20)
                  : Text(
                      '#$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  enrollmentNumber,
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
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: percentage >= 75 ? Colors.green : percentage >= 50 ? Colors.orange : Colors.red,
                ),
              ),
              Text(
                '$presentCount/$totalClasses classes',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
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
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    )
    .animate()
    .fade(duration: 300.ms)
    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0));
  }

  void _showLogoutDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Logout",
      barrierColor: const Color.fromARGB(137, 226, 196, 196),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 10),
              Text("Logout"),
            ],
          ),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 240, 117, 108),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                bool? hasVibrator = await Vibration.hasVibrator();
                if (hasVibrator == true) {
                  Vibration.vibrate(duration: 100);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                await _authService.logout();
              },
              child: const Text("Logout"),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Transform.scale(
          scale: animation.value,
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
    );
  }
}

