// lib/create_doubt_poll_page.dart - CORRECTED

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateDoubtPollPage extends StatefulWidget {
  final String classId;

  const CreateDoubtPollPage({
    super.key,
    required this.classId,
  });

  @override
  State<CreateDoubtPollPage> createState() => _CreateDoubtPollPageState();
}

class _CreateDoubtPollPageState extends State<CreateDoubtPollPage> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _questionController.dispose();
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
      
      return name.isEmpty ? (user.email ?? 'Unknown User') : name;
    }
    return 'Unknown User';
  }

  Future<void> _postDoubtPoll() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final userName = await _getCurrentUserName();
      final user = FirebaseAuth.instance.currentUser!;
      final postTime = Timestamp.now();
      
      // --- FIX: Use a batch write ---
      final batch = FirebaseFirestore.instance.batch();

      // 1. Create the original doubt poll
      final pollRef = FirebaseFirestore.instance.collection('doubt_polls').doc();
      batch.set(pollRef, {
        'question': _questionController.text.trim(),
        'courseId': widget.classId,
        'postedBy': userName,
        'postedById': user.uid,
        'postedOn': postTime,
        'answersCount': 0,
        'upvotes': 0,
        'upvotedBy': [],
        'finalAnswerIds': []
      });
      
      // 2. Create the unified class_feed item
      final feedRef = FirebaseFirestore.instance.collection('class_feed').doc();
      batch.set(feedRef, {
        'type': 'doubt', // To identify this item in the feed
        'question': _questionController.text.trim(),
        'courseId': widget.classId,
        'postedBy': userName,
        'postedById': user.uid,
        'lastActivityTimestamp': postTime, // Used for sorting
        'pollId': pollRef.id, // Link to the original poll
        'answersCount': 0, // Store this here for the UI
        'upvotes': 0, // Store this here for the UI
      });
      
      await batch.commit();
      // --- END OF FIX ---

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doubt Poll posted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post doubt: $e'), backgroundColor: Colors.red),
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
        title: const Text('Ask a New Doubt'),
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
              const Text(
                'Post your question clearly for your peers and instructor.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _questionController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Your Doubt/Question',
                  hintText: 'e.g., "What is the difference between Future and Stream in Dart?"',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 120, left: 8),
                    child: Icon(Icons.help_outline),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'A question is required to post a doubt.' : null,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _postDoubtPoll,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(_isLoading ? 'Submitting...' : 'Post Doubt Poll'),
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