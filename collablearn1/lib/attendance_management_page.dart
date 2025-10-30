// lib/attendance_management_page.dart - CORRECTED

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'start_attendance_session_page.dart';
import 'dart:async';
import 'submit_attendance_page.dart'; // IMPORTANT: This is now the QR Scanner page
import 'attendance_report_page.dart';

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

// lib/attendance_management_page.dart (InstructorAttendanceView)

// =================================================================
// INSTRUCTOR VIEW (Management) - STABLE VERSION
// Note: Changed from StatefulWidget to StatelessWidget
// =================================================================
// lib/attendance_management_page.dart (InstructorAttendanceView)

// =================================================================
// INSTRUCTOR VIEW (Management) - STABLE & CORRECTED VERSION
// =================================================================
class InstructorAttendanceView extends StatelessWidget {
  final String classId;

  const InstructorAttendanceView({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // 1. StreamBuilder handles all rebuilds based on Firestore data
    return StreamBuilder<QuerySnapshot>(
      // Stream past attendance sessions, ordered by most recent
      stream: FirebaseFirestore.instance
          .collection('attendance_sessions')
          .where('courseId', isEqualTo: classId)
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
        
        // 2. Find the active session using a simple loop (No setState!)
        for (var doc in sessions) {
          final data = doc.data() as Map<String, dynamic>;
          final endTime = (data['endTime'] as Timestamp).toDate();
          if (endTime.isAfter(DateTime.now())) {
            activeSession = doc;
            break; 
          }
        }
        
        // 3. Derive state locally and use it to control the FAB
        final hasActiveSession = activeSession != null; 

        if (sessions.isEmpty) {
          return Scaffold(
            body: const Center(
              child: Text('No attendance sessions created yet.', style: TextStyle(fontSize: 16)),
            ),
            floatingActionButton: _buildFab(context, classId, hasActiveSession, primaryColor),
          );
        }

        // --- START OF CORRECT SCAFFOLD WITH LISTVIEW ---
        return Scaffold(
          body: ListView.builder(
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
                    final sessionDocId = sessions[index].id;
                    final sessionDate = '${startTime.day}/${startTime.month}/${startTime.year}';
                    
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AttendanceReportPage(
                          classId: classId,
                          sessionId: sessionDocId,
                          sessionTitle: 'Session on $sessionDate',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          
          // FAB is outside the ListView, correctly placed in the Scaffold
          floatingActionButton: _buildFab(context, classId, hasActiveSession, primaryColor),
        );
        // --- END OF CORRECT SCAFFOLD WITH LISTVIEW ---
      },
    );
  }
  
  // Helper method for the Floating Action Button
  Widget _buildFab(BuildContext context, String classId, bool hasActiveSession, Color primaryColor) {
    return FloatingActionButton.extended(
      onPressed: hasActiveSession ? null : () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StartAttendanceSessionPage(classId: classId),
          ),
        );
      },
      label: Text(hasActiveSession ? 'Active Session Running' : 'Start New Session'),
      icon: Icon(hasActiveSession ? Icons.timer : Icons.add_alarm),
      backgroundColor: hasActiveSession ? Colors.grey : primaryColor,
      foregroundColor: Colors.white,
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
      // Check if the session is still active
      if (endTime.isAfter(DateTime.now())) {
        return latestSession;
      }
    }
    return null;
  }

  // --- NEW: Helper to get total session count for percentage ---
  Future<int> _getTotalSessionCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance_sessions')
        .where('courseId', isEqualTo: classId)
        // Only count sessions that have ended or are running (for a more accurate ratio)
        // We will count all sessions here. The 'records' stream handles actual attendance.
        .count()
        .get();
    
    return snapshot.count ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return FutureBuilder<QueryDocumentSnapshot?>(
      future: _getActiveSession(), // Check for an active session
      builder: (context, activeSessionSnapshot) {
        final activeSessionDoc = activeSessionSnapshot.data;

        return Scaffold(
          // --- FIX: Use a second FutureBuilder to get the total session count ---
          body: FutureBuilder<int>(
            future: _getTotalSessionCount(),
            builder: (context, totalSessionsSnapshot) {

              return StreamBuilder<QuerySnapshot>(
                // Stream the student's own attendance records
                stream: FirebaseFirestore.instance
                    .collection('attendance_records')
                    .where('studentId', isEqualTo: userId)
                    .where('courseId', isEqualTo: classId) // <-- Filter by class
                    .snapshots(),
                builder: (context, recordSnapshot) {
                  if (recordSnapshot.connectionState == ConnectionState.waiting || 
                      totalSessionsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (recordSnapshot.hasError || totalSessionsSnapshot.hasError) {
                    return Center(child: Text('Error: ${recordSnapshot.error ?? totalSessionsSnapshot.error}'));
                  }
                  
                  final records = recordSnapshot.data?.docs ?? [];
                  final totalPresent = records.length;
                  
                  // --- FIX: Use the real total session count ---
                  final totalSessions = totalSessionsSnapshot.data ?? 0; 
                  final attendancePercentage = totalSessions > 0 ? (totalPresent / totalSessions * 100).toStringAsFixed(0) : '100';


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
                              Text('Total Sessions Held: $totalSessions', style: const TextStyle(fontSize: 16)),
                              Text('Attendance Percentage: $attendancePercentage%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              );
            }
          ),
          // Student FAB to scan QR code if a session is active
          floatingActionButton: activeSessionDoc != null
              ? FloatingActionButton.extended(
                  onPressed: () {
                    // Navigate to the QR scanner page. 
                    // The submitted code/ID will be scanned, not passed as a parameter.
                    // We pass dummy data for required fields to satisfy the old constructor.
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SubmitAttendancePage(
                          sessionCode: 'SCAN', // Dummy value
                          sessionId: 'SCAN', // Dummy value
                        ),
                      ),
                    );
                  },
                  label: const Text('Scan QR for Attendance'),
                  icon: const Icon(Icons.qr_code_scanner),
                  backgroundColor: Theme.of(context).colorScheme.primary, // Changed color for consistency
                  foregroundColor: Colors.white,
                )
              : null,
        );
      },
    );
  }
}
