// lib/user_progress_tracker_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProgressTrackerPage extends StatefulWidget {
  const UserProgressTrackerPage({super.key});

  @override
  State<UserProgressTrackerPage> createState() => _UserProgressTrackerPageState();
}

class _UserProgressTrackerPageState extends State<UserProgressTrackerPage> {
  bool _isLoading = true;
  String _userName = 'User';

  // State variables for dynamic metrics
  int _attendancePercentage = 0;
  int _quizAverage = 0;
  int _goalProgress = 0;
  final int _goalTarget = 85; // Target from your Figma design

  // Dynamic list for Performance Overview/Mid Exams
  List<Map<String, dynamic>> _midExamPerformance = [];

  @override
  void initState() {
    super.initState();
    _fetchPerformanceData();
  }

  Future<void> _fetchPerformanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Load User Name
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final firstName = data?['firstName'] ?? '';
        final lastName = data?['lastName'] ?? '';
        if (mounted) {
          setState(() {
            _userName = (firstName.isNotEmpty || lastName.isNotEmpty) ? '$firstName $lastName' : user.displayName ?? 'User';
          });
        }
      }

      // 2. Fetch Overall Progress Data from 'progress_tracker'
      // This collection will dynamically hold the latest calculated metrics for each user.
      final progressDoc = await FirebaseFirestore.instance
          .collection('progress_tracker')
          .doc(user.uid) // Document ID is the user's UID
          .get();

      // 3. Fetch Mid Exam Performance Data from a sub-collection (e.g., 'exams')
      // This assumes that detailed exam results are stored under the user's profile.
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
            // Overall Metrics (Dynamic)
            _attendancePercentage = data?['overallAttendance'] as int? ?? 92; 
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
             _attendancePercentage = 92;
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
                  // --- Welcome Banner (Figma: Good Morning!) ---
                  Text(
                    'Welcome! $_userName', // Based on Figma design
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Ready to achieve your goals today?', // Based on Figma design
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 25),

                  // --- Top Metrics Row (Attendance & Quiz Average) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricCard(
                        context,
                        title: 'Attendance',
                        value: '$_attendancePercentage%',
                        feedback: _attendancePercentage >= 90 ? 'Great job!' : 'Needs attention', 
                        icon: Icons.check_circle_outline,
                      ),
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
                    'Performance Overview', // Based on Figma design
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(thickness: 1),
                  ..._midExamPerformance.map((exam) => _buildExamProgress(
                        exam['subject'],
                        exam['score'],
                        primaryColor,
                      )),
                  const SizedBox(height: 30),

                  // --- Goal Progress Tracker ---
                  _buildGoalProgress(primaryColor),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(BuildContext context, {required String title, required String value, required String feedback, required IconData icon}) {
    // Determine color based on metric
    final bool isPositive = title == 'Attendance' ? _attendancePercentage >= 90 : _quizAverage >= 80;
    final Color iconColor = isPositive ? Colors.green : Colors.orange;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width / 2 - 24, // Half width minus padding
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
              Text('$score%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)), // Score text
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
                  Text('Target: $_goalTarget%', style: const TextStyle(color: Colors.grey)), // Target from Figma
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
                Text('$_goalProgress%', style: const TextStyle(fontWeight: FontWeight.bold)), // Progress value
              ],
            ),
          ],
        ),
      ),
    );
  }
}