import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Function to remove the student from the class
  Future<void> _removeStudent() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Removal'),
          content: Text('Are you sure you want to remove ${widget.studentName} from this class?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // 1. Remove studentId from the class document
        await FirebaseFirestore.instance.collection('classes').doc(widget.classId).update({
          'studentIds': FieldValue.arrayRemove([widget.studentId]),
        });
        
        // 2. Remove classId from the student's user document (if you maintain an 'enrolledClasses' field)
        // await FirebaseFirestore.instance.collection('users').doc(widget.studentId).update({
        //   'enrolledClasses': FieldValue.arrayRemove([widget.classId]),
        // });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.studentName} has been removed from the class.')),
          );
          // Navigate back to the People page
          Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
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

          final userData = snapshot.data!;
          final String email = userData['email'] ?? 'N/A';
          final String entryNo = userData['entryNo'] ?? 'N/A';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.studentName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(email),
                ),
                ListTile(
                  leading: const Icon(Icons.badge),
                  title: const Text('Entry/Roll No.'),
                  subtitle: Text(entryNo),
                ),
                
                const Divider(height: 30),
                
                // --- Management Action (Instructor Only) ---
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

                // --- Student Performance/Submissions Section (Placeholder) ---
                Text(
                  'Assignments & Grades',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                const Text('Future implementation: Show a list of assignments, their submission status, and grades for this student.'),
              ],
            ),
          );
        },
      ),
    );
  }
}