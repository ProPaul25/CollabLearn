// lib/models/announcement.dart (You would typically put this in a separate file)

import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Factory constructor to create an Announcement from a Firestore DocumentSnapshot
  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    // Safety checks for required fields
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