// lib/user_progress_tracker_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Data Models ---

class ClassAttendanceSummary {
  final String classId;
  final String className;
  final int totalSessions;
  final int attendedSessions;
  final int? percentage;
  final String displayPercentage;

  ClassAttendanceSummary({
    required this.classId,
    required this.className,
    required this.totalSessions,
    required this.attendedSessions,
    required this.percentage,
    required this.displayPercentage,
  });
}

class GradedItem {
  final String title;
  final String type; // 'Assignment' or 'Quiz'
  final int score;
  final int maxScore;
  final double percentage;

  GradedItem({
    required this.title,
    required this.type,
    required this.score,
    required this.maxScore,
  }) : percentage = maxScore > 0 ? (score / maxScore) : 0.0;
}

class UserProgressTrackerPage extends StatefulWidget {
  const UserProgressTrackerPage({super.key});

  @override
  State<UserProgressTrackerPage> createState() => _UserProgressTrackerPageState();
}

class _UserProgressTrackerPageState extends State<UserProgressTrackerPage> {
  bool _isLoading = true;
  String _userName = 'Student';
  
  // --- Metrics State ---
  int _overallAttendancePercentage = 0;
  String _overallAttendanceDisplay = 'N/A';
  
  int _quizAverage = 0;
  bool _hasQuizData = false;

  int _assignmentCompletionRate = 0; // Replaces "Goal Progress"
  
  List<ClassAttendanceSummary> _classAttendance = [];
  List<GradedItem> _recentGrades = []; // Replaces static "Mid Exams"

  // Thresholds
  final int _attendanceTarget = 70;

  @override
  void initState() {
    super.initState();
    _fetchDynamicData();
  }

  Future<void> _fetchDynamicData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      // 1. Fetch User Profile & Enrolled Classes
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      
      final firstName = userData?['firstName'] ?? '';
      final lastName = userData?['lastName'] ?? '';
      List<String> enrolledClassIds = [];
      
      if (userData != null && userData['enrolledClasses'] is List) {
        enrolledClassIds = List<String>.from(userData['enrolledClasses']);
      }

      if (mounted) {
        setState(() {
          _userName = (firstName.isNotEmpty || lastName.isNotEmpty) 
              ? '$firstName $lastName' 
              : user.email ?? 'Student';
        });
      }

      // 2. Calculate Attendance (Per Class & Overall)
      await _calculateAttendance(user.uid, enrolledClassIds);

      // 3. Calculate Academic Performance (Quizzes & Assignments)
      await _calculateAcademicPerformance(user.uid, enrolledClassIds);

    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateAttendance(String userId, List<String> classIds) async {
    List<ClassAttendanceSummary> summaries = [];
    List<int> validPercentages = [];

    for (var classId in classIds) {
      if (classId.isEmpty) continue;

      // Fetch Class Name
      final classDoc = await FirebaseFirestore.instance.collection('classes').doc(classId).get();
      final className = classDoc.data()?['className'] ?? 'Unknown Class';

      // Count Sessions
      final totalSessionsSnapshot = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .where('courseId', isEqualTo: classId)
          .count()
          .get();
      final totalSessions = totalSessionsSnapshot.count ?? 0;

      // Count Attended
      final attendedSnapshot = await FirebaseFirestore.instance
          .collection('attendance_records')
          .where('courseId', isEqualTo: classId)
          .where('studentId', isEqualTo: userId)
          .count()
          .get();
      final attendedSessions = attendedSnapshot.count ?? 0;

      int? percentage;
      String display = 'N/A';

      if (totalSessions > 0) {
        percentage = ((attendedSessions / totalSessions) * 100).round();
        display = '$percentage%';
        validPercentages.add(percentage);
      }

      summaries.add(ClassAttendanceSummary(
        classId: classId,
        className: className,
        totalSessions: totalSessions,
        attendedSessions: attendedSessions,
        percentage: percentage,
        displayPercentage: display,
      ));
    }

    // Calculate Overall Average
    int? overallAvg;
    if (validPercentages.isNotEmpty) {
      overallAvg = (validPercentages.reduce((a, b) => a + b) / validPercentages.length).round();
    }

    if (mounted) {
      setState(() {
        _classAttendance = summaries;
        _overallAttendancePercentage = overallAvg ?? 0;
        _overallAttendanceDisplay = overallAvg == null ? 'N/A' : '$overallAvg%';
      });
    }
  }

  Future<void> _calculateAcademicPerformance(String userId, List<String> classIds) async {
    if (classIds.isEmpty) return;

    // --- A. QUIZ METRICS ---
    // 1. Get all quizzes for enrolled classes
    // Firestore whereIn is limited to 10, so we loop or assume <10 for now. 
    // For robustness, we'll chunk or loop. Here we loop for simplicity.
    
    num totalQuizScore = 0;
    num totalQuizMax = 0;
    List<GradedItem> recentGrades = [];

    // Fetch Quizzes
    final quizSnapshots = await FirebaseFirestore.instance
        .collection('quizzes')
        .where('courseId', whereIn: classIds.take(10).toList()) // Limit 10 for safety
        .get();

    for (var quizDoc in quizSnapshots.docs) {
      final quizId = quizDoc.id;
      final quizData = quizDoc.data();
      
      // Check if student submitted
      final subDoc = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(quizId)
          .collection('submissions')
          .doc(userId)
          .get();

      if (subDoc.exists) {
        final subData = subDoc.data()!;
        final score = subData['score'] as int? ?? 0;
        final max = subData['maxScore'] as int? ?? 100;

        totalQuizScore += score;
        totalQuizMax += max;

        recentGrades.add(GradedItem(
          title: quizData['title'] ?? 'Quiz',
          type: 'Quiz',
          score: score,
          maxScore: max,
        ));
      }
    }

    // --- B. ASSIGNMENT METRICS ---
    int totalAssignmentsAssigned = 0;
    int totalAssignmentsSubmitted = 0;

    // Fetch Assignments
    final assignSnapshots = await FirebaseFirestore.instance
        .collection('assignments')
        .where('courseId', whereIn: classIds.take(10).toList())
        .get();

    totalAssignmentsAssigned = assignSnapshots.docs.length;

    for (var assignDoc in assignSnapshots.docs) {
      final assignId = assignDoc.id;
      final assignData = assignDoc.data();
      final maxPoints = assignData['points'] as int? ?? 100;

      // Check submission
      final subQuery = await FirebaseFirestore.instance
          .collection('assignment_submissions')
          .where('assignmentId', isEqualTo: assignId)
          .where('studentId', isEqualTo: userId)
          .limit(1)
          .get();

      if (subQuery.docs.isNotEmpty) {
        totalAssignmentsSubmitted++;
        final subData = subQuery.docs.first.data();
        
        // If graded, add to recent grades list
        if (subData['graded'] == true || subData['isGraded'] == true) {
           final score = subData['score'] as int? ?? 0;
           recentGrades.add(GradedItem(
             title: assignData['title'] ?? 'Assignment',
             type: 'Assignment',
             score: score,
             maxScore: maxPoints,
           ));
        }
      }
    }

    // Calculate Results
    int quizAvg = 0;
    if (totalQuizMax > 0) {
      quizAvg = ((totalQuizScore / totalQuizMax) * 100).round();
    }

    int assignmentRate = 0;
    if (totalAssignmentsAssigned > 0) {
      assignmentRate = ((totalAssignmentsSubmitted / totalAssignmentsAssigned) * 100).round();
    }

    if (mounted) {
      setState(() {
        _quizAverage = quizAvg;
        _hasQuizData = totalQuizMax > 0;
        _assignmentCompletionRate = assignmentRate;
        // Show last 5 graded items
        _recentGrades = recentGrades.take(5).toList(); 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Dashboard'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDynamicData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Welcome Banner
                    Text(
                      'Welcome, $_userName!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Here is your real-time academic progress.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 25),

                    // 2. Attendance Section
                    _buildAttendanceGoalTracker(primaryColor),
                    const SizedBox(height: 30),
                    _buildPerClassAttendanceSummary(primaryColor),
                    const SizedBox(height: 30),
                    
                    // 3. Quiz Average
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: 'Quiz Average',
                            value: _hasQuizData ? '$_quizAverage%' : 'N/A',
                            feedback: !_hasQuizData 
                                ? 'No quizzes taken yet.' 
                                : (_quizAverage >= 80 ? 'Great job!' : 'Keep practicing.'),
                            icon: Icons.quiz_outlined,
                            isPositive: _quizAverage >= 75,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: 'Assignments Done',
                            value: '$_assignmentCompletionRate%',
                            feedback: 'Submission Rate',
                            icon: Icons.assignment_turned_in,
                            isPositive: _assignmentCompletionRate >= 80,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 4. Recent Graded Items (Dynamic replacement for Mid Exams)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Graded Work',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (_recentGrades.isNotEmpty)
                          Text(
                            'Last ${_recentGrades.length}', 
                            style: const TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                    const Divider(thickness: 1),
                    
                    if (_recentGrades.isEmpty)
                       const Padding(
                         padding: EdgeInsets.symmetric(vertical: 20.0),
                         child: Center(child: Text('No graded assignments or quizzes yet.')),
                       )
                    else
                      ..._recentGrades.map((item) => _buildGradedItemRow(item, primaryColor)).toList(),

                    const SizedBox(height: 30),

                    // 5. Assignment Completion Goal
                    _buildCompletionGoalTracker(primaryColor),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // --- Widgets ---

  Widget _buildAttendanceGoalTracker(Color primaryColor) {
    final bool isDataAvailable = _overallAttendanceDisplay != 'N/A';
    final int percentage = _overallAttendancePercentage;
    final bool isSafe = percentage >= _attendanceTarget;
    final Color progressColor = isDataAvailable ? (isSafe ? Colors.green : Colors.red) : Colors.grey;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overall Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: isDataAvailable ? (percentage / 100.0).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        strokeWidth: 8,
                      ),
                    ),
                    Text(
                      _overallAttendanceDisplay,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: progressColor),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Target: $_attendanceTarget%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(
                        isDataAvailable 
                           ? (isSafe ? 'You are on track!' : 'Attendance is below target.') 
                           : 'No attendance data yet.',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerClassAttendanceSummary(Color primaryColor) {
    if (_classAttendance.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Class Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Column(
          children: _classAttendance.map((summary) {
            final bool isSafe = summary.percentage != null && summary.percentage! >= _attendanceTarget;
            final Color color = summary.percentage == null ? Colors.grey : (isSafe ? Colors.green : Colors.orange);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Text(summary.displayPercentage, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                ),
                title: Text(summary.className, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${summary.attendedSessions}/${summary.totalSessions} Sessions'),
                trailing: Icon(
                  summary.percentage == null ? Icons.hourglass_empty : (isSafe ? Icons.check_circle : Icons.warning),
                  color: color,
                  size: 20,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, {
    required String title, 
    required String value, 
    required String feedback, 
    required IconData icon,
    required bool isPositive
  }) {
    final Color color = isPositive ? Colors.green : Colors.orange;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(feedback, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildGradedItemRow(GradedItem item, Color primaryColor) {
    final bool isGreat = item.percentage >= 0.8;
    final bool isGood = item.percentage >= 0.5;
    final Color color = isGreat ? Colors.green : (isGood ? Colors.orange : Colors.red);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.type == 'Quiz' ? Icons.timer : Icons.assignment, 
                size: 18, 
                color: Colors.grey
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              Text(
                '${item.score}/${item.maxScore}', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: item.percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionGoalTracker(Color primaryColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.task_alt, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assignment Completion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Percentage of tasks submitted', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    value: _assignmentCompletionRate / 100.0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    strokeWidth: 5,
                  ),
                ),
                Text('$_assignmentCompletionRate%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}