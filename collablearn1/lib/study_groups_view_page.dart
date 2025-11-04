// lib/study_groups_view_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'study_group_chat_page.dart';

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
  
  // New state for class roster
  List<Map<String, dynamic>> _classRoster = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();
    _loadClassRoster(); // Load roster for group creation
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

  // --- NEW: Load Class Roster ---
  Future<void> _loadClassRoster() async {
    try {
      final classDoc = await FirebaseFirestore.instance.collection('classes').doc(widget.classId).get();
      final studentIds = List<String>.from(classDoc.data()?['studentIds'] ?? []);
      final instructorId = classDoc.data()?['instructorId'] as String?;
      
      final allUids = {...studentIds};
      if (instructorId != null) {
        allUids.add(instructorId);
      }

      if (allUids.isEmpty) return;

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: allUids.toList())
          .get();

      final roster = usersSnapshot.docs.map((doc) {
        final data = doc.data();
        final name = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
        return {
          'uid': doc.id,
          'name': name.isEmpty ? (data['email'] ?? 'User') : name,
          'isInstructor': doc.id == instructorId,
        };
      }).where((u) => u['uid'] != user.uid).toList(); // Exclude current user from the invite list

      if (mounted) {
        setState(() {
          _classRoster = roster;
        });
      }
    } catch (e) {
      debugPrint('Error loading class roster: $e');
    }
  }
  
  // --- Group Creation Dialog ---
  Future<void> _showCreateGroupDialog() async {
    final _nameController = TextEditingController();
    final _descriptionController = TextEditingController();
    final _formKey = GlobalKey<FormState>();
    
    // State for selected users
    List<String> _selectedUids = []; 

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
                  const SizedBox(height: 20),
                  // --- NEW: Invitee Selection ---
                  const Text('Invite Class Members (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_classRoster.isEmpty)
                    const Text('No other members in the class to invite.')
                  else
                    ..._classRoster.map((member) {
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          final isSelected = _selectedUids.contains(member['uid']);
                          return CheckboxListTile(
                            title: Text(member['name']),
                            subtitle: Text(member['isInstructor'] ? 'Instructor' : 'Student'),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedUids.add(member['uid']);
                                } else {
                                  _selectedUids.remove(member['uid']);
                                }
                              });
                            },
                          );
                        },
                      );
                    }).toList(),
                  // --- END NEW: Invitee Selection ---
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
                  _createGroup(
                    _nameController.text.trim(), 
                    _descriptionController.text.trim(),
                    _selectedUids, // Pass the selected UIDs
                  );
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

  // --- Group Creation Logic (UPDATED) ---
  Future<void> _createGroup(String name, String description, List<String> inviteeUids) async {
    try {
      // The creator is a member and will be added to the inviteeUids list as well for simplicity
      final allInviteeUids = {...inviteeUids, user.uid}.toList();

      await FirebaseFirestore.instance.collection('study_groups').add({
        'groupName': name,
        'description': description,
        'classId': widget.classId,
        'createdBy': user.uid,
        'creatorName': _currentUserName,
        'memberUids': [user.uid], // Creator is the first member
        'inviteeUids': allInviteeUids, // NEW: List of all invited/allowed UIDs
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

 // --- Group List Stream (UPDATED for private groups) ---
  Stream<QuerySnapshot> _getStudyGroupsStream() {
    return FirebaseFirestore.instance
        .collection('study_groups')
        .where('classId', isEqualTo: widget.classId)
        // NEW LOGIC: Only fetch groups where the current user is a member OR an invitee
        .where('inviteeUids', arrayContains: user.uid) 
        
        // --- ADD THESE TWO LINES TO MATCH THE COMPOSITE INDEX ORDER ---
        .orderBy('classId') 
        .orderBy('inviteeUids')
        // -----------------------------------------------------------
        
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // --- Group Joining Logic (UNCHANGED logic, but used by the new 'Accept Invite' action) ---
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

  // --- NEW: Group Rejection Logic (Remove from inviteeUids) ---
  Future<void> _rejectGroup(String groupId) async {
    try {
      await FirebaseFirestore.instance.collection('study_groups').doc(groupId).update({
        'inviteeUids': FieldValue.arrayRemove([user.uid]), // Remove the user from the allowed list
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group invitation rejected.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject invitation: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
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
          // Filter groups to only show if the user is a member or an invitee (already done in stream but kept for safety/future check)
          // final visibleGroups = groups.where((doc) {
          //   final data = doc.data() as Map<String, dynamic>;
          //   final memberUids = data['memberUids'] as List<dynamic>? ?? [];
          //   final inviteeUids = data['inviteeUids'] as List<dynamic>? ?? [];
          //   return memberUids.contains(user.uid) || inviteeUids.contains(user.uid);
          // }).toList();
          final visibleGroups = groups;


          if (visibleGroups.isEmpty) {
            return const Center(
              child: Text(
                'No study groups visible to you. Be the first to create one!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visibleGroups.length,
            itemBuilder: (context, index) {
              final groupDoc = visibleGroups[index];
              final data = groupDoc.data() as Map<String, dynamic>;
              final groupId = groupDoc.id;
              final groupName = data['groupName'] ?? 'Unnamed Group';
              final memberUids = data['memberUids'] as List<dynamic>? ?? [];
              
              final isMember = memberUids.contains(user.uid);
              
              // NEW: Check if the user is an invitee but NOT a member
              final inviteeUids = data['inviteeUids'] as List<dynamic>? ?? [];
              final isInvitedButNotMember = inviteeUids.contains(user.uid) && !isMember;


              Widget trailingWidget;
              VoidCallback? onTapAction;

              if (isMember) {
                // User is a member -> show chat icon and navigate to chat
                trailingWidget = const Icon(Icons.chat_bubble_outline, color: Colors.green);
                onTapAction = () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => StudyGroupChatPage(
                        groupId: groupId,
                        groupName: groupName,
                        currentUserName: _currentUserName,
                      ),
                    ),
                  );
                };
              } else if (isInvitedButNotMember) {
                // User is invited but not a member -> show join/reject buttons
                trailingWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => _joinGroup(groupId, memberUids),
                      child: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _rejectGroup(groupId),
                      child: const Text('Reject', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                );
                onTapAction = null; // No direct tap action until accepted
              } else {
                 // Should technically not happen if the stream is correct, but handles any "public" or uninvited/non-member view
                 trailingWidget = const Text('Invite Only', style: TextStyle(color: Colors.grey));
                 onTapAction = null;
              }


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
                  trailing: trailingWidget,
                  onTap: onTapAction,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _classRoster.isEmpty ? null : _showCreateGroupDialog,
        label: const Text('Create Group'),
        icon: const Icon(Icons.add_circle),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}