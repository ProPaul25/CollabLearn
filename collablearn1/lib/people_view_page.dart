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

    // The logic to handle more than 10 UIDs remains correct but complex.
    // Assuming you have less than 10 UIDs for now, or using batching for production:
    
    // For simplicity and safety against the 10-item limit:
    final List<Map<String, dynamic>> userList = [];
    for (var uid in uids) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
            // Ensure data() is not null before using the spread operator
            final data = doc.data();
            if (data != null) {
                userList.add({...data, 'uid': doc.id});
            }
        }
    }
    return userList;
    
    /* If you prefer the batch method for fewer than 10 UIDs:
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: uids)
        .get();

    return snapshot.docs.map((doc) => {...doc.data()!, 'uid': doc.id}).toList();
    */
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
        // Ensure instructorId is treated as a String, or default to an empty string
        final instructorId = (classData['instructorId'] as String?) ?? ''; 
        final studentUids = classData['students'] as List<dynamic>? ?? [];

        // Now, fetch the details for the instructor and all students
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
                // Fallback for instructor if not found in users collection
                orElse: () => {'name': 'Unknown Instructor', 'email': 'N/A'});
            final students = allUsers.where((user) => user['uid'] != instructorId).toList();

            // --- CRITICAL FIX 1: Safely access instructor data ---
            final instructorName = instructor['name']?.toString() ?? 'Name N/A';
            final instructorEmail = instructor['email']?.toString() ?? 'Email N/A';


            // Safely sort students (handles null 'name' by treating it as an empty string)
            students.sort((a, b) {
              final aName = a['name']?.toString() ?? '';
              final bName = b['name']?.toString() ?? '';
              return aName.compareTo(bName);
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
                    instructorName, // Safely accessed name
                    instructorEmail, // Safely accessed email
                    Icons.school),
                
                const SizedBox(height: 30),

                // --- STUDENTS SECTION ---
                Text(
                  'Students (${students.length})',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
                const Divider(),
                // --- CRITICAL FIX 2: Safely access student data in the map ---
                ...students.map((student) {
                  final studentName = student['name']?.toString() ?? 'Name N/A';
                  final studentEmail = student['email']?.toString() ?? 'Email N/A';
                  
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
  
  // Helper widget to display a single user
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