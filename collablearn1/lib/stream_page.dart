// lib/stream_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_announcement_page.dart'; // Import for the new page
import 'announcement_detail_page.dart'; // Import for the new page

// --- DATA MODEL (MUST MATCH ANNOUNCEMENT STRUCTURE) ---
class Announcement {
  final String id;
  final String title;
  final String content;
  final String postedBy;
  final Timestamp postedOn;
  final String courseId;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.postedBy,
    required this.postedOn,
    required this.courseId,
  });
  
  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Announcement data is null");
    return Announcement(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      content: data['content'] ?? 'No content provided.',
      postedBy: data['postedBy'] ?? 'Unknown User',
      postedOn: data['postedOn'] ?? Timestamp.now(),
      courseId: data['courseId'] ?? '',
    );
  }
}
// --- END DATA MODEL ---

class StreamPage extends StatelessWidget {
  final String classId;

  const StreamPage({
    super.key,
    required this.classId,
  });

  // --- FIRESTORE STREAMS & QUERIES ---

  // 1. Real-time Stream for Announcements
  Stream<List<Announcement>> getAnnouncementsStream(String courseId) {
    return FirebaseFirestore.instance
        .collection('announcements')
        .where('courseId', isEqualTo: courseId)
        .orderBy('postedOn', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Announcement.fromFirestore(doc))
          .toList();
    });
  }

  // 2. Future to fetch Course Metadata (Instructor Name and Student Count)
  Future<Map<String, dynamic>> _fetchCourseMetadata(String classId) async {
    final courseDoc = await FirebaseFirestore.instance.collection('classes').doc(classId).get();
    final courseData = courseDoc.data();

    if (courseData == null) {
      return {'instructorName': 'N/A', 'studentsEnrolled': 0};
    }

    // Fetch Instructor Name
    String instructorName = 'Instructor Unknown';
    final instructorId = courseData['instructorId'];
    if (instructorId != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(instructorId).get();
      instructorName = userDoc.data()?['name'] ?? 'Instructor';
    }

    // Calculate Student Count (assumes 'students' is a List field on the class document)
    final studentsEnrolled = (courseData['students'] as List?)?.length ?? 0;
    
    return {
      'instructorName': instructorName,
      'studentsEnrolled': studentsEnrolled,
    };
  }

  // --- UI BUILDING STARTS HERE ---
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return StreamBuilder<List<Announcement>>(
      stream: getAnnouncementsStream(classId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading class feed: ${snapshot.error.toString()}'));
        }

        final announcements = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // *** TODO 3 COMPLETED: Dynamic Course Info Card ***
              _buildDynamicCourseInfoCard(context, primaryColor, classId),

              const SizedBox(height: 20),
              
              // *** TODO 1 COMPLETED: New Post Button with Navigation ***
              _buildNewPostButton(context),

              const SizedBox(height: 20),

              Text(
                'Recent Announcements',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (announcements.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(child: Text('No announcements posted yet for this course.')),
                )
              else
                ...announcements.map((announcement) => _buildAnnouncementCard(context, announcement)).toList(),
            ],
          ),
        );
      },
    );
  }

  // --- Helper Widgets ---

  // Refactored to fetch dynamic course data
  Widget _buildDynamicCourseInfoCard(BuildContext context, Color primaryColor, String id) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchCourseMetadata(id),
      builder: (context, snapshot) {
        final instructorName = snapshot.data?['instructorName'] ?? 'Loading...';
        final studentsEnrolled = snapshot.data?['studentsEnrolled'] ?? '...';
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Class Code:', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70)),
              const SizedBox(height: 5),
              Text(
                id.replaceAll('course-', '').toUpperCase(), 
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white38),
              const SizedBox(height: 10),
              // DYNAMIC INSTRUCTOR NAME
              Text(
                'Instructor: $instructorName',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 5),
              // DYNAMIC STUDENT COUNT
              Text(
                'Students Enrolled: $studentsEnrolled', 
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  // Refactored to navigate to the CreateAnnouncementPage
  Widget _buildNewPostButton(BuildContext context) {
    // NOTE: This logic assumes the currently logged-in user is an instructor.
    // In a final app, you must add an explicit check for the user's role 
    // (e.g., fetching user role from Firestore) before showing this button.
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // Navigate to the new creation page, passing the classId
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CreateAnnouncementPage(classId: classId),
            ),
          );
        },
        icon: const Icon(Icons.add_box_rounded),
        label: const Text('Share something with your class'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  // Refactored to navigate to the AnnouncementDetailPage
  Widget _buildAnnouncementCard(BuildContext context, Announcement announcement) {
    String timeAgo(Timestamp timestamp) {
      final duration = DateTime.now().difference(timestamp.toDate());
      if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
      if (duration.inHours < 24) return '${duration.inHours}h ago';
      return '${timestamp.toDate().day}/${timestamp.toDate().month}'; 
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: const CircleAvatar(
          backgroundColor: Colors.blueAccent,
          child: Icon(Icons.campaign_outlined, color: Colors.white),
        ),
        title: Text(
          announcement.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(announcement.content, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(
              'Posted by ${announcement.postedBy} • ${timeAgo(announcement.postedOn)}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          // Navigate to the full announcement detail view
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AnnouncementDetailPage(announcement: announcement),
            ),
          );
        },
      ),
    );
  }
}