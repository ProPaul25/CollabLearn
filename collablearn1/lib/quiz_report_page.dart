// lib/quiz_report_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizReportPage extends StatelessWidget {
  final String quizId;
  final String quizTitle;

  const QuizReportPage({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  // --- NEW: Fetch and combine submission, user data, and statistics ---
  Future<Map<String, dynamic>> _fetchReportData() async {
    final firestore = FirebaseFirestore.instance;

    // 1. Fetch all submissions for the quiz
    final submissionsSnapshot = await firestore
        .collection('quizzes')
        .doc(quizId)
        .collection('submissions')
        .get();

    if (submissionsSnapshot.docs.isEmpty) {
      return {
        'submissions': [],
        'totalSubmissions': 0,
        'averageScore': 0,
        'highestScore': 0,
        'lowestScore': 0,
        'maxPossibleScore': 0,
      };
    }

    final List<Map<String, dynamic>> submissions = submissionsSnapshot.docs.map((doc) => doc.data()).toList();
    final studentIds = submissions.map((s) => s['studentId'] as String).toSet().toList();
    final num maxPossibleScore = submissions.first['maxScore'] ?? 0;

    // 2. Fetch student details (names, entry numbers)
    final Map<String, Map<String, dynamic>> studentDetails = {};
    for (var uid in studentIds) {
      final userDoc = await firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final name = '${data?['firstName'] ?? ''} ${data?['lastName'] ?? ''}'.trim();
        studentDetails[uid] = {
          'name': name.isEmpty ? (data?['email'] ?? 'Unknown Student') : name,
          'entryNo': data?['entryNo'] ?? 'N/A',
        };
      }
    }

    // 3. Combine data and calculate statistics
    num totalScoreSum = 0;
    num highestScore = 0;
    num lowestScore = maxPossibleScore; 

    final List<Map<String, dynamic>> detailedSubmissions = submissions.map((sub) {
      final uid = sub['studentId'] as String;
      final num score = sub['score'] ?? 0;
      totalScoreSum += score;
      if (score > highestScore) highestScore = score;
      if (score < lowestScore) lowestScore = score;
      
      return {
        ...sub,
        'studentName': studentDetails[uid]?['name'] ?? 'Unknown Student',
        'entryNo': studentDetails[uid]?['entryNo'] ?? 'N/A',
        'submittedOn': (sub['submissionTime'] as Timestamp?)?.toDate(),
      };
    }).toList();
    
    // Sort by score descending
    detailedSubmissions.sort((a, b) => b['score'].compareTo(a['score']));

    final double averageScore = maxPossibleScore > 0 ? (totalScoreSum / submissions.length) : 0.0;
    
    return {
      'submissions': detailedSubmissions,
      'totalSubmissions': submissions.length,
      'averageScore': averageScore,
      'highestScore': highestScore,
      'lowestScore': lowestScore,
      'maxPossibleScore': maxPossibleScore,
    };
  }
  // --- END NEW DATA FETCHING ---
  
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('$quizTitle - Report'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchReportData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading report: ${snapshot.error}'));
          }

          final report = snapshot.data ?? {};
          final submissions = report['submissions'] as List<Map<String, dynamic>>? ?? [];
          final totalSubmissions = report['totalSubmissions'] as int? ?? 0;
          final averageScore = report['averageScore'] as double? ?? 0.0;
          final num highestScore = report['highestScore'] as num? ?? 0;
          final num lowestScore = report['lowestScore'] as num? ?? 0;
          final num maxPossibleScore = report['maxPossibleScore'] as num? ?? 0;


          if (totalSubmissions == 0) {
            return const Center(child: Text('No submissions recorded for this quiz yet.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Summary Card ---
              _buildSummaryCard(context, primaryColor, totalSubmissions, maxPossibleScore, averageScore, highestScore, lowestScore),
              
              const SizedBox(height: 30),
              
              Text(
                'Individual Submissions ($totalSubmissions)',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              
              // --- Detailed Submission List ---
              ...submissions.map((sub) => _buildSubmissionTile(context, sub, maxPossibleScore, primaryColor)).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Color primaryColor, int total, num maxScore, double avgScore, num high, num low) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quiz Statistics (Max: $maxScore Points)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', total.toString(), Colors.grey.shade600),
                _buildStatItem('Average', avgScore.toStringAsFixed(1), primaryColor),
                _buildStatItem('Highest', high.toString(), Colors.green),
                _buildStatItem('Lowest', low.toString(), Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }


  Widget _buildSubmissionTile(BuildContext context, Map<String, dynamic> submission, num maxScore, Color primaryColor) {
    final num score = submission['score'] ?? 0;
    final submittedOn = submission['submittedOn'] as DateTime?;
    final scoreRatio = maxScore > 0 ? score / maxScore : 0.0;
    final scoreColor = scoreRatio > 0.8 ? Colors.green : (scoreRatio > 0.5 ? Colors.orange : Colors.red);
    
    String formattedTime = submittedOn != null 
        ? '${submittedOn.day}/${submittedOn.month} ${submittedOn.hour}:${submittedOn.minute.toString().padLeft(2, '0')}'
        : 'N/A';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scoreColor.withOpacity(0.1),
          child: Text(
            score.toString(), 
            style: TextStyle(fontWeight: FontWeight.bold, color: scoreColor)
          ),
        ),
        title: Text(submission['studentName'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Entry No: ${submission['entryNo']} | Submitted: $formattedTime'),
        trailing: Text(
          '$score / $maxScore',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        // Optional: Implement onTap to view detailed answers later
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Detailed quiz answer review not yet implemented.')),
          );
        },
      ),
    );
  }
}