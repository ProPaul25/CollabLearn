// lib/attendance_report_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceReportPage extends StatelessWidget {
  final String classId;
  final String sessionId;
  final String sessionTitle;

  const AttendanceReportPage({
    super.key,
    required this.classId,
    required this.sessionId,
    required this.sessionTitle,
  });

  // Data structure to hold the student and their attendance status
  Future<List<Map<String, dynamic>>> _fetchReportData() async {
    final firestore = FirebaseFirestore.instance;

    // 1. Get the list of all student UIDs in the class
    final classDoc = await firestore.collection('classes').doc(classId).get();
    final studentIds = List<String>.from(classDoc.data()?['studentIds'] ?? []);

    if (studentIds.isEmpty) {
      return [];
    }

    // 2. Fetch all attendance records for this specific session
    final recordsSnapshot = await firestore
        .collection('attendance_records')
        .where('sessionId', isEqualTo: sessionId)
        .get();
    
    // Create a Set of student UIDs who ARE present
    final presentStudentIds = recordsSnapshot.docs
        .map((doc) => (doc.data())['studentId'] as String)
        .toSet();

    // 3. Fetch user data (name and entryNo) for all enrolled students
    final List<Map<String, dynamic>> reportData = [];
    
    // Note: Firestore 'whereIn' query is limited to 10 items. 
    // We will batch read the user documents to support more than 10 students.
    for (var studentId in studentIds) {
      final userDoc = await firestore.collection('users').doc(studentId).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final isPresent = presentStudentIds.contains(studentId);

        reportData.add({
          'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
          'entryNo': userData['entryNo'] ?? 'N/A',
          'status': isPresent ? 'Present' : 'Absent',
          'isAbsent': !isPresent,
        });
      }
    }
    
    // Sort the list so absent students are at the top (optional)
    reportData.sort((a, b) => a['isAbsent'] ? -1 : 1);

    return reportData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance Report'),
            Text(
              sessionTitle,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchReportData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final report = snapshot.data ?? [];

          if (report.isEmpty) {
            return const Center(child: Text('No students enrolled or report data found.'));
          }

          // Calculate summary statistics
          final totalStudents = report.length;
          final presentCount = report.where((s) => s['status'] == 'Present').length;
          final absentCount = totalStudents - presentCount;

          return Column(
            children: [
              // Summary Header
              _buildSummaryHeader(context, totalStudents, presentCount, absentCount),
              
              const Divider(height: 1),
              
              // List of Student Records
              Expanded(
                child: ListView.builder(
                  itemCount: report.length,
                  itemBuilder: (context, index) {
                    final student = report[index];
                    return _buildStudentRow(context, student);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, int total, int present, int absent) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total', total.toString(), Colors.blue),
          _buildSummaryItem('Present', present.toString(), Colors.green),
          _buildSummaryItem('Absent', absent.toString(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentRow(BuildContext context, Map<String, dynamic> student) {
    final isAbsent = student['isAbsent'] as bool;
    return ListTile(
      tileColor: isAbsent ? Colors.red.withOpacity(0.05) : null,
      leading: CircleAvatar(
        backgroundColor: isAbsent ? Colors.red : Colors.green,
        child: Text(
          student['name'][0],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        student['name'],
        style: TextStyle(fontWeight: isAbsent ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Text('Entry No: ${student['entryNo']}'),
      trailing: Chip(
        label: Text(student['status']),
        backgroundColor: isAbsent ? Colors.red : Colors.green,
        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      onTap: () {
        // Optional: Show a dialog with full student details
      },
    );
  }
}