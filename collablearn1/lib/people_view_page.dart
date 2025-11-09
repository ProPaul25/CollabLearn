// lib/people_view_page.dart - FINAL FIX: Pull-to-Refresh Implemented

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_co_instructor_page.dart'; 
import 'add_student_page.dart'; 
import 'instructor_student_report_page.dart'; 

class PeopleViewPage extends StatefulWidget {
  final String classId;

  const PeopleViewPage({
    super.key,
    required this.classId,
  });

  @override
  State<PeopleViewPage> createState() => _PeopleViewPageState();
}

class _PeopleViewPageState extends State<PeopleViewPage> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  late Future<bool> _isInstructorFuture;
  late Future<DocumentSnapshot<Map<String, dynamic>>> _classDataFuture; // Store data future

  @override
  void initState() {
    super.initState();
    _isInstructorFuture = _isCurrentUserInstructor();
    _classDataFuture = _fetchClassData();
  }

  // Helper to fetch class data
  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchClassData() {
     // Use GetOptions(source: Source.server) for debugging to verify data consistency
     return FirebaseFirestore.instance.collection('classes').doc(widget.classId).get();
  }

  // --- MODIFIED: Return Future<void> for onRefresh ---
  Future<void> _reloadData() async {
    setState(() {
      _isInstructorFuture = _isCurrentUserInstructor();
      _classDataFuture = _fetchClassData(); // Refresh the class data
    });
    // Await the completion of the future used in the build method
    await _classDataFuture; 
  }


  // Determine if the current user is the main instructor or a co-instructor for this class
  Future<bool> _isCurrentUserInstructor() async {
    if (_currentUser == null) return false;
    
    try {
      final classDoc = await _fetchClassData();
      final data = classDoc.data();
      if (data == null) return false;
      
      final instructorIds = List<String>.from(data['instructorIds'] ?? []).where((id) => id.isNotEmpty).toList();
      final primaryInstructorId = (data['instructorId'] as String?) ?? '';

      return instructorIds.contains(_currentUser!.uid) || primaryInstructorId == _currentUser!.uid;
    } catch (e) {
      debugPrint('Error checking instructor status: $e');
      return false;
    }
  }

  // A helper to fetch user data for a list of UIDs
  Future<List<Map<String, dynamic>>> _fetchUsersByIds(List<dynamic> uids) async {
    if (uids.isEmpty) return [];
    
    final List<Map<String, dynamic>> userList = [];
    
    for (var uid in uids) {
        if (uid is String && uid.isNotEmpty) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          
          if (doc.exists) {
              final data = doc.data();
              if (data != null) {
                  userList.add({...data, 'uid': doc.id});
              }
          } else {
            // FIX: Add a distinct, easily recognizable placeholder for debugging
            userList.add({
              'uid': uid,
              'email': 'MISSING USER DATA (UID: $uid)',
              'firstName': 'Missing',
              'lastName': 'Profile'
            });
          }
        }
    }
    return userList;
  }

  // Helper to combine first and last name
  String _getUserName(Map<String, dynamic> userData) {
    final String firstName = userData['firstName']?.toString() ?? '';
    final String lastName = userData['lastName']?.toString() ?? '';
    final name = "$firstName $lastName".trim();
    
    // Check if it's the specific placeholder name
    if (name == 'Missing Profile' && userData['email'] != null) {
        return 'Missing Profile (${userData['email']})';
    }
    return name.isEmpty ? "Unnamed User" : name; 
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return FutureBuilder<bool>(
      future: _isInstructorFuture,
      builder: (context, instructorSnapshot) {
        final bool isInstructor = instructorSnapshot.data ?? false;

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _classDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Class not found.'));
            }

            final classData = snapshot.data!.data()!;
            
            final primaryInstructorId = (classData['instructorId'] as String?) ?? ''; 
            final coInstructorUids = classData['instructorIds'] as List<dynamic>? ?? [];

            // Combine all unique instructor UIDs
            final allInstructorUids = {primaryInstructorId, ...coInstructorUids}.where((uid) => uid.isNotEmpty).toList();

            final studentUids = classData['studentIds'] as List<dynamic>? ?? [];

            final allUserIds = [...allInstructorUids, ...studentUids].where((uid) => uid.isNotEmpty).toList();
            final uniqueAllUserIds = allUserIds.toSet().toList(); // Ensure uniqueness


            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchUsersByIds(uniqueAllUserIds),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allUsers = userSnapshot.data ?? [];
                
                // Separate instructors and students
                final instructors = allUsers.where((user) => allInstructorUids.contains(user['uid'])).toList();
                final students = allUsers.where((user) => studentUids.contains(user['uid']) && !allInstructorUids.contains(user['uid'])).toList(); // Student not an instructor

                // Sort instructors to put the primary one first (if available)
                instructors.sort((a, b) {
                  if (a['uid'] == primaryInstructorId) return -1;
                  if (b['uid'] == primaryInstructorId) return 1;
                  return _getUserName(a).compareTo(_getUserName(b));
                });
                
                students.sort((a, b) => _getUserName(a).compareTo(_getUserName(b)));


                // --- WRAP LISTVIEW IN REFRESH INDICATOR ---
                return RefreshIndicator(
                  onRefresh: _reloadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    physics: const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator
                    children: [
                      // --- INSTRUCTOR SECTION ---
                      Text(
                        'Instructor${instructors.length > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                      const Divider(),
                      ...instructors.map((instructor) {
                        final String instructorName = _getUserName(instructor);
                        final String instructorEmail = instructor['email']?.toString() ?? 'N/A';
                        final String instructorUid = instructor['uid']?.toString() ?? '';
                        final isPrimary = instructorUid == primaryInstructorId;

                        // Pass null onTap for instructors 
                        return _buildUserTile(context, instructorName, instructorEmail, instructorUid, true, isPrimary ? const Icon(Icons.star, color: Colors.amber) : null, null);
                      }).toList(),
                      
                      // 1. ADD CO-TEACHER BUTTON (Bottom of Teacher's Section)
                      if (isInstructor)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 30),
                          child: OutlinedButton.icon(
                            onPressed: () async { // Make onPressed async
                              await Navigator.of(context).push( // Await the result
                                MaterialPageRoute(
                                  builder: (context) => AddCoInstructorPage(classId: widget.classId),
                                ),
                              );
                              _reloadData(); // FIX: Reload data when returning
                            },
                            icon: const Icon(Icons.group_add),
                            label: const Text('Add Co-Teacher'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                      // --- STUDENTS SECTION ---
                      Text(
                        'Students (${students.length})', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                      const Divider(),
                      
                      ...students.map((student) {
                        final String studentName = _getUserName(student);
                        final String studentEmail = student['email']?.toString() ?? 'N/A';
                        final String studentUid = student['uid']?.toString() ?? '';

                        return _buildUserTile(
                          context, 
                          studentName, 
                          studentEmail, 
                          studentUid, 
                          false, // isInstructor flag: false for students
                          isInstructor // Only allow navigation if the current user is the course instructor
                            ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blueGrey)
                            : null,
                          isInstructor // Only allow navigation if the current user is the course instructor
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => InstructorStudentReportPage(
                                      classId: widget.classId,
                                      studentId: studentUid,
                                      studentName: studentName,
                                    ),
                                  ),
                                );
                              } 
                            : null,
                        );
                      }).toList(),

                      // 2. ADD STUDENT BUTTON (Bottom of Student's Section)
                      if (isInstructor)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: FilledButton.icon(
                            onPressed: () async { // Make onPressed async
                              await Navigator.of(context).push( // Await the result
                                MaterialPageRoute(
                                  builder: (context) => AddStudentPage(classId: widget.classId),
                                ),
                              );
                              _reloadData(); // FIX: Reload data when returning
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add Student to Course'),
                            style: FilledButton.styleFrom(backgroundColor: primaryColor),
                          ),
                        ),
                    ],
                  ),
                );
                // --- END REFRESH INDICATOR WRAP ---
              },
            );
          },
        );
      },
    );
  }
  
  // MODIFIED to accept userId and onTap action
  Widget _buildUserTile(BuildContext context, String name, String email, String userId, bool isInstructor, Widget? trailingWidget, VoidCallback? onTap) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final icon = isInstructor ? Icons.school : Icons.person;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Icon(icon, color: primaryColor),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(email),
        // Use the passed trailingWidget
        trailing: trailingWidget, 
        onTap: onTap,
      ),
    );
  }
}