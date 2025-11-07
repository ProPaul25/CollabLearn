import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import for date formatting

// 1. New data model to combine assignment and submission details
class StudentAssignmentStatus {
  final String assignmentId;
  final String title;
  final Timestamp dueDate;
  final int maxPoints;
  final bool isSubmitted;
  final int? grade;
  final bool isLate;

  StudentAssignmentStatus({
    required this.assignmentId,
    required this.title,
    required this.dueDate,
    required this.maxPoints,
    required this.isSubmitted,
    this.grade,
    required this.isLate,
  });
}

class StudentManagementDetailPage extends StatefulWidget {
  final String classId;
  final String studentId;
  final String studentName; // For display, saves a read
  final bool isInstructor;

  const StudentManagementDetailPage({
    super.key,
    required this.classId,
    required this.studentId,
    required this.studentName,
    required this.isInstructor,
  });

  @override
  State<StudentManagementDetailPage> createState() => _StudentManagementDetailPageState();
}

class _StudentManagementDetailPageState extends State<StudentManagementDetailPage> {
  late Future<Map<String, dynamic>> _studentDataFuture;

  @override
  void initState() {
    super.initState();
    _studentDataFuture = _fetchStudentData();
  }

  Future<Map<String, dynamic>> _fetchStudentData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.studentId).get();
    if (doc.exists) {
      return doc.data()!;
    }
    throw Exception("Student data not found.");
  }

  // 2. NEW FUNCTION: Fetches all assignments and the student's submission status for each
  Future<List<StudentAssignmentStatus>> _fetchAssignmentData() async {
    final assignmentDocs = await FirebaseFirestore.instance
        .collection('assignments')
        .where('courseId', isEqualTo: widget.classId)
        .orderBy('dueDate', descending: false)
        .get();

    final List<StudentAssignmentStatus> statusList = [];
    final submissionFutures = <Future<void>>[];

    for (final assignmentDoc in assignmentDocs.docs) {
      final data = assignmentDoc.data();
      final assignmentId = assignmentDoc.id;
      final dueDate = data['dueDate'] as Timestamp;
      final maxPoints = data['maxPoints'] as int? ?? 100;

      // Fetch the student's specific submission for this assignment
      final submissionFuture = FirebaseFirestore.instance
          .collection('submissions')
          .where('assignmentId', isEqualTo: assignmentId)
          .where('studentId', isEqualTo: widget.studentId)
          .limit(1)
          .get()
          .then((submissionSnapshot) {
        
        bool isSubmitted = submissionSnapshot.docs.isNotEmpty;
        int? grade;
        bool isLate = false;

        if (isSubmitted) {
          final submissionData = submissionSnapshot.docs.first.data();
          grade = submissionData['grade'] as int?;
          isLate = submissionData['isLate'] as bool? ?? false;
        }

        statusList.add(
          StudentAssignmentStatus(
            assignmentId: assignmentId,
            title: data['title'] ?? 'Untitled Assignment',
            dueDate: dueDate,
            maxPoints: maxPoints,
            isSubmitted: isSubmitted,
            grade: grade,
            isLate: isLate,
          ),
        );
      });
      submissionFutures.add(submissionFuture);
    }

    // Wait for all submission fetches to complete
    await Future.wait(submissionFutures);
    return statusList;
  }

  // Function to remove the student from the class
  Future<void> _removeStudent() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text('Are you sure you want to remove ${widget.studentName} from this class?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Remove student's ID from the class document
        await FirebaseFirestore.instance.collection('classes').doc(widget.classId).update({
          'studentIds': FieldValue.arrayRemove([widget.studentId]),
        });

        // 2. Remove class ID from the student's user document
        await FirebaseFirestore.instance.collection('users').doc(widget.studentId).update({
          'enrolledClassIds': FieldValue.arrayRemove([widget.classId]),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.studentName} removed successfully.')),
          );
          Navigator.of(context).pop(); // Go back after success
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing student: $e')),
          );
        }
      }
    }
  }

  // 3. NEW WIDGET: Builds the list of assignments
  Widget _buildAssignmentList() {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return FutureBuilder<List<StudentAssignmentStatus>>(
      future: _fetchAssignmentData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading assignments: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No assignments found for this class.'));
        }

        final assignments = snapshot.data!;
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Important for nested list views
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final item = assignments[index];
            String statusText;
            Color statusColor;
            IconData statusIcon;

            if (item.grade != null) {
              statusText = 'Graded (${item.grade}/${item.maxPoints})';
              statusColor = Colors.green;
              statusIcon = Icons.done_all;
            } else if (item.isSubmitted) {
              statusText = item.isLate ? 'Submitted (Late)' : 'Submitted';
              statusColor = item.isLate ? Colors.orange : primaryColor;
              statusIcon = Icons.check;
            } else if (item.dueDate.toDate().isBefore(DateTime.now())) {
              statusText = 'Missing';
              statusColor = Colors.red;
              statusIcon = Icons.close;
            } else {
              statusText = 'Assigned';
              statusColor = Colors.grey;
              statusIcon = Icons.assignment_outlined;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Icon(statusIcon, color: statusColor),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Due: ${DateFormat('MMM d, hh:mm a').format(item.dueDate.toDate())}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                trailing: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onTap: () {
                  // Future: Navigate to the full assignment detail/submission review page for this student
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _studentDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final studentData = snapshot.data!;
          final String entryNo = studentData['entryNo'] ?? 'N/A';
          final String email = studentData['email'] ?? 'N/A';
          final String phone = studentData['phone'] ?? 'N/A';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // --- Student Details ---
                Text(
                  'Student Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: primaryColor),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.grey),
                  title: const Text('Full Name'),
                  subtitle: Text(widget.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                ListTile(
                  leading: const Icon(Icons.badge, color: Colors.grey),
                  title: const Text('Entry Number'),
                  subtitle: Text(entryNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.grey),
                  title: const Text('Email'),
                  subtitle: Text(email),
                ),
                ListTile(
                  leading: const Icon(Icons.phone, color: Colors.grey),
                  title: const Text('Phone'),
                  subtitle: Text(phone),
                ),

                // --- Remove Student Action (Instructor Only) ---
                if (widget.isInstructor)
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _removeStudent,
                        icon: const Icon(Icons.person_remove_alt_1, color: Colors.white),
                        label: const Text('Remove Student from Class', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),

                const Divider(height: 40),

                // 4. NEW: Assignments & Grades Section
                Text(
                  'Assignments & Grades',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: primaryColor),
                ),
                const SizedBox(height: 10),
                
                // Call the new assignment list builder
                _buildAssignmentList(),

              ],
            ),
          );
        },
      ),
    );
  }
}