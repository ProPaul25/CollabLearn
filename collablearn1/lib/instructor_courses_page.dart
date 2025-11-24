// lib/instructor_courses_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'people_view_page.dart';

class InstructorCoursesPage extends StatelessWidget {
  const InstructorCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'), // Title reflects the feature
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query: Find classes where I am the instructor OR a co-instructor
        stream: FirebaseFirestore.instance
            .collection('classes')
            .where(Filter.or(
              Filter('instructorId', isEqualTo: user.uid),
              Filter('instructorIds', arrayContains: user.uid),
            ))
            // Optional: Exclude archived classes if you want
            // .where('isArchived', isNotEqualTo: true) 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final courses = snapshot.data?.docs ?? [];

          if (courses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('You are not teaching any courses yet.'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final doc = courses[index];
              final data = doc.data() as Map<String, dynamic>;
              final className = data['className'] ?? 'Untitled Class';
              final classCode = data['classCode'] ?? 'No Code';
              final studentIds = List.from(data['studentIds'] ?? []);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.1),
                    child: Icon(Icons.school, color: primaryColor),
                  ),
                  title: Text(className, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Code: $classCode • ${studentIds.length} Students'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    // Navigate to PeopleViewPage to show students
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PeopleViewPage(classId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
} 