// lib/doubt_polls_view_page.dart - CORRECTED

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_doubt_poll_page.dart';
import 'package:collablearn1/doubt_poll_detail_page.dart';

// --- 1. DATA MODEL UPDATED ---
class DoubtPoll {
  final String id;
  final String question;
  final String postedBy;
  final String postedById;
  final Timestamp postedOn;
  final int answersCount;
  final int upvotes;
  final List<dynamic> upvotedBy;

  DoubtPoll({
    required this.id,
    required this.question,
    required this.postedBy,
    required this.postedById,
    required this.postedOn,
    required this.answersCount,
    required this.upvotes,
    required this.upvotedBy,
  });

  factory DoubtPoll.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Doubt Poll data is null");
    return DoubtPoll(
      id: doc.id,
      question: data['question'] ?? 'No Question Title',
      postedBy: data['postedBy'] ?? 'Unknown User',
      postedById: data['postedById'] ?? '',
      postedOn: data['postedOn'] ?? Timestamp.now(),
      answersCount: data['answersCount'] ?? 0,
      upvotes: data['upvotes'] ?? 0,
      upvotedBy: data['upvotedBy'] ?? [],
    );
  }
}

class DoubtPollsViewPage extends StatelessWidget {
  final String classId;

  const DoubtPollsViewPage({
    super.key,
    required this.classId,
  });

  // --- 2. STREAM SORTING UPDATED ---
  Stream<List<DoubtPoll>> getDoubtPollsStream(String courseId) {
    return FirebaseFirestore.instance
        .collection('doubt_polls')
        .where('courseId', isEqualTo: courseId)
        .orderBy('upvotes', descending: true)
        .orderBy('postedOn', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DoubtPoll.fromFirestore(doc))
          .toList();
    });
  }

  // --- 3. UPVOTE LOGIC ---
  Future<void> _toggleUpvote(BuildContext context, DoubtPoll poll, String currentUserId) async {
    if (poll.postedById == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot upvote your own post.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final docRef = FirebaseFirestore.instance.collection('doubt_polls').doc(poll.id);

    if (poll.upvotedBy.contains(currentUserId)) {
      await docRef.update({
        'upvotes': FieldValue.increment(-1),
        'upvotedBy': FieldValue.arrayRemove([currentUserId])
      });
    } else {
      await docRef.update({
        'upvotes': FieldValue.increment(1),
        'upvotedBy': FieldValue.arrayUnion([currentUserId])
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
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
              return _buildDoubtPollCard(context, poll, currentUserId);
            },
          );
        },
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CreateDoubtPollPage(classId: classId),
            ),
          );
        },
        label: const Text('Ask a Doubt'),
        icon: const Icon(Icons.add_comment),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
  
  // --- 5. CARD UI UPDATED (NAVIGATION) ---
  Widget _buildDoubtPollCard(BuildContext context, DoubtPoll poll, String currentUserId) {
    String timeAgo(Timestamp timestamp) {
      final duration = DateTime.now().difference(timestamp.toDate());
      if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
      if (duration.inHours < 24) return '${duration.inHours}h ago';
      return '${timestamp.toDate().day}/${timestamp.toDate().month}';
    }

    final bool isUpvoted = poll.upvotedBy.contains(currentUserId);
    final bool isAuthor = poll.postedById == currentUserId;
    
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          // --- NAVIGATION SIMPLIFIED ---
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DoubtPollDetailPage(
                pollId: poll.id,
                classId: classId,
                // Pass the initial data to avoid a loading flash
                initialPollData: {
                  'question': poll.question,
                  'postedBy': poll.postedBy,
                  'postedById': poll.postedById,
                  'postedOn': poll.postedOn,
                  'answersCount': poll.answersCount,
                },
              ),
            ),
          );
          // --- END NAVIGATION ---
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                poll.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 5),
              Text(
                'Posted by ${poll.postedBy}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // --- Upvote Button ---
                  InkWell(
                    onTap: () => _toggleUpvote(context, poll, currentUserId),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            isUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                            size: 18, 
                            color: isAuthor ? Colors.grey : (isUpvoted ? primaryColor : Colors.black54)
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${poll.upvotes}', 
                            style: TextStyle(
                              color: isAuthor ? Colors.grey : (isUpvoted ? primaryColor : Colors.black54), 
                              fontWeight: FontWeight.w600,
                              fontSize: 14
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  // --- Answers Button ---
                  Row(
                    children: [
                      Icon(Icons.comment_outlined, size: 18, color: Colors.green),
                      const SizedBox(width: 5),
                      Text(
                        '${poll.answersCount} Answers', 
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 14)
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(timeAgo(poll.postedOn), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}