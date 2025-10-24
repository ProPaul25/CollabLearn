// lib/announcement_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'stream_page.dart'; // Import to use the Announcement model

class AnnouncementDetailPage extends StatelessWidget {
  final Announcement announcement;

  const AnnouncementDetailPage({
    super.key,
    required this.announcement,
  });

  // Helper function to format the timestamp
  String _formatTimestamp(Timestamp timestamp) {
    return '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} at ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement Details'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Announcement Title
            Text(
              announcement.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 15),

            // Metadata: Posted By and Date
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  announcement.postedBy,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const Spacer(),
                const Icon(Icons.schedule, size: 18, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  _formatTimestamp(announcement.postedOn),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 30),

            // Announcement Content
            Text(
              announcement.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            
            // You can add a Comments/Discussion section here later
            const SizedBox(height: 40),
            Center(
              child: Text(
                '--- End of Announcement ---',
                style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}