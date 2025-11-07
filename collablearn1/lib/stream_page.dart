// lib/stream_page.dart - COMPLETELY FIXED

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'announcement_detail_page.dart'; 

// --- DATA MODEL ---
class Announcement {
  final String id;
  final String title;
  final String content;
  final String postedBy;
  final Timestamp postedOn;
  final String courseId;
  final String postedById;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.postedBy,
    required this.postedOn,
    required this.courseId,
    required this.postedById,
  });
  
  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Announcement data is null");
    
    return Announcement(
      id: doc.id, // This captures the Firestore document ID
      title: data['title'] ?? 'No Title',
      content: data['content'] ?? 'No content provided.',
      postedBy: data['postedBy'] ?? 'Unknown User',
      postedOn: data['postedOn'] ?? Timestamp.now(),
      courseId: data['courseId'] ?? '',
      postedById: data['postedById'] ?? '',
    );
  }
}

class StreamPage extends StatefulWidget {
  final String classId;

  const StreamPage({
    super.key,
    required this.classId,
  });

  @override
  State<StreamPage> createState() => _StreamPageState();
}

class _StreamPageState extends State<StreamPage> {
  
  Stream<List<Announcement>> getAnnouncementsStream(String courseId) {
    return FirebaseFirestore.instance
        .collection('announcements')
        .where('courseId', isEqualTo: courseId)
        .orderBy('postedOn', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        print('📄 Document ID from Firestore: ${doc.id}'); // Debug print
        return Announcement.fromFirestore(doc);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: getAnnouncementsStream(widget.classId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading class feed: ${snapshot.error.toString()}'));
        }

        final announcements = snapshot.data ?? [];

        return Column(
          children: [
            if (announcements.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Center(child: Text('No announcements posted yet for this course.')),
              )
            else
              ...announcements.map((announcement) => _buildAnnouncementCard(context, announcement)).toList(),
          ],
        );
      },
    );
  }

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
        onTap: () async {
          print('🔍 Tapping card with announcement ID: "${announcement.id}"'); // Debug
          
          // Navigate and wait for result
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AnnouncementDetailPage(announcement: announcement),
            ),
          );
          
          // If announcement was deleted or edited, the stream will auto-refresh
          // No manual refresh needed since we're using StreamBuilder
          if (result == true && mounted) {
            // Optional: Show a snackbar or do nothing, stream handles it
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Changes saved'), duration: Duration(seconds: 1)),
            );
          }
        },
      ),
    );
  }
}
