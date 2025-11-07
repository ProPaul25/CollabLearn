// lib/announcement_detail_page.dart - MODIFIED FOR EDIT/DELETE UI

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW IMPORT
import 'stream_page.dart'; // Import to use the Announcement model
import 'create_announcement_page.dart'; // NEW IMPORT

// Change to StatefulWidget
class AnnouncementDetailPage extends StatefulWidget {
  // NOTE: If you need to refresh, the final field may cause issues. 
  // We'll keep it final but re-fetch data on edit success in the state class.
  final Announcement announcement; 

  const AnnouncementDetailPage({
    super.key,
    required this.announcement,
  });

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  // Use a mutable variable to hold the announcement data for refreshing
  late Announcement _currentAnnouncement;

  @override
  void initState() {
    super.initState();
    _currentAnnouncement = widget.announcement;
  }

  // Helper function to format the timestamp
  String _formatTimestamp(Timestamp timestamp) {
    return '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} at ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}';
  }

  // NEW: Check if the current user is the poster
  bool get _isOriginalPoster {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == _currentAnnouncement.postedById;
  }

  // NEW: Delete Confirmation Dialog and Logic
  Future<void> _deleteAnnouncement() async {
  debugPrint('Attempting to delete announcement with ID: "${_currentAnnouncement.id}"');
  debugPrint('ID length: ${_currentAnnouncement.id.length}');
  if (_currentAnnouncement.id.isEmpty) {
    // Show an error or simply stop the operation
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
        await FirebaseFirestore.instance
            .collection('announcements')
            .doc(_currentAnnouncement.id)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement successfully deleted.')),
          );
          // Pop with 'true' so StreamPage can refresh its list
          Navigator.of(context).pop(true); 
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete announcement: $e')),
          );
        }
      }
    }
  }

  // NEW: Function to navigate to Edit page and refresh
  void _editAnnouncement() async {
debugPrint('Editing announcement with ID: "${_currentAnnouncement.id}"');
  debugPrint('Course ID: ${_currentAnnouncement.courseId}');

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateAnnouncementPage(
          classId: _currentAnnouncement.courseId,
          announcementId: _currentAnnouncement.id,
          // Pass the data for pre-filling
          announcementData: {
            'title': _currentAnnouncement.title,
            'content': _currentAnnouncement.content,
          },
        ),
      ),
    );
    
    // When returning from the edit page, if successful (result == true), re-fetch the data
    if (result == true) {
      try {
        final updatedDoc = await FirebaseFirestore.instance
            .collection('announcements')
            .doc(_currentAnnouncement.id)
            .get();
        
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
            
            // ... (Rest of the body) ...
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