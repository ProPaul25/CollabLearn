// lib/people_view_page.dart - CORRECTED VERSION

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PeopleViewPage extends StatelessWidget {
  final String classId;

  const PeopleViewPage({
    super.key,
    required this.classId,
  });

  // A helper to fetch user data for a list of UIDs
  Future<List<Map<String, dynamic>>> _fetchUsersByIds(List<dynamic> uids) async {
    if (uids.isEmpty) return [];
    
    // Using a loop is safer against the 10-item 'whereIn' limit
    final List<Map<String, dynamic>> userList = [];
    for (var uid in uids) {
        // Ensure uid is a non-empty string before querying
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
    return name.isEmpty ? "Unnamed User" : name; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('classes').doc(classId).get(),
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
        final instructorId = (classData['instructorId'] as String?) ?? ''; 
        
        // --- THIS IS THE CRITICAL FIX ---
        // It now reads 'studentIds' instead of 'students'
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
                // Fallback if instructor doc is missing
                orElse: () => {'firstName': 'Unknown', 'lastName': 'Instructor', 'email': 'N/A'}); 
            
            final students = allUsers.where((user) => user['uid'] != instructorId).toList();

            final String instructorName = _getUserName(instructor);
            final String instructorEmail = instructor['email']?.toString() ?? 'N/A';

            // Sort students by their combined name
            students.sort((a, b) {
              return _getUserName(a).compareTo(_getUserName(b));
            });

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // --- INSTRUCTOR SECTION ---
                Text(
                  'Instructor',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
                const Divider(),
                _buildUserTile(
                    context,
                    instructorName,
                    instructorEmail,
                    Icons.school),
                
                const SizedBox(height: 30),

                // --- STUDENTS SECTION ---
                Text(
                  'Students (${students.length})', // This will now show "Students (1)"
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
                const Divider(),
                
                // This will now list your user
                ...students.map((student) {
                  final String studentName = _getUserName(student);
                  final String studentEmail = student['email']?.toString() ?? 'N/A';
                  
                  return _buildUserTile(
                      context,
                      studentName,
                      studentEmail,
                      Icons.person);
                }).toList(),
              ],
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