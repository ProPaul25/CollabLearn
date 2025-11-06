// lib/people_view_page.dart - UPDATED WITH BUTTONS AND INSTRUCTOR CHECK

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// NOTE: Ensure these two files exist and contain the navigation logic
import 'add_co_instructor_page.dart'; 
import 'add_student_page.dart'; 

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
  late final Future<bool> _isInstructorFuture;

  @override
  void initState() {
    super.initState();
    // Start fetching instructor status immediately
    _isInstructorFuture = _isCurrentUserInstructor();
  }

  // Determine if the current user is the main instructor for this class
  Future<bool> _isCurrentUserInstructor() async {
    if (_currentUser == null) return false;
    
    // NOTE: This currently checks against a single 'instructorId' field, 
    // consistent with your other files. For co-teachers, your Firestore 
    // structure should use an 'instructorIds' array and check membership.
    try {
      final classDoc = await FirebaseFirestore.instance.collection('classes').doc(widget.classId).get();
      final data = classDoc.data();
      if (data == null) return false;
      return data['instructorId'] == _currentUser!.uid;
    } catch (e) {
      debugPrint('Error checking instructor status: $e');
      return false;
    }
  }


  // A helper to fetch user data for a list of UIDs
  Future<List<Map<String, dynamic>>> _fetchUsersByIds(List<dynamic> uids) async {
    if (uids.isEmpty) return [];
    
    final List<Map<String, dynamic>> userList = [];
    // Using a loop is necessary if the list size can exceed the 10-item 'whereIn' limit
    for (var uid in uids) {
        if (uid is String && uid.isNotEmpty) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists) {
              final data = doc.data();
              if (data != null) {
                  userList.add({...data, 'uid': doc.id});
              }
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
    return name.isEmpty ? "Unnamed User" : name; 
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Use a FutureBuilder to wait for both the class data and the instructor status
    return FutureBuilder<bool>(
      future: _isInstructorFuture,
      builder: (context, instructorSnapshot) {
        final bool isInstructor = instructorSnapshot.data ?? false;

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('classes').doc(widget.classId).get(),
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
            // For now, only using the main instructorId
            final instructorId = (classData['instructorId'] as String?) ?? ''; 
            
            // To support co-teachers, you'd use 'instructorIds' array here. 
            // We'll stick to 'instructorId' to match existing logic.
            final studentUids = classData['studentIds'] as List<dynamic>? ?? [];

            final allUserIds = [instructorId, ...studentUids].where((uid) => uid.isNotEmpty).toList();

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchUsersByIds(allUserIds),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allUsers = userSnapshot.data ?? [];
                
                final instructor = allUsers.firstWhere(
                    (user) => user['uid'] == instructorId,
                    orElse: () => {'firstName': 'Unknown', 'lastName': 'Instructor', 'email': 'N/A'}); 
                
                final students = allUsers.where((user) => user['uid'] != instructorId).toList();

                final String instructorName = _getUserName(instructor);
                final String instructorEmail = instructor['email']?.toString() ?? 'N/A';

                students.sort((a, b) => _getUserName(a).compareTo(_getUserName(b)));

                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // --- INSTRUCTOR SECTION ---
                    Text(
                      'Instructor',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    const Divider(),
                    _buildUserTile(context, instructorName, instructorEmail, Icons.school),
                    
                    // 1. ADD CO-TEACHER BUTTON (Bottom of Teacher's Section)
                    if (isInstructor)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 30),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AddCoInstructorPage(classId: widget.classId),
                              ),
                            );
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
                      
                      return _buildUserTile(context, studentName, studentEmail, Icons.person);
                    }).toList(),

                    // 2. ADD STUDENT BUTTON (Bottom of Student's Section)
                    if (isInstructor)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AddStudentPage(classId: widget.classId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add Student to Course'),
                          style: FilledButton.styleFrom(backgroundColor: primaryColor),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
  
  Widget _buildUserTile(BuildContext context, String name, String email, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(email),
        onTap: () {},
      ),
    );
  }
}