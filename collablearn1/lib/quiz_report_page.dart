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

  // Placeholder function to fetch student submission summary
  Future<List<Map<String, dynamic>>> _fetchSubmissions() async {
    // This needs to be a full implementation that fetches all submissions, 
    // matches them to student names (from a separate fetch), and calculates stats.
    final snapshot = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .collection('submissions')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'studentId': data['studentId'] ?? 'N/A',
        'score': data['score'] ?? 0,
        'maxScore': data['maxScore'] ?? 0,
        'email': data['studentEmail'] ?? 'N/A',
        'submitted': (data['submissionTime'] as Timestamp?)?.toDate().toString().split('.')[0] ?? 'N/A',
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('$quizTitle - Results'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchSubmissions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading report: ${snapshot.error}'));
          }

          final submissions = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text('Total Submissions: ${submissions.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              ...submissions.map((sub) {
                return ListTile(
                  title: Text(sub['email'] as String),
                  trailing: Text('${sub['score']}/${sub['maxScore']}', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                  subtitle: Text('Submitted on: ${sub['submitted']}'),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}