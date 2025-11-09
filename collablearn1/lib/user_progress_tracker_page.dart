// lib/user_progress_tracker_page.dart - MODIFIED FOR PER-CLASS ATTENDANCE

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- NEW Data Model for Per-Class Attendance ---
class ClassAttendanceSummary {
  final String classId;
  final String className;
  final int totalSessions;
  final int attendedSessions;
  final int? percentage; // Changed to nullable int
  final String displayPercentage; // New field for UI display

  ClassAttendanceSummary({
    required this.classId,
    required this.className,
    required this.totalSessions,
    required this.attendedSessions,
    required this.percentage,
    required this.displayPercentage, // Required new field
  });
}
// ---------------------------------------------

class UserProgressTrackerPage extends StatefulWidget {
  const UserProgressTrackerPage({super.key});

  @override
  State<UserProgressTrackerPage> createState() => _UserProgressTrackerPageState();
}

class _UserProgressTrackerPageState extends State<UserProgressTrackerPage> {
  bool _isLoading = true;
  String _userName = 'User';

  // State variables for dynamic metrics
  int _overallAttendancePercentage = 0; // Renamed for clarity
  String _overallAttendanceDisplay = 'N/A'; // New state for overall display
  int _quizAverage = 0;
  int _goalProgress = 0;
  final int _goalTarget = 85; // Original Target for General Goal
  final int _attendanceTarget = 70; // New target for overall attendance
  
  // --- NEW STATE VARIABLE for Per-Class Attendance ---
  List<ClassAttendanceSummary> _classAttendance = [];
  // ----------------------------------------------------

  // Dynamic list for Performance Overview/Mid Exams
  List<Map<String, dynamic>> _midExamPerformance = [];

  @override
  void initState() {
    super.initState();
    _fetchPerformanceData();
  }
  
  // --- NEW FUNCTION: Fetch & Calculate Per-Class Attendance ---
  Future<List<ClassAttendanceSummary>> _fetchClassAttendance(String userId, List<dynamic> classIds) async {
    List<ClassAttendanceSummary> summaries = [];
    final firestore = FirebaseFirestore.instance;

    for (var classId in classIds) {
      if (classId is! String || classId.isEmpty) continue;

      // 1. Get Class Name
      final classDoc = await firestore.collection('classes').doc(classId).get();
      final className = classDoc.data()?['className'] ?? 'Unknown Class';
      
      // 2. Count Total Sessions for this class (that have ended)
      final totalSessionsSnapshot = await firestore
          .collection('attendance_sessions')
          .where('courseId', isEqualTo: classId)
          .count()
          .get();
      final totalSessions = totalSessionsSnapshot.count ?? 0;
      
      // 3. Count Attended Sessions by the user
      final attendedRecordsSnapshot = await firestore
          .collection('attendance_records')
          .where('courseId', isEqualTo: classId)
          .where('studentId', isEqualTo: userId)
          .count()
          .get();
      final attendedSessions = attendedRecordsSnapshot.count ?? 0;
      
      // 4. Calculate Percentage (Return null if no sessions were held)
      final int? percentage = totalSessions > 0 
          ? ((attendedSessions / totalSessions) * 100).round()
          : null;
      
      final String displayPercentage = percentage == null ? 'N/A' : '$percentage%';

      summaries.add(ClassAttendanceSummary(
        classId: classId,
        className: className,
        totalSessions: totalSessions,
        attendedSessions: attendedSessions,
        percentage: percentage,
        displayPercentage: displayPercentage, // Store the display value
      ));
    }
    
    // Calculate the overall average based ONLY on classes that have sessions
    final validPercentages = summaries
        .where((s) => s.percentage != null)
        .map((s) => s.percentage!)
        .toList();
        
    final overallAvg = validPercentages.isNotEmpty
      ? (validPercentages.reduce((a, b) => a + b) / validPercentages.length).round()
      : null; // Return null if no classes have sessions
      
    if (mounted) {
      setState(() {
        _overallAttendancePercentage = overallAvg ?? 0;
        _overallAttendanceDisplay = overallAvg == null ? 'N/A' : '$overallAvg%';
      });
    }

    return summaries;
  }
  // -----------------------------------------------------------


  Future<void> _fetchPerformanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Load User Data (Name and Enrolled Classes)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      List<dynamic> classIds = [];
      if (userDoc.exists) {
        final data = userDoc.data();
        final firstName = data?['firstName'] ?? '';
        final lastName = data?['lastName'] ?? '';
        if (mounted) {
          setState(() {
            _userName = (firstName.isNotEmpty || lastName.isNotEmpty) ? '$firstName $lastName' : user.displayName ?? 'User';
          });
        }
        
        if (data != null && data.containsKey('enrolledClasses') && data['enrolledClasses'] is List) {
            classIds = List<String>.from(data['enrolledClasses']);
        }
      }
      
      // --- MODIFIED STEP: Fetch overall attendance and per-class summary ---
      final classAttendanceSummary = await _fetchClassAttendance(user.uid, classIds);
      // We rely on _fetchClassAttendance to set _overallAttendancePercentage and _overallAttendanceDisplay
      
      // 2. Fetch Overall Progress Data from 'progress_tracker'
      final progressDoc = await FirebaseFirestore.instance
          .collection('progress_tracker')
          .doc(user.uid)
          .get();

      // 3. Fetch Mid Exam Performance Data from a sub-collection (e.g., 'exams')
      final examsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('exams')
          .get();
      
      final dynamicExams = examsSnapshot.docs.map((doc) => doc.data()).toList();


      if (progressDoc.exists || dynamicExams.isNotEmpty) {
        final data = progressDoc.data();
        if (mounted) {
          setState(() {
            _classAttendance = classAttendanceSummary; // Set new state variable
            _quizAverage = data?['overallQuizAverage'] as int? ?? 87; 
            _goalProgress = data?['overallGoalProgress'] as int? ?? 82;

            // Exam Performance (Dynamic)
            if (dynamicExams.isNotEmpty) {
              _midExamPerformance = dynamicExams.map((examData) => {
                'subject': examData['subject'] as String? ?? 'N/A',
                'score': examData['score'] as int? ?? 0,
              }).toList();
            } else {
              // Use Figma placeholders if no dynamic data found
              _midExamPerformance = [
                {'subject': 'Mathematics', 'score': 78},
                {'subject': 'DSA', 'score': 55},
                {'subject': 'Computer System', 'score': 55},
              ];
            }
          });
        }
      } else {
         // Use default Figma values if no progress document exists
         if (mounted) {
           setState(() {
             _classAttendance = classAttendanceSummary; // Set new state variable
             _quizAverage = 87;
             _goalProgress = 82;
             _midExamPerformance = [
                {'subject': 'Mathematics', 'score': 78},
                {'subject': 'DSA', 'score': 55},
                {'subject': 'Computer System', 'score': 55},
              ];
           });
         }
      }

    } catch (e) {
      debugPrint('Error fetching performance data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Welcome Banner ---
                  Text(
                    'Welcome! $_userName',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Ready to achieve your goals today?',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 25),

                  // --- NEW SECTION: Overall Attendance Goal Tracker ---
                  _buildAttendanceGoalTracker(primaryColor),
                  const SizedBox(height: 30),
                  
                  // --- NEW SECTION: Per-Class Attendance Summary ---
                  _buildPerClassAttendanceSummary(primaryColor),
                  const SizedBox(height: 30),
                  
                  // --- Quiz Average Card ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMetricCard(
                        context,
                        title: 'Quiz Average',
                        value: '$_quizAverage%',
                        feedback: _quizAverage >= 80 ? 'Excellent work' : 'Keep practicing', 
                        icon: Icons.quiz_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // --- Performance Overview (Mid Exams) ---
                  const Text(
                    'Performance Overview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(thickness: 1),
                  ..._midExamPerformance.map((exam) => _buildExamProgress(
                        exam['subject'],
                        exam['score'],
                        primaryColor,
                      )),
                  const SizedBox(height: 30),

                  // --- Goal Progress Tracker (Original) ---
                  _buildGoalProgress(primaryColor),
                ],
              ),
            ),
    );
  }

  // --- NEW WIDGET: Per-Class Attendance Summary ---
  Widget _buildPerClassAttendanceSummary(Color primaryColor) {
    if (_classAttendance.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Class Attendance Summary',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Divider(thickness: 1),
        // Use Column/ListView.builder with shrinkWrap/physics for scrolling compatibility
        Column(
          children: _classAttendance.map((summary) => _buildClassAttendanceTile(summary, primaryColor)).toList(),
        ),
      ],
    );
  }
  
  Widget _buildClassAttendanceTile(ClassAttendanceSummary summary, Color primaryColor) {
    // --- FIX: Check for null percentage before calculating isSafe ---
    final bool isSafe = summary.percentage != null && summary.percentage! >= _attendanceTarget;
    final Color color = summary.percentage == null ? Colors.grey : (isSafe ? Colors.green : Colors.red);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Text(
            summary.displayPercentage, // Use the pre-formatted display string
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)
          ),
        ),
        title: Text(
          summary.className,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          // Display session count only if sessions exist
          summary.totalSessions > 0 
            ? 'Attended ${summary.attendedSessions} of ${summary.totalSessions} sessions.'
            : 'No attendance sessions held.',
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Icon(
          summary.percentage == null ? Icons.info_outline : (isSafe ? Icons.check_circle : Icons.warning),
          color: color,
        ),
      ),
    );
  }
  // --- END NEW WIDGET: Per-Class Attendance Summary ---


  // --- WIDGET: Combined Attendance Goal Tracker (Renamed from _attendancePercentage to _overallAttendancePercentage) ---
  Widget _buildAttendanceGoalTracker(Color primaryColor) {
    // --- FIX: Check if overall data is N/A ---
    final bool isDataAvailable = _overallAttendanceDisplay != 'N/A';
    final int percentage = _overallAttendancePercentage;
    final bool isSafe = percentage >= _attendanceTarget;
    final Color progressColor = isDataAvailable ? (isSafe ? Colors.green : Colors.red) : Colors.grey;
    final String feedback;
    
    if (!isDataAvailable) {
        feedback = 'ℹ️ Data N/A: No attendance sessions have been held across your enrolled classes yet.';
    } else {
        feedback = isSafe 
            ? '✅ Excellent! Your attendance is above the required minimum.' 
            : '⚠️ Warning: You need to attend more classes to reach the 70% minimum.';
    }
    // ------------------------------------------
        
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overall Attendance Goal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                        // Value is 0.0 if N/A, otherwise the actual ratio
                        value: isDataAvailable ? (percentage / 100.0).clamp(0.0, 1.0) : 0.0, 
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        strokeWidth: 8,
                      ),
                    ),
                    Text(
                      _overallAttendanceDisplay, // Use the new display string
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: progressColor)
                    ), 
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target: $_attendanceTarget%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        feedback,
                        style: TextStyle(fontSize: 14, color: isDataAvailable ? (isSafe ? Colors.green.shade700 : Colors.red.shade700) : Colors.grey.shade700),
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
  // --- END WIDGET: Combined Attendance Goal Tracker ---


  // --- MODIFIED _buildMetricCard (Only for Quiz Average) ---
  Widget _buildMetricCard(BuildContext context, {required String title, required String value, required String feedback, required IconData icon}) {
    final bool isPositive = _quizAverage >= 80;
    final Color iconColor = isPositive ? Colors.green : Colors.orange;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(feedback, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
  // --- END MODIFIED _buildMetricCard ---

  Widget _buildExamProgress(String subject, int score, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Mid Exam: $subject', style: const TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('$score%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score / 100.0,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(score > 70 ? Colors.green : Colors.orange),
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoalProgress(Color primaryColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.track_changes, color: primaryColor, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Goal Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Target: $_goalTarget%', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: _goalProgress / 100.0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    strokeWidth: 6,
                  ),
                ),
                Text('$_goalProgress%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}