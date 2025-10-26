// lib/stream_page.dart - CORRECTED

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import for the detail page
import 'announcement_detail_page.dart'; 

// --- DATA MODEL (Unchanged) ---
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

  // 1. Real-time Stream for Announcements (Unchanged)
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

  // --- UI BUILDING STARTS HERE (NOW SIMPLIFIED) ---
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: getAnnouncementsStream(classId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Use a smaller, centered indicator as this is now an embedded widget
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading class feed: ${snapshot.error.toString()}'));
        }

        final announcements = snapshot.data ?? [];

        // --- FIX: Return a Column directly ---
        // This widget is now just the list of posts (or an empty message)
        // It no longer has its own scrolling, padding, or extra UI elements
        return Column(
          children: [
            if (announcements.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Center(child: Text('No announcements posted yet for this course.')),
              )
            else
              // Create a list of widgets and expand them into the Column
              ...announcements.map((announcement) => _buildAnnouncementCard(context, announcement)).toList(),
          ],
        );
      },
    );
  }

  // --- Helper Widgets (Unchanged) ---

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

  // --- REMOVED _fetchCourseMetadata ---
  // --- REMOVED _buildDynamicCourseInfoCard ---
  // --- REMOVED _buildNewPostButton ---
}