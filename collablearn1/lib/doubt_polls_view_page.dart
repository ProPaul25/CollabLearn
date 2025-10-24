// lib/doubt_polls_view_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_doubt_poll_page.dart'; // Import to link the creation page

// Simplified Model for Display (You should move this to lib/models/doubt_poll.dart later)
class DoubtPoll {
  final String id;
  final String question;
  final String postedBy;
  final Timestamp postedOn;
  final int answersCount;
  final int upvotes;

  DoubtPoll({
    required this.id,
    required this.question,
    required this.postedBy,
    required this.postedOn,
    required this.answersCount,
    required this.upvotes,
  });

  factory DoubtPoll.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Doubt Poll data is null");
    return DoubtPoll(
      id: doc.id,
      question: data['question'] ?? 'No Question Title',
      postedBy: data['postedBy'] ?? 'Unknown User',
      postedOn: data['postedOn'] ?? Timestamp.now(),
      answersCount: data['answersCount'] ?? 0,
      upvotes: data['upvotes'] ?? 0,
    );
  }
}

class DoubtPollsViewPage extends StatelessWidget {
  final String classId;

  const DoubtPollsViewPage({
    super.key,
    required this.classId,
  });

  Stream<List<DoubtPoll>> getDoubtPollsStream(String courseId) {
    return FirebaseFirestore.instance
        .collection('doubt_polls')
        .where('courseId', isEqualTo: courseId)
        .orderBy('postedOn', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DoubtPoll.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The content of the Discussion tab
      body: StreamBuilder<List<DoubtPoll>>(
        stream: getDoubtPollsStream(classId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading doubts: ${snapshot.error.toString()}'));
          }

          final polls = snapshot.data ?? [];

          if (polls.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'No doubts have been posted yet. Be the first to ask one!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: polls.length,
            itemBuilder: (context, index) {
              final poll = polls[index];
              return _buildDoubtPollCard(context, poll);
            },
          );
        },
      ),
      
      // Floating Action Button to ask a doubt
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigates to the creation page, allowing instructors or students to post
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CreateDoubtPollPage(classId: classId),
            ),
          );
        },
        label: const Text('Ask a Doubt'),
        icon: const Icon(Icons.add_comment),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
      ),
    );
  }
  
  // Helper to build the visual card for a single doubt poll
  Widget _buildDoubtPollCard(BuildContext context, DoubtPoll poll) {
    String timeAgo(Timestamp timestamp) {
      final duration = DateTime.now().difference(timestamp.toDate());
      if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
      if (duration.inHours < 24) return '${duration.inHours}h ago';
      return '${timestamp.toDate().day}/${timestamp.toDate().month}'; 
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        title: Text(
          poll.question,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              'Posted by ${poll.postedBy}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.thumb_up, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text('${poll.upvotes}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                const SizedBox(width: 15),
                Icon(Icons.comment, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text('${poll.answersCount} Answers', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(timeAgo(poll.postedOn), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        onTap: () {
          // TODO: Navigate to the Doubt Poll Detail Page (where answers are posted)
        },
      ),
    );
  }
}