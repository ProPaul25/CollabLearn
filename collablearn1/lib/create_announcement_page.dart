// lib/create_announcement_page.dart - CORRECTED WITH CLASS FEED UPDATE

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateAnnouncementPage extends StatefulWidget {
  final String classId;
  final Map<String, dynamic>? announcementData;
  final String? announcementId; 

  const CreateAnnouncementPage({
    super.key,
    required this.classId,
    this.announcementData,
    this.announcementId,
  });

  @override
  State<CreateAnnouncementPage> createState() => _CreateAnnouncementPageState();
}

class _CreateAnnouncementPageState extends State<CreateAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;
  late bool _isEditing;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.announcementData != null && widget.announcementId != null;
    
    if (_isEditing) {
      _titleController.text = widget.announcementData!['title'] ?? '';
      _contentController.text = widget.announcementData!['content'] ?? '';
    }
  }

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
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userName = await _getCurrentUserName();
      final collection = FirebaseFirestore.instance.collection('announcements');
      
      final data = {
        'courseId': widget.classId,
        'title': _titleController.text,
        'content': _contentController.text,
        'postedBy': userName,
        'postedById': user!.uid,
      };

      String announcementId;

      if (_isEditing && widget.announcementId != null) {
        // --- EDIT LOGIC ---
        announcementId = widget.announcementId!;
        await collection.doc(announcementId).update({
          ...data, 
          'lastUpdatedOn': FieldValue.serverTimestamp(),
        });
        
        // Update the class_feed entry
        final feedQuery = await FirebaseFirestore.instance
            .collection('class_feed')
            .where('announcementId', isEqualTo: announcementId)
            .where('courseId', isEqualTo: widget.classId)
            .limit(1)
            .get();
        
        if (feedQuery.docs.isNotEmpty) {
          await feedQuery.docs.first.reference.update({
            'title': _titleController.text,
            'content': _contentController.text,
            'lastActivityTimestamp': FieldValue.serverTimestamp(),
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement successfully updated!')),
          );
        }
      } else {
        // --- CREATE LOGIC ---
        final docRef = await collection.add({
          ...data,
          'postedOn': FieldValue.serverTimestamp(),
        });
        
        announcementId = docRef.id;
        
        // Create class_feed entry with the announcement ID
        await FirebaseFirestore.instance.collection('class_feed').add({
          'type': 'announcement',
          'announcementId': announcementId,  // CRITICAL: Store the announcement ID
          'courseId': widget.classId,
          'title': _titleController.text,
          'content': _contentController.text,
          'postedBy': userName,
          'postedById': user.uid,
          'lastActivityTimestamp': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement successfully posted!')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true); 
      }
    } catch (e) {
      debugPrint('Error posting/updating announcement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post/update announcement: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Announcement' : 'Create Announcement'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Class Cancelled Today',
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
                        : Icon(_isEditing ? Icons.save : Icons.send),
                    label: Text(_isLoading ? 'Saving...' : (_isEditing ? 'Save Changes' : 'Post Announcement')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
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
      ),
    );
  }
}