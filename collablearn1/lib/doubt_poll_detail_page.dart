// lib/doubt_poll_detail_page.dart - FULLY UPDATED FOR NESTED REPLIES AND UPVOTE RESTRICTION

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- Data Model for processing replies in memory ---
class ReplyData {
  final String id;
  final Map<String, dynamic> data;
  final List<ReplyData> children = [];
  String get parentId => data['parentId'] as String? ?? '';

  ReplyData(this.id, this.data);
}


class DoubtPollDetailPage extends StatefulWidget {
  final String pollId;
  final String classId;
  final Map<String, dynamic> initialPollData;
  final bool isOriginalPoster;

  const DoubtPollDetailPage({
    super.key,
    required this.pollId,
    required this.classId,
    required this.initialPollData,
    required this.isOriginalPoster,
  });

  @override
  State<DoubtPollDetailPage> createState() => _DoubtPollDetailPageState();
}

class _DoubtPollDetailPageState extends State<DoubtPollDetailPage> {
  final _replyController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  late String _currentUserName = 'Anonymous';

  // State variable to manage the inline reply form
  String? _replyingToId; // Stores the replyId of the comment being replied to
  String? _replyingToName; // Stores the name of the user being replied to

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  // Fetch the current user's display name for posting replies
  Future<void> _loadCurrentUserData() async {
    if (_currentUser == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        if (mounted) {
          setState(() {
            _currentUserName = (userDoc.data()?['firstName'] ?? '') + ' ' + (userDoc.data()?['lastName'] ?? '');
            _currentUserName = _currentUserName.trim().isEmpty ? 'Anonymous' : _currentUserName.trim();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // MARK FINAL ANSWER
  Future<void> _markFinalAnswer(String replyId) async {
    if (!widget.isOriginalPoster) return; 

    try {
      await FirebaseFirestore.instance.collection('doubt_polls').doc(widget.pollId).update({
        'finalAnswerId': replyId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Final answer marked!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error marking final answer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark final answer: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // POST REPLY (Updated to handle parentId)
  Future<void> _postReply({String? parentId}) async {
    if (_replyController.text.trim().isEmpty || _currentUser == null) return;

    final replyText = _replyController.text.trim();
    _replyController.clear();
    // Clear the reply target after posting
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final pollRef = FirebaseFirestore.instance.collection('doubt_polls').doc(widget.pollId);
      final repliesRef = pollRef.collection('replies').doc();

      // 1. Add the new reply to the subcollection
      batch.set(repliesRef, {
        'pollId': widget.pollId,
        'text': replyText,
        'postedById': _currentUser!.uid,
        'postedBy': _currentUserName,
        'timestamp': FieldValue.serverTimestamp(),
        'upvotes': [], 
        'parentId': parentId, // <-- NEW: Used for nesting
      });

      // 2. Increment the answersCount in the main poll document
      batch.update(pollRef, {
        'answersCount': FieldValue.increment(1),
      });

      await batch.commit();

      if (mounted) {
        FocusScope.of(context).unfocus(); 
      }
    } catch (e) {
      debugPrint('Error posting reply: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post reply: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper function to process flat list of documents into a nested structure
  List<ReplyData> _processReplies(List<DocumentSnapshot> docs) {
    // 1. Create a map of all replies for quick lookup
    final Map<String, ReplyData> allReplies = {};
    for (var doc in docs) {
      allReplies[doc.id] = ReplyData(doc.id, doc.data() as Map<String, dynamic>);
    }

    final List<ReplyData> rootReplies = [];

    // 2. Populate the children arrays
    allReplies.forEach((id, reply) {
      if (reply.parentId.isEmpty) {
        // This is a top-level reply
        rootReplies.add(reply);
      } else {
        // This is a nested reply, find its parent and add it to children
        final parent = allReplies[reply.parentId];
        parent?.children.add(reply);
      }
    });

    return rootReplies;
  }
  
  // Recursive function to build the nested list
  List<Widget> _buildNestedReplies(List<ReplyData> replies, String? finalAnswerId, {double depth = 0}) {
    List<Widget> list = [];

    // Sort children by timestamp to ensure they appear chronologically within the thread
    replies.sort((a, b) => (a.data['timestamp'] as Timestamp).compareTo(b.data['timestamp'] as Timestamp));

    for (var reply in replies) {
      list.add(Padding(
        // Add indentation based on depth
        padding: EdgeInsets.only(left: depth > 0 ? 20.0 : 0.0),
        child: Column(
          children: [
            ReplyCard(
              replyDocId: reply.id,
              pollId: widget.pollId,
              reply: reply.data,
              finalAnswerId: finalAnswerId,
              isOriginalPoster: widget.isOriginalPoster,
              onMarkFinal: _markFinalAnswer,
              onReply: (replyId, postedBy) {
                // Set the reply target for the inline form
                setState(() {
                  _replyingToId = replyId;
                  _replyingToName = postedBy;
                });
              },
            ),
            // Recursively build children
            ..._buildNestedReplies(reply.children, finalAnswerId, depth: depth + 1),
          ],
        ),
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion Thread'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Main Question Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.initialPollData['question'] ?? 'Error: Question not found.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Asked by: ${widget.initialPollData['postedBy'] ?? 'Unknown'}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Divider(),
                const Text('Replies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // Replies StreamBuilder (Nested Forum)
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('doubt_polls').doc(widget.pollId).snapshots(),
              builder: (context, pollSnapshot) {
                if (!pollSnapshot.hasData || !pollSnapshot.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pollData = pollSnapshot.data!.data() as Map<String, dynamic>;
                final finalAnswerId = pollData['finalAnswerId'] as String?;

                // Listen to the replies subcollection
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('doubt_polls')
                      .doc(widget.pollId)
                      .collection('replies')
                      .orderBy('timestamp', descending: false) // Fetch flat list
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final replies = snapshot.data?.docs ?? [];
                    if (replies.isEmpty) {
                      return const Center(child: Text('Be the first to reply!'));
                    }
                    
                    // Process the flat list into a nested structure
                    final rootReplies = _processReplies(replies);

                    return ListView(
                      children: [
                        // Build the recursive widget tree
                        ..._buildNestedReplies(rootReplies, finalAnswerId),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Reply Input Area
          _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    // Determine the hint text based on who the user is replying to
    String hintText = _replyingToName != null 
        ? 'Replying to ${_replyingToName}...' 
        : 'Add a reply to the main post...';
        
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A314D) : Colors.grey.shade200,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: primaryColor,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () => _postReply(parentId: _replyingToId),
                ),
              ),
            ],
          ),
          // Option to cancel the reply if replying to a specific comment
          if (_replyingToId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _replyingToId = null;
                    _replyingToName = null;
                  });
                },
                child: const Text('Cancel Reply'),
              ),
            ),
        ],
      ),
    );
  }
}


// ===============================================
// New Widget for the Reply Card (Upvote and Final Answer Logic)
// ===============================================

class ReplyCard extends StatefulWidget {
  final String replyDocId;
  final String pollId;
  final Map<String, dynamic> reply;
  final String? finalAnswerId;
  final bool isOriginalPoster;
  final Function(String) onMarkFinal;
  final Function(String replyId, String postedBy) onReply; // <-- NEW: For nested replies

  const ReplyCard({
    super.key,
    required this.replyDocId,
    required this.pollId,
    required this.reply,
    required this.finalAnswerId,
    required this.isOriginalPoster,
    required this.onMarkFinal,
    required this.onReply, // <-- NEW
  });

  @override
  State<ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends State<ReplyCard> {
  final _currentUser = FirebaseAuth.instance.currentUser!;

  // UPVOTE LOGIC (Updated for Restriction)
  Future<void> _toggleUpvote() async {
    final replyRef = FirebaseFirestore.instance
        .collection('doubt_polls')
        .doc(widget.pollId)
        .collection('replies')
        .doc(widget.replyDocId);

    // --- FIX: RESTRICTION CHECK (OP of comment cannot upvote) ---
    if (_currentUser.uid == widget.reply['postedById']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot upvote your own comment.'), backgroundColor: Colors.orange),
      );
      return;
    }
    // --- END RESTRICTION CHECK ---

    final upvotes = List<String>.from(widget.reply['upvotes'] ?? []);
    final isUpvoted = upvotes.contains(_currentUser.uid);

    try {
      if (isUpvoted) {
        // Remove upvote
        await replyRef.update({
          'upvotes': FieldValue.arrayRemove([_currentUser.uid]),
        });
      } else {
        // Add upvote
        await replyRef.update({
          'upvotes': FieldValue.arrayUnion([_currentUser.uid]),
        });
      }
    } catch (e) {
      debugPrint('Error toggling upvote: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upvote failed, check your permissions: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final upvotes = List<String>.from(widget.reply['upvotes'] ?? []);
    final isUpvoted = upvotes.contains(_currentUser.uid);
    final isFinalAnswer = widget.replyDocId == widget.finalAnswerId;
    final isAuthor = widget.reply['postedById'] == _currentUser.uid;
    
    // Check if the current user is the author of this specific reply
    final bool isReplyAuthor = widget.reply['postedById'] == _currentUser.uid;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4), // Margin removed here, handled by Padding in parent
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFinalAnswer ? Colors.green.withOpacity(0.1) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A314D) : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isFinalAnswer ? Colors.green : Colors.grey.shade300),
        boxShadow: isFinalAnswer ? [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 4)] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    widget.reply['postedBy'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isFinalAnswer ? Colors.green.shade700 : primaryColor,
                    ),
                  ),
                  // Final Answer Badge
                  if (isFinalAnswer)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.check_circle, color: Colors.green, size: 18),
                    ),
                  if (isReplyAuthor)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text('(You)', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
              Text(
                (widget.reply['timestamp'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reply Text Content
          Text(
            widget.reply['text'] ?? '',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Upvote Button (Restricted to Author)
              GestureDetector(
                onTap: _toggleUpvote,
                child: Row(
                  children: [
                    Icon(
                      isUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                      color: isUpvoted ? primaryColor : (isReplyAuthor ? Colors.grey.shade300: Colors.grey),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${upvotes.length}',
                      style: TextStyle(
                        color: isUpvoted ? primaryColor : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16.0),

              // Reply Button (For Nested Replies)
              TextButton.icon(
                onPressed: () => widget.onReply(widget.replyDocId, widget.reply['postedBy'] as String? ?? 'Unknown'),
                icon: const Icon(Icons.reply, size: 18),
                label: const Text('Reply'),
              ),
              
              // Mark as Final Button (Visible only to the Original Poll Poster, and only if not already marked)
              if (widget.isOriginalPoster && !isFinalAnswer)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: TextButton.icon(
                    onPressed: () => widget.onMarkFinal(widget.replyDocId),
                    icon: const Icon(Icons.done, color: Colors.green),
                    label: const Text('Mark as Final', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}