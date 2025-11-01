// lib/study_groups_view_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'study_group_chat_page.dart'; // We'll create this next

class StudyGroupsViewPage extends StatefulWidget {
  final String classId;

  const StudyGroupsViewPage({
    super.key,
    required this.classId,
  });

  @override
  State<StudyGroupsViewPage> createState() => _StudyGroupsViewPageState();
}

class _StudyGroupsViewPageState extends State<StudyGroupsViewPage> {
  final user = FirebaseAuth.instance.currentUser!;
  String _currentUserName = 'User';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();
  }

  Future<void> _loadCurrentUserName() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      final String firstName = data?['firstName'] ?? '';
      final String lastName = data?['lastName'] ?? '';
      if (mounted) {
        setState(() {
          _currentUserName = "$firstName $lastName".trim().isEmpty ? (user.email ?? 'User') : "$firstName $lastName".trim();
        });
      }
    }
  }

  // --- Group Creation Dialog ---
  Future<void> _showCreateGroupDialog() async {
    final _nameController = TextEditingController();
    final _descriptionController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Study Group'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Group Name'),
                    validator: (value) => value!.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Purpose/Description'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _createGroup(_nameController.text.trim(), _descriptionController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // --- Group Creation Logic ---
  Future<void> _createGroup(String name, String description) async {
    try {
      await FirebaseFirestore.instance.collection('study_groups').add({
        'groupName': name,
        'description': description,
        'classId': widget.classId, // Link to the current class
        'createdBy': user.uid,
        'creatorName': _currentUserName,
        'memberUids': [user.uid], // Creator is the first member
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- Group List Stream ---
  Stream<QuerySnapshot> _getStudyGroupsStream() {
    return FirebaseFirestore.instance
        .collection('study_groups')
        .where('classId', isEqualTo: widget.classId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // --- Group Joining Logic ---
  Future<void> _joinGroup(String groupId, List<dynamic> memberUids) async {
    if (memberUids.contains(user.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already a member.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('study_groups').doc(groupId).update({
        'memberUids': FieldValue.arrayUnion([user.uid]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined group successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join group: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  @override
  Widget build(BuildContext) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _getStudyGroupsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final groups = snapshot.data?.docs ?? [];

          if (groups.isEmpty) {
            return const Center(
              child: Text(
                'No study groups yet. Be the first to create one!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final groupDoc = groups[index];
              final data = groupDoc.data() as Map<String, dynamic>;
              final groupId = groupDoc.id;
              final groupName = data['groupName'] ?? 'Unnamed Group';
              final memberUids = data['memberUids'] as List<dynamic>? ?? [];
              final isMember = memberUids.contains(user.uid);

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isMember ? Colors.green : primaryColor.withOpacity(0.1),
                    child: Icon(Icons.group, color: isMember ? Colors.white : primaryColor),
                  ),
                  title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Members: ${memberUids.length} • Created by: ${data['creatorName'] ?? 'N/A'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isMember
                      ? const Icon(Icons.chat_bubble_outline, color: Colors.green)
                      : ElevatedButton(
                          onPressed: () => _joinGroup(groupId, memberUids),
                          child: const Text('Join'),
                        ),
                  onTap: isMember
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => StudyGroupChatPage(
                                groupId: groupId,
                                groupName: groupName,
                                currentUserName: _currentUserName,
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroupDialog,
        label: const Text('Create Group'),
        icon: const Icon(Icons.add_circle),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}