// lib/instructor_student_report_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InstructorStudentReportPage extends StatefulWidget {
  final String classId;
  final String studentId;
  final String studentName; 

  const InstructorStudentReportPage({
    super.key,
    required this.classId,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<InstructorStudentReportPage> createState() => _InstructorStudentReportPageState();
}

class _InstructorStudentReportPageState extends State<InstructorStudentReportPage> {
  final firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic> _reportData = {};
  
  // Reusing the target from user_progress_tracker_page for context
  static const int _attendanceTarget = 70; 

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    try {
      // Fetch all data sources concurrently
      final data = await Future.wait([
        _fetchStudentDetails(),
        _fetchAttendanceData(),
        _fetchQuizData(),
        _fetchAssignmentData(),
      ]);

      if (mounted) {
        setState(() {
          _reportData = {
            'studentDetails': data[0],
            'attendance': data[1],
            'quizzes': data[2],
            'assignments': data[3],
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching report data: $e');
      if (mounted) {
        // Show an error state if fetching fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load report: ${e.toString()}'), backgroundColor: Colors.red)
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, String>> _fetchStudentDetails() async {
    final userDoc = await firestore.collection('users').doc(widget.studentId).get();
    final data = userDoc.data();
    return {
      'entryNo': data?['entryNo'] ?? 'N/A',
      'email': data?['email'] ?? 'N/A',
    };
  }

  Future<Map<String, dynamic>> _fetchAttendanceData() async {
    // Count total sessions for this class
    final totalSessionsSnapshot = await firestore
        .collection('attendance_sessions')
        .where('courseId', isEqualTo: widget.classId)
        .count()
        .get();
    final totalSessions = totalSessionsSnapshot.count ?? 0;

    // Count attended sessions by the student
    final attendedRecordsSnapshot = await firestore
        .collection('attendance_records')
        .where('courseId', isEqualTo: widget.classId)
        .where('studentId', isEqualTo: widget.studentId)
        .count()
        .get();
    final attendedSessions = attendedRecordsSnapshot.count ?? 0;

    final num? percentage = totalSessions > 0
        ? ((attendedSessions / totalSessions) * 100).round()
        : null;

    return {
      'totalSessions': totalSessions,
      'attendedSessions': attendedSessions,
      'percentage': percentage,
    };
  }

  Future<Map<String, dynamic>> _fetchQuizData() async {
    // 1. Get all Quizzes for the class
    final quizzesSnapshot = await firestore
        .collection('quizzes')
        .where('courseId', isEqualTo: widget.classId)
        .orderBy('postedOn', descending: true)
        .get();

    final List<Map<String, dynamic>> quizReports = [];

    // Local accumulation variables
    num totalQuizMaxScore = 0;
    num totalQuizGainedScore = 0;

    for (var quizDoc in quizzesSnapshot.docs) {
      final quizData = quizDoc.data();
      final quizId = quizDoc.id;
      final maxScore = quizData['totalPoints'] ?? 0;

      // 2. Try to get the student's submission
      final submissionDoc = await firestore
          .collection('quizzes')
          .doc(quizId)
          .collection('submissions')
          .doc(widget.studentId)
          .get();

      final isSubmitted = submissionDoc.exists;
      final submissionData = submissionDoc.data();
      final score = isSubmitted && submissionData != null ? submissionData['score'] : null;
      final isGraded = score != null;
      
      if (isGraded) {
          totalQuizMaxScore += (maxScore as num);
          totalQuizGainedScore += (score as num);
      }

      quizReports.add({
        'title': quizData['title'] ?? 'Untitled Quiz',
        'quizId': quizId,
        'postedOn': (quizData['postedOn'] as Timestamp?)?.toDate(),
        'isSubmitted': isSubmitted,
        'score': score,
        'maxScore': maxScore,
        'scoreDisplay': isSubmitted ? (isGraded ? '$score / $maxScore' : 'Submitted') : 'Missing',
        'isGraded': isGraded,
      });
    }

    final int? quizPercentage = totalQuizMaxScore > 0 
      ? ((totalQuizGainedScore / totalQuizMaxScore) * 100).round()
      : null;

    return {
      'reports': quizReports,
      'overallQuizPercentage': quizPercentage, // New overall percentage field
    };
  }
  
  Future<Map<String, dynamic>> _fetchAssignmentData() async {
    // 1. Get all Assignments for the class
    final assignmentsSnapshot = await firestore
        .collection('assignments')
        .where('courseId', isEqualTo: widget.classId)
        .orderBy('dueDate', descending: true)
        .get();

    final List<Map<String, dynamic>> assignmentReports = [];
    // Using `num` for accumulation is safer as Firestore numbers can be int or double.
    num totalPossiblePointsSubmitted = 0;
    num totalGainedPoints = 0;
    int submittedCount = 0;
    int totalAssignments = assignmentsSnapshot.docs.length;

    for (var assignmentDoc in assignmentsSnapshot.docs) {
      final assignmentData = assignmentDoc.data();
      final assignmentId = assignmentDoc.id;
      
      // Ensure maxPoints is treated as num/int for later math
      final num maxPoints = (assignmentData['points'] as num?) ?? 0;

      // 2. Try to get the student's submission
      final submissionQuery = await firestore
          .collection('assignment_submissions')
          .where('assignmentId', isEqualTo: assignmentId)
          .where('studentId', isEqualTo: widget.studentId)
          .limit(1)
          .get();
      
      final isSubmitted = submissionQuery.docs.isNotEmpty;
      final submissionData = isSubmitted ? submissionQuery.docs.first.data() : null;
      final score = submissionData?['score'];
      final isGraded = submissionData?['graded'] ?? false;
      
      if (isSubmitted) {
        submittedCount++;
        // Now maxPoints is num, allowing direct addition
        totalPossiblePointsSubmitted += maxPoints; 
        if (isGraded && score != null) {
          // Use round() to ensure totalGainedPoints remains a whole number if desired, 
          // or cast to num
          totalGainedPoints += (score as num);
        }
      }

      assignmentReports.add({
        'title': assignmentData['title'] ?? 'Untitled Assignment',
        'maxPoints': maxPoints,
        'isSubmitted': isSubmitted,
        'isGraded': isGraded,
        'score': score,
        'scoreDisplay': isSubmitted ? (isGraded ? '$score / $maxPoints' : 'Pending') : 'Missing',
        'dueDate': (assignmentData['dueDate'] as Timestamp?)?.toDate(),
      });
    }
    
    final int? overallGainedPercentage = totalPossiblePointsSubmitted > 0
        ? ((totalGainedPoints / totalPossiblePointsSubmitted) * 100).round()
        : null;


    return {
      'reports': assignmentReports,
      'submittedCount': submittedCount,
      'totalAssignments': totalAssignments,
      'overallGainedPercentage': overallGainedPercentage, // Now nullable
    };
  }

  // --- UI Building ---
  
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Performance Report'),
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
                  _buildStudentInfoCard(primaryColor),
                  const SizedBox(height: 30),
                  
                  _buildOverallMetrics(primaryColor),
                  const SizedBox(height: 30),
                  
                  _buildAttendanceReportSection(primaryColor),
                  const SizedBox(height: 30),

                  _buildQuizReportSection(primaryColor),
                  const SizedBox(height: 30),
                  
                  _buildAssignmentReportSection(primaryColor),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildStudentInfoCard(Color primaryColor) {
    final details = _reportData['studentDetails'] as Map<String, String>;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: primaryColor.withOpacity(0.1),
              child: Text(widget.studentName.isNotEmpty ? widget.studentName[0] : '?', style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.studentName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Entry No: ${details['entryNo']}', style: const TextStyle(color: Colors.grey)),
                Text('Email: ${details['email']}', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallMetrics(Color primaryColor) {
    final attendance = _reportData['attendance'] as Map<String, dynamic>;
    final quizzes = _reportData['quizzes'] as Map<String, dynamic>;
    final assignments = _reportData['assignments'] as Map<String, dynamic>;
    
    // --- Attendance Handling ---
    final int? attendancePercentageNullable = attendance['percentage'] as int?;
    final int attendancePercentage = attendancePercentageNullable ?? 0;
    final bool attendanceSafe = attendancePercentage >= _attendanceTarget;
    final Color attColor = attendanceSafe ? Colors.green : Colors.red;
    final String attDisplay = attendancePercentageNullable == null ? 'N/A' : '$attendancePercentage%';

    // --- Quiz Handling ---
    final int? quizPercentageNullable = quizzes['overallQuizPercentage'] as int?;
    final int quizPercentage = quizPercentageNullable ?? 0;
    final Color quizColor = quizPercentage > 75 ? Colors.green : (quizPercentage > 50 ? Colors.orange : Colors.red);
    final String quizDisplay = quizPercentageNullable == null ? 'N/A' : '$quizPercentage%';
    
    // --- Assignment Handling ---
    final int? assignmentGainedPercentageNullable = assignments['overallGainedPercentage'] as int?;
    final int assignmentGainedPercentage = assignmentGainedPercentageNullable ?? 0;
    final Color assignColor = assignmentGainedPercentage > 75 ? Colors.green : (assignmentGainedPercentage > 50 ? Colors.orange : Colors.red);
    final String assignDisplay = assignmentGainedPercentageNullable == null ? 'N/A' : '$assignmentGainedPercentage%';


    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overall Performance Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCircle('Attendance', attDisplay, attColor), 
                _buildStatCircle('Quiz Score', quizDisplay, quizColor),
                _buildStatCircle('Assignment', assignDisplay, assignColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCircle(String title, String value, Color color) {
    // Determine the progress value for the circle, or 0.0 if N/A
    final double progressValue = value == 'N/A' ? 0.0 : double.tryParse(value.replaceAll('%', ''))! / 100.0;
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: progressValue.clamp(0.0, 1.0),
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 5,
              ),
            ),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildAttendanceReportSection(Color primaryColor) {
    final attendance = _reportData['attendance'] as Map<String, dynamic>;
    final int? percentageNullable = attendance['percentage'] as int?;
    final int attended = attendance['attendedSessions'] ?? 0;
    final int total = attendance['totalSessions'] ?? 0;
    

    if (percentageNullable == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
          const Divider(),
          Card(
            elevation: 2,
            color: Colors.grey.withOpacity(0.08),
            child: const ListTile(
              leading: Icon(Icons.info_outline, color: Colors.grey, size: 30),
              title: Text('N/A - No Attendance Sessions Held'),
              subtitle: Text('The instructor has not created any sessions for this class yet.'),
            ),
          ),
        ],
      );
    }
    
    final int percentage = percentageNullable;
    final bool isSafe = percentage >= _attendanceTarget;
    final Color color = isSafe ? Colors.green : Colors.red;
    // ----------------------------------

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attendance Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
        const Divider(),
        Card(
          elevation: 2,
          color: color.withOpacity(0.08),
          child: ListTile(
            leading: Icon(isSafe ? Icons.check_circle : Icons.warning, color: color, size: 30),
            title: Text(
              'Attendance Percentage: $percentage%',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            subtitle: Text('Attended $attended out of $total sessions.'),
            trailing: Text(
              isSafe ? 'On Track' : 'Below Target',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizReportSection(Color primaryColor) {
    final quizzesData = _reportData['quizzes'] as Map<String, dynamic>;
    final quizzes = quizzesData['reports'] as List<Map<String, dynamic>>;
    final int? overallPercentageNullable = quizzesData['overallQuizPercentage'] as int?;
    
    final submittedCount = quizzes.where((q) => q['isSubmitted']).length;
    final totalCount = quizzes.length;
    

    final String overallDisplay = overallPercentageNullable == null ? 'N/A' : '$overallPercentageNullable% Scored';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quiz Performance ($submittedCount/$totalCount Attended, $overallDisplay)', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
        const Divider(),
        if (quizzes.isEmpty)
          const Center(child: Text('No quizzes posted yet for this course.'))
        else
          ...quizzes.map((quiz) => _buildQuizTile(quiz, primaryColor)).toList(),
      ],
    );
  }

  Widget _buildQuizTile(Map<String, dynamic> quiz, Color primaryColor) {
    final isSubmitted = quiz['isSubmitted'];
    final isGraded = quiz['isGraded'] ?? false;
    final scoreDisplay = quiz['scoreDisplay'];

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.hourglass_empty;

    if (isSubmitted) {
      statusColor = isGraded ? Colors.green : Colors.blue;
      statusIcon = isGraded ? Icons.check_circle : Icons.pending;
    }
    
    String postedDate = DateFormat('MMM dd').format(quiz['postedOn'] ?? DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(quiz['title']),
        subtitle: Text('Posted: $postedDate'),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(scoreDisplay, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
            Text(isSubmitted ? (isGraded ? 'Graded' : 'Submitted') : 'Missing', style: TextStyle(fontSize: 12, color: statusColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentReportSection(Color primaryColor) {
    final assignmentsData = _reportData['assignments'] as Map<String, dynamic>;
    final assignmentReports = assignmentsData['reports'] as List<Map<String, dynamic>>;
    final submittedCount = assignmentsData['submittedCount'];
    final totalAssignments = assignmentsData['totalAssignments'];
    final int? overallGainedPercentageNullable = assignmentsData['overallGainedPercentage'] as int?;


    final String overallDisplay = overallGainedPercentageNullable == null ? 'N/A' : '$overallGainedPercentageNullable% Gained';


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assignment Performance ($submittedCount/$totalAssignments Submitted, $overallDisplay)', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)
        ),
        const Divider(),
        if (assignmentReports.isEmpty)
          const Center(child: Text('No assignments posted yet for this course.'))
        else
          ...assignmentReports.map((assignment) => _buildAssignmentTile(assignment, primaryColor)).toList(),
      ],
    );
  }

  Widget _buildAssignmentTile(Map<String, dynamic> assignment, Color primaryColor) {
    final isSubmitted = assignment['isSubmitted'];
    final isGraded = assignment['isGraded'];
    final maxPoints = assignment['maxPoints'];
    final score = assignment['score'];

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.warning;

    if (isSubmitted) {
      statusColor = isGraded ? Colors.green : Colors.blue;
      statusIcon = isGraded ? Icons.check_circle : Icons.upload_file;
    }
    
    final scoreText = isSubmitted ? (isGraded ? '$score / $maxPoints' : 'Pending Grading') : 'Missing';
    final statusText = isSubmitted ? (isGraded ? 'Graded' : 'Submitted') : 'Missing';
    
    String dueDate = DateFormat('MMM dd').format(assignment['dueDate'] ?? DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(assignment['title']),
        subtitle: Text('Due: $dueDate'),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(scoreText, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
            Text(statusText, style: TextStyle(fontSize: 12, color: statusColor)),
          ],
        ),
      ),
    );
  }
} 