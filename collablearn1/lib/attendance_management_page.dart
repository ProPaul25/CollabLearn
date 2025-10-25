// lib/attendance_management_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'start_attendance_session_page.dart'; // NEW
import 'dart:async';
import 'submit_attendance_page.dart';

class AttendanceManagementPage extends StatelessWidget {
  final String classId;

  const AttendanceManagementPage({
    super.key,
    required this.classId,
  });

  // Re-used function to check if the current user is the instructor of this course
  Future<bool> isCurrentUserInstructor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final classDoc =
        await FirebaseFirestore.instance.collection('classes').doc(classId).get();
        
    final instructorId = classDoc.data()?['instructorId'];
    return user.uid == instructorId;
  }

  @override
  Widget build(BuildContext context) {
    // Determine the current user's role to show the correct view
    return FutureBuilder<bool>(
      future: isCurrentUserInstructor(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final isInstructor = snapshot.data ?? false;

        return isInstructor
            ? InstructorAttendanceView(classId: classId)
            : StudentAttendanceView(classId: classId);
      },
    );
  }
}

// =================================================================
// INSTRUCTOR VIEW (Management)
// =================================================================
class InstructorAttendanceView extends StatefulWidget {
  final String classId;

  const InstructorAttendanceView({super.key, required this.classId});

  @override
  State<InstructorAttendanceView> createState() => _InstructorAttendanceViewState();
}

class _InstructorAttendanceViewState extends State<InstructorAttendanceView> {
  // Logic to show a persistent indicator if an active session exists
  bool _hasActiveSession = false;

  @override
  void initState() {
    super.initState();
    // This is a simple initial check, a StreamBuilder in the build method 
    // is better for real-time status.
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // Stream past attendance sessions, ordered by most recent
        stream: FirebaseFirestore.instance
            .collection('attendance_sessions')
            .where('courseId', isEqualTo: widget.classId)
            .orderBy('startTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final sessions = snapshot.data?.docs ?? [];
          QueryDocumentSnapshot? activeSession;
          
          // Check for an active session to control the FAB visibility/state
          for (var doc in sessions) {
            final data = doc.data() as Map<String, dynamic>;
            final endTime = (data['endTime'] as Timestamp).toDate();
            if (endTime.isAfter(DateTime.now())) {
                activeSession = doc;
                break; // Found the active session, stop looking
            }
          }
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasActiveSession = activeSession != null;
              });
            }
          });

          if (sessions.isEmpty) {
            return const Center(
              child: Text('No attendance sessions created yet.', style: TextStyle(fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index].data() as Map<String, dynamic>;
              final startTime = (session['startTime'] as Timestamp).toDate();
              final endTime = (session['endTime'] as Timestamp).toDate();
              final sessionCode = session['sessionCode'];
              
              final isActive = endTime.isAfter(DateTime.now());

              return Card(
                color: isActive ? primaryColor.withOpacity(0.1) : null,
                child: ListTile(
                  title: Text('Session: ${startTime.day}/${startTime.month}/${startTime.year}'),
                  subtitle: Text(isActive
                      ? 'ACTIVE - Code: $sessionCode (Ends: ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')})'
                      : 'Ended: ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to a details page (optional: to view who marked present)
                  },
                ),
              );
            },
          );
        },
      ),
      
      // Instructor FAB to start a new session
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _hasActiveSession ? null : () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StartAttendanceSessionPage(classId: widget.classId),
            ),
          );
        },
        label: Text(_hasActiveSession ? 'Active Session Running' : 'Start New Session'),
        icon: Icon(_hasActiveSession ? Icons.timer : Icons.add_alarm),
        backgroundColor: _hasActiveSession ? Colors.grey : primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// =================================================================
// STUDENT VIEW (Attendance History)
// =================================================================
class StudentAttendanceView extends StatelessWidget {
  final String classId;

  const StudentAttendanceView({super.key, required this.classId});
  
  // This helps students find the active session to submit the code
  Future<QueryDocumentSnapshot?> _getActiveSession() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance_sessions')
        .where('courseId', isEqualTo: classId)
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final latestSession = snapshot.docs.first;
      final endTime = (latestSession.data()['endTime'] as Timestamp).toDate();
      if (endTime.isAfter(DateTime.now())) {
        return latestSession;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return FutureBuilder<QueryDocumentSnapshot?>(
      future: _getActiveSession(), // Check for an active session
      builder: (context, activeSessionSnapshot) {
        final activeSessionDoc = activeSessionSnapshot.data;

        return Scaffold(
          body: StreamBuilder<QuerySnapshot>(
            // Stream the student's own attendance records
            stream: FirebaseFirestore.instance
                .collection('attendance_records')
                .where('studentId', isEqualTo: userId)
                .snapshots(),
            builder: (context, recordSnapshot) {
              if (recordSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (recordSnapshot.hasError) {
                return Center(child: Text('Error: ${recordSnapshot.error}'));
              }
              
              final records = recordSnapshot.data?.docs ?? [];
              final totalPresent = records.length;
              
              // This is a simplified view - ideally you'd also need the total number of sessions
              // We'll use a placeholder for total sessions for now.
              const totalSessions = 5; 
              final attendancePercentage = totalSessions > 0 ? (totalPresent / totalSessions * 100).toStringAsFixed(1) : 'N/A';


              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Attendance Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text('Total Classes Attended: $totalPresent', style: const TextStyle(fontSize: 16)),
                          Text('Attendance Percentage: $attendancePercentage%', style: const TextStyle(fontSize: 16)),
                          // Placeholder for total sessions needs to be fetched from Firestore
                          Text('Total Sessions (Placeholder): $totalSessions', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  const Divider(),

                  ...records.map((recordDoc) {
                    final record = recordDoc.data() as Map<String, dynamic>;
                    final timestamp = (record['timestamp'] as Timestamp).toDate();
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text('Present - ${timestamp.day}/${timestamp.month}/${timestamp.year}'),
                      subtitle: Text('Recorded at: ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}'),
                    );
                  }).toList(),
                  
                  if (records.isEmpty) 
                    const Center(child: Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text('No attendance records found.', style: TextStyle(color: Colors.grey)),
                    )),
                ],
              );
            },
          ),
          // Student FAB to submit code if a session is active
          floatingActionButton: activeSessionDoc != null
              ? FloatingActionButton.extended(
                  onPressed: () {
                    final sessionData = activeSessionDoc.data() as Map<String, dynamic>;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SubmitAttendancePage(
                          sessionCode: sessionData['sessionCode'],
                          sessionId: activeSessionDoc.id,
                        ),
                      ),
                    );
                  },
                  label: const Text('Submit Attendance Code'),
                  icon: const Icon(Icons.code),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                )
              : null,
        );
      },
    );
  }
}