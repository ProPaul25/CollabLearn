// lib/submission_review_page.dart - (No errors found)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_submission_detail.dart'; 
import 'study_materials_view_page.dart'; // This import now works correctly

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
  // ... (All state logic is unchanged) ...
  Future<List<String>> _fetchStudentIds() async {
    final classDoc = await FirebaseFirestore.instance.collection('classes').doc(widget.classId).get();
    final data = classDoc.data();
    return (data?['studentIds'] as List?)?.whereType<String>().toList() ?? [];
  }

  Future<List<Map<String, dynamic>>> _fetchUsersData(List<String> uids) async {
    if (uids.isEmpty) return [];

    final List<Map<String, dynamic>> userList = [];
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
    // ... (All build logic is unchanged) ...
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
              
              students.sort((a, b) => (a['lastName'] ?? '').compareTo(b['lastName'] ?? ''));

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
                  
                  final Map<String, Map<String, dynamic>> submissionsMap = {
                    for (var doc in submissionDocs) 
                      doc['studentId'] as String: {...doc.data() as Map<String, dynamic>, 'docId': doc.id}
                  };

                  int submittedCount = submissionsMap.keys.length;
                  int gradedCount = submissionsMap.values.where((sub) => sub['graded'] == true).length;
                  
                  int missingCount = students.length - submittedCount;
                  
                  students.sort((a, b) {
                      final aSub = submissionsMap[a['uid']];
                      final bSub = submissionsMap[b['uid']];
                      
                      final aStatus = aSub?['graded'] == true ? 2 : (aSub != null ? 1 : 0); 
                      final bStatus = bSub?['graded'] == true ? 2 : (bSub != null ? 1 : 0);
                      
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
              width: 110, 
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
        onTap: isSubmitted ? () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StudentSubmissionDetail(
                submissionDocId: docId!,
                assignment: widget.assignment,
                studentName: displayName,
                isGraded: isGraded,
              ),
            ),
          ).then((_) {
            setState(() {}); 
          });
        } : null, 
      ),
    );
  }
}