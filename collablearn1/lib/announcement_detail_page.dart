// lib/announcement_detail_page.dart 

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// FIX: Explicitly import the Announcement model from its source
import 'stream_page.dart' show Announcement; 
import 'create_announcement_page.dart';

class AnnouncementDetailPage extends StatefulWidget {
  final Announcement announcement; 

  const AnnouncementDetailPage({
    super.key,
    required this.announcement,
  });

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  late Announcement _currentAnnouncement;

  @override
  void initState() {
    super.initState();
    _currentAnnouncement = widget.announcement;
  }

  String _formatTimestamp(Timestamp timestamp) {
    return '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} at ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}';
  }

  bool get _isOriginalPoster {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == _currentAnnouncement.postedById;
  }

  // --- START CONFLICT ZONE RESOLVED ---
  Future<void> _deleteAnnouncement() async {
    debugPrint('Attempting to delete announcement with ID: "${_currentAnnouncement.id}"');
    
    if (_currentAnnouncement.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Announcement ID is missing.')),
        );
      }
      return;
    }

    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this announcement? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        
        // 1. Delete the announcement document
        final announcementRef = FirebaseFirestore.instance
            .collection('announcements')
            .doc(_currentAnnouncement.id);
        batch.delete(announcementRef);
        
        // 2. Find and delete the corresponding class_feed entry
        final feedQuery = await FirebaseFirestore.instance
            .collection('class_feed')
            .where('announcementId', isEqualTo: _currentAnnouncement.id)
            .where('type', isEqualTo: 'announcement')
            .limit(1)
            .get();
        
        if (feedQuery.docs.isNotEmpty) {
          batch.delete(feedQuery.docs.first.reference);
        }
        
        // Execute the batch delete
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement successfully deleted.')),
          );
          // Pop with 'true' so StreamPage can refresh its list
          Navigator.of(context).pop(true); 
        }
      } catch (e) {
        debugPrint('Error deleting announcement: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete announcement: $e')),
          );
        }
      }
    }
  }
  // --- END CONFLICT ZONE RESOLVED (The entire function body was kept) ---


  void _editAnnouncement() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateAnnouncementPage(
          classId: _currentAnnouncement.courseId,
          announcementId: _currentAnnouncement.id,
          announcementData: {
            'title': _currentAnnouncement.title,
            'content': _currentAnnouncement.content,
          },
        ),
      ),
    );
    
    if (result == true) {
      try {
        final updatedDoc = await FirebaseFirestore.instance
            .collection('announcements')
            .doc(_currentAnnouncement.id)
            .get();
        
        // FIX: Re-fetch the updated Announcement using the factory method defined in stream_page.dart
        if (updatedDoc.exists) {
          setState(() {
            _currentAnnouncement = Announcement.fromFirestore(updatedDoc);
          });
        }
      } catch (e) {
        debugPrint('Error refreshing announcement after edit: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement Details'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isOriginalPoster)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editAnnouncement();
                } else if (value == 'delete') {
                  _deleteAnnouncement();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit Announcement'),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete Announcement', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Announcement Title
            Text(
              _currentAnnouncement.title,
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
                  _currentAnnouncement.postedBy,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const Spacer(),
                const Icon(Icons.schedule, size: 18, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  _formatTimestamp(_currentAnnouncement.postedOn),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 30),

            // Announcement Content
            Text(
              _currentAnnouncement.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            
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