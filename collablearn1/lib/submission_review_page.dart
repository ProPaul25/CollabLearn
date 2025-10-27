// lib/submission_review_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_submission_detail.dart'; // Import the grading page
import 'study_materials_view_page.dart'; // Import AssignmentItem model

class SubmissionReviewPage extends StatefulWidget {
  final AssignmentItem assignment;
  final String classId;

  const SubmissionReviewPage({
    super.key,
    required this.assignment,
    required this.classId,
  });

  @override
  State<SubmissionReviewPage> createState() => _SubmissionReviewPageState();
}

class _SubmissionReviewPageState extends State<SubmissionReviewPage> {
  // Fetches a list of all students enrolled in the class
  Future<List<String>> _fetchStudentIds() async {
    final classDoc = await FirebaseFirestore.instance.collection('classes').doc(widget.classId).get();
    final data = classDoc.data();
    // Use .whereType<String>() to ensure all elements are strings
    return (data?['studentIds'] as List?)?.whereType<String>().toList() ?? [];
  }

  // Fetches detailed user data for a list of UIDs
  Future<List<Map<String, dynamic>>> _fetchUsersData(List<String> uids) async {
    if (uids.isEmpty) return [];

    final List<Map<String, dynamic>> userList = [];
    // Fetching iteratively is necessary if the list of students exceeds 10 
    // due to Firestore's 'whereIn' limit.
    for (var uid in uids) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
            final data = doc.data();
            if (data != null) {
                userList.add({...data, 'uid': doc.id});
            }
        }
    }
    return userList;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.assignment.title} - Submission Review'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<String>>(
        future: _fetchStudentIds(),
        builder: (context, studentIdSnapshot) {
          if (studentIdSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (studentIdSnapshot.hasError) {
            return Center(child: Text('Error loading class roster: ${studentIdSnapshot.error}'));
          }

          final studentUids = studentIdSnapshot.data ?? [];

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchUsersData(studentUids),
            builder: (context, studentDataSnapshot) {
              if (studentDataSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final students = studentDataSnapshot.data ?? [];
              
              // Sort by last name for easier management
              students.sort((a, b) => (a['lastName'] ?? '').compareTo(b['lastName'] ?? ''));

              // Stream submissions to get real-time status and score
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('assignment_submissions')
                    .where('assignmentId', isEqualTo: widget.assignment.id)
                    .snapshots(),
                builder: (context, submissionSnapshot) {
                  if (submissionSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final submissionDocs = submissionSnapshot.data?.docs ?? [];
                  
                  // Map submissions by studentId for quick lookup
                  final Map<String, Map<String, dynamic>> submissionsMap = {
                    for (var doc in submissionDocs) 
                      doc['studentId'] as String: {...doc.data() as Map<String, dynamic>, 'docId': doc.id}
                  };

                  int submittedCount = submissionsMap.keys.length;
                  int gradedCount = submissionsMap.values.where((sub) => sub['graded'] == true).length;
                  
                  // Calculate missing count based on the number of enrolled students vs. number of submissions
                  int missingCount = students.length - submittedCount;
                  
                  // Sort students to bring pending submissions (Submitted but not Graded) to the top
                  students.sort((a, b) {
                      final aSub = submissionsMap[a['uid']];
                      final bSub = submissionsMap[b['uid']];
                      
                      final aStatus = aSub?['graded'] == true ? 2 : (aSub != null ? 1 : 0); // Graded (2), Submitted (1), Missing (0)
                      final bStatus = bSub?['graded'] == true ? 2 : (bSub != null ? 1 : 0);
                      
                      // Prioritize Missing (0) and then Submitted (1)
                      return aStatus.compareTo(bStatus); 
                  });


                  return Column(
                    children: [
                      _buildSummaryCard(context, students.length, submittedCount, gradedCount, missingCount),
                      Expanded(
                        child: ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final submission = submissionsMap[student['uid']];
                            return _buildStudentSubmissionTile(context, student, submission, widget.assignment.points);
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
  
  // Helper to build the summary card
  Widget _buildSummaryCard(BuildContext context, int total, int submitted, int graded, int missing) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total', total, Colors.grey),
            _buildStatItem('Submitted', submitted, Colors.blue),
            _buildStatItem('Graded', graded, Colors.green),
            _buildStatItem('Missing', missing, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, int count, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        const SizedBox(height: 5),
        Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }


  // Helper to build a single student's submission row
  Widget _buildStudentSubmissionTile(BuildContext context, Map<String, dynamic> student, Map<String, dynamic>? submission, int maxPoints) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final name = '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.trim();
    final isSubmitted = submission != null;
    final isGraded = submission?['graded'] ?? false;
    final score = submission?['score'];
    final docId = submission?['docId'];


    Color statusColor = Colors.grey;
    String statusText = 'Missing';
    IconData statusIcon = Icons.cancel;

    if (isSubmitted) {
      statusText = isGraded ? 'Graded' : 'Submitted';
      statusColor = isGraded ? Colors.green : Colors.blue;
      statusIcon = isGraded ? Icons.check_circle : Icons.upload_file;
    }
    if (isGraded) {
      statusText = 'Graded: $score/$maxPoints';
    }
    
    // Fallback for missing student name
    final displayName = name.isEmpty ? (student['email'] ?? 'Unknown Student') : name;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: primaryColor)),
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(student['entryNo'] ?? student['email'] ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 20, color: statusColor),
            const SizedBox(width: 8),
            SizedBox(
              width: 110, // Fixed width for status text
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        // Only allow tap/grading if a submission exists
        onTap: isSubmitted ? () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StudentSubmissionDetail(
                submissionDocId: docId!, // Must have docId if submitted
                assignment: widget.assignment,
                studentName: displayName,
                isGraded: isGraded,
              ),
            ),
          ).then((_) {
            // Refresh the page to show the new grade immediately
            setState(() {}); 
          });
        } : null, 
      ),
    );
  }
}
