// lib/doubt_poll_detail_page.dart - CORRECTED

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ... (ReplyData class is unchanged)
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

  const DoubtPollDetailPage({
    super.key,
    required this.pollId,
    required this.classId,
    required this.initialPollData,
  });

  @override
  State<DoubtPollDetailPage> createState() => _DoubtPollDetailPageState();
}

class _DoubtPollDetailPageState extends State<DoubtPollDetailPage> {
  final _replyController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  
  late String _currentUserName = 'Anonymous';
  String _instructorId = '';
  bool _isTeacher = false;
  bool _isOriginalPoster = false;
  String? _replyingToId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
    if (_currentUser != null) {
      _isOriginalPoster = widget.initialPollData['postedById'] == _currentUser!.uid;
    }
  }

  Future<void> _loadCurrentUserData() async {
    // ... (This function is unchanged)
    if (_currentUser == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      final classDoc = await FirebaseFirestore.instance.collection('classes').doc(widget.classId).get();
      
      if (mounted) {
        setState(() {
          if (userDoc.exists) {
            final data = userDoc.data();
            final String firstName = data?['firstName'] ?? '';
            final String lastName = data?['lastName'] ?? '';
            _currentUserName = "$firstName $lastName".trim();
            _currentUserName = _currentUserName.isEmpty ? 'Anonymous' : _currentUserName;
          }
          if (classDoc.exists) {
            _instructorId = classDoc.data()?['instructorId'] ?? '';
            _isTeacher = _currentUser!.uid == _instructorId;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _toggleFinalAnswer(String replyId, bool isCurrentlyFinal) async {
    // ... (This function is unchanged)
    if (!_isTeacher) return;
    try {
      final pollRef = FirebaseFirestore.instance.collection('doubt_polls').doc(widget.pollId);
      if (isCurrentlyFinal) {
        await pollRef.update({'finalAnswerIds': FieldValue.arrayRemove([replyId])});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Answer unmarked as final.'), backgroundColor: Colors.orange),
          );
        }
      } else {
        await pollRef.update({'finalAnswerIds': FieldValue.arrayUnion([replyId])});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Final answer marked!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling final answer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark final answer: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- FIX: This function now "bumps" the post in the class_feed ---
  Future<void> _postReply({String? parentId}) async {
    if (_replyController.text.trim().isEmpty || _currentUser == null) return;

    final replyText = _replyController.text.trim();
    final newTimestamp = FieldValue.serverTimestamp(); // Use the same timestamp for all updates
    _replyController.clear();
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // 1. Add the new reply to the subcollection
      final pollRef = FirebaseFirestore.instance.collection('doubt_polls').doc(widget.pollId);
      final repliesRef = pollRef.collection('replies').doc();
      batch.set(repliesRef, {
        'pollId': widget.pollId,
        'text': replyText,
        'postedById': _currentUser!.uid,
        'postedBy': _currentUserName,
        'timestamp': newTimestamp,
        'upvotes': [], 
        'parentId': parentId,
      });

      // 2. Increment the answersCount on the main poll document
      batch.update(pollRef, {
        'answersCount': FieldValue.increment(1),
      });

      // 3. Find the matching feed item and UPDATE its timestamp to "bump" it
      final feedQuery = await FirebaseFirestore.instance
          .collection('class_feed')
          .where('pollId', isEqualTo: widget.pollId)
          .limit(1)
          .get();
          
      if (feedQuery.docs.isNotEmpty) {
        final feedDocRef = feedQuery.docs.first.reference;
        batch.update(feedDocRef, {
          'lastActivityTimestamp': newTimestamp,
          'answersCount': FieldValue.increment(1), // Also update count on feed item
        });
      }

      // 4. Commit all 3 operations
      await batch.commit();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      debugPrint('Error posting reply: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting reply: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ... (_processReplies and _buildNestedReplies functions are unchanged)
  List<ReplyData> _processReplies(List<DocumentSnapshot> docs) {
    final Map<String, ReplyData> allReplies = {};
    for (var doc in docs) {
      allReplies[doc.id] = ReplyData(doc.id, doc.data() as Map<String, dynamic>);
    }
    final List<ReplyData> rootReplies = [];
    allReplies.forEach((id, reply) {
      if (reply.parentId.isEmpty) {
        rootReplies.add(reply);
      } else {
        final parent = allReplies[reply.parentId];
        parent?.children.add(reply);
      }
    });
    return rootReplies;
  }
  
  List<Widget> _buildNestedReplies(List<ReplyData> replies, List<String> finalAnswerIds, {double depth = 0}) {
    List<Widget> list = [];
    replies.sort((a, b) {
      bool aIsTeacher = a.data['postedById'] == _instructorId;
      bool bIsTeacher = b.data['postedById'] == _instructorId;
      if (aIsTeacher && !bIsTeacher) return -1;
      if (bIsTeacher && !aIsTeacher) return 1;
      bool aIsFinal = finalAnswerIds.contains(a.id);
      bool bIsFinal = finalAnswerIds.contains(b.id);
      if (aIsFinal && !bIsFinal) return -1;
      if (bIsFinal && !aIsFinal) return 1;
      final aTimestamp = a.data['timestamp'] as Timestamp? ?? Timestamp.now();
      final bTimestamp = b.data['timestamp'] as Timestamp? ?? Timestamp.now();
      return aTimestamp.compareTo(bTimestamp);
    });
    for (var reply in replies) {
      list.add(Padding(
        padding: EdgeInsets.only(left: depth > 0 ? 20.0 : 0.0),
        child: Column(
          children: [
            ReplyCard(
              replyDocId: reply.id,
              pollId: widget.pollId,
              reply: reply.data,
              finalAnswerIds: finalAnswerIds,
              isTeacher: _isTeacher,
              onToggleFinal: _toggleFinalAnswer,
              onReply: (replyId, postedBy) {
                setState(() {
                  _replyingToId = replyId;
                  _replyingToName = postedBy;
                });
              },
            ),
            ..._buildNestedReplies(reply.children, finalAnswerIds, depth: depth + 1),
          ],
        ),
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    // ... (UI build method is unchanged)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion Thread'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
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
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('doubt_polls').doc(widget.pollId).snapshots(),
              builder: (context, pollSnapshot) {
                if (!pollSnapshot.hasData || !pollSnapshot.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pollData = pollSnapshot.data!.data() as Map<String, dynamic>;
                final finalAnswerIds = List<String>.from(pollData['finalAnswerIds'] ?? []);

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('doubt_polls')
                      .doc(widget.pollId)
                      .collection('replies')
                      .orderBy('timestamp', descending: false)
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
                    final rootReplies = _processReplies(replies);
                    return ListView(
                      children: [
                        ..._buildNestedReplies(rootReplies, finalAnswerIds),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    // ... (This widget is unchanged)
    final primaryColor = Theme.of(context).colorScheme.primary;
    if (_isOriginalPoster && _replyingToId == null) {
      return const SizedBox.shrink();
    }
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
// Reply Card Widget
// ===============================================

class ReplyCard extends StatefulWidget {
  // ... (This class is unchanged)
  final String replyDocId;
  final String pollId;
  final Map<String, dynamic> reply;
  final List<String> finalAnswerIds;
  final bool isTeacher;
  final Function(String, bool) onToggleFinal;
  final Function(String replyId, String postedBy) onReply;

  const ReplyCard({
    super.key,
    required this.replyDocId,
    required this.pollId,
    required this.reply,
    required this.finalAnswerIds,
    required this.isTeacher,
    required this.onToggleFinal,
    required this.onReply,
  });

  @override
  State<ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends State<ReplyCard> {
  final _currentUser = FirebaseAuth.instance.currentUser!;

  Future<void> _toggleUpvote() async {
    // ... (This function is unchanged)
    final replyRef = FirebaseFirestore.instance
        .collection('doubt_polls')
        .doc(widget.pollId)
        .collection('replies')
        .doc(widget.replyDocId);
    if (_currentUser.uid == widget.reply['postedById']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot upvote your own comment.'), backgroundColor: Colors.orange),
      );
      return;
    }
    final upvotes = List<String>.from(widget.reply['upvotes'] ?? []);
    final isUpvoted = upvotes.contains(_currentUser.uid);
    try {
      if (isUpvoted) {
        await replyRef.update({'upvotes': FieldValue.arrayRemove([_currentUser.uid])});
      } else {
        await replyRef.update({'upvotes': FieldValue.arrayUnion([_currentUser.uid])});
      }
    } catch (e) {
      debugPrint('Error toggling upvote: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (This build method is unchanged)
    final primaryColor = Theme.of(context).colorScheme.primary;
    final upvotes = List<String>.from(widget.reply['upvotes'] ?? []);
    final isUpvoted = upvotes.contains(_currentUser.uid);
    final isFinalAnswer = widget.finalAnswerIds.contains(widget.replyDocId);
    final isReplyAuthor = widget.reply['postedById'] == _currentUser.uid;
    final isTeacherReply = widget.reply['postedById'] == (context.findAncestorStateOfType<_DoubtPollDetailPageState>()?._instructorId ?? '');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
                  if (isTeacherReply)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Chip(
                        label: const Text('Instructor'),
                        backgroundColor: primaryColor.withOpacity(0.1),
                        labelStyle: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                        padding: EdgeInsets.zero,
                        side: BorderSide.none,
                      ),
                    ),
                  if (isFinalAnswer && !isTeacherReply)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.check_circle, color: Colors.green, size: 18),
                    ),
                  if (isReplyAuthor && !isTeacherReply)
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
          Text(
            widget.reply['text'] ?? '',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
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
              TextButton.icon(
                onPressed: () => widget.onReply(widget.replyDocId, widget.reply['postedBy'] as String? ?? 'Unknown'),
                icon: const Icon(Icons.reply, size: 18),
                label: const Text('Reply'),
              ),
              const Spacer(),
              if (widget.isTeacher)
                TextButton.icon(
                  onPressed: () => widget.onToggleFinal(widget.replyDocId, isFinalAnswer),
                  icon: Icon(isFinalAnswer ? Icons.clear : Icons.done, color: isFinalAnswer ? Colors.red : Colors.green),
                  label: Text(
                    isFinalAnswer ? 'Unmark' : 'Mark as Final', 
                    style: TextStyle(color: isFinalAnswer ? Colors.red : Colors.green, fontWeight: FontWeight.bold)
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}