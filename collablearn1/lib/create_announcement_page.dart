// lib/create_announcement_page.dart - CORRECTED

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateAnnouncementPage extends StatefulWidget {
  final String classId;

  const CreateAnnouncementPage({
    super.key,
    required this.classId,
  });

  @override
  State<CreateAnnouncementPage> createState() => _CreateAnnouncementPageState();
}

class _CreateAnnouncementPageState extends State<CreateAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<String> _getCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      final String firstName = data?['firstName'] ?? '';
      final String lastName = data?['lastName'] ?? '';
      final String name = "$firstName $lastName".trim();
      return name.isEmpty ? (user.email ?? 'Instructor') : name;
    }
    return 'Instructor';
  }

  Future<void> _postAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final userName = await _getCurrentUserName();
      final user = FirebaseAuth.instance.currentUser!;
      final postTime = Timestamp.now();
      
      // --- FIX: Use a batch write ---
      final batch = FirebaseFirestore.instance.batch();

      // 1. Create the original announcement
      final announcementRef = FirebaseFirestore.instance.collection('announcements').doc();
      batch.set(announcementRef, {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'courseId': widget.classId,
        'postedBy': userName,
        'postedOn': postTime,
        'postedById': user.uid,
      });

      // 2. Create the unified class_feed item
      final feedRef = FirebaseFirestore.instance.collection('class_feed').doc();
      batch.set(feedRef, {
        'type': 'announcement', // To identify this item in the feed
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'courseId': widget.classId,
        'postedBy': userName,
        'postedById': user.uid,
        'lastActivityTimestamp': postTime, // Used for sorting
        'pollId': null, // Not a poll
      });
      
      await batch.commit();
      // --- END OF FIX ---

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement posted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post announcement: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (UI is unchanged)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Announcement'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (e.g., Exam Date Change)',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
                validator: (value) => value!.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contentController,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Announcement Details',
                  hintText: 'Provide details here...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
                validator: (value) => value!.isEmpty ? 'Content is required' : null,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _postAnnouncement,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(_isLoading ? 'Posting...' : 'Post Announcement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}