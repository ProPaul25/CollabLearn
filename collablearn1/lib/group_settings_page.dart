// lib/group_settings_page.dart - FIX FOR DISABLED 'Add Selected' BUTTON

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupSettingsPage extends StatefulWidget {
  final String groupId;
  final String classId;
  final String initialGroupName;

  const GroupSettingsPage({
    super.key,
    required this.groupId,
    required this.classId,
    required this.initialGroupName,
  });

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  final _groupNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _currentUser = FirebaseAuth.instance.currentUser!;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _groupNameController.text = widget.initialGroupName;
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
  
  // --- ADMIN FUNCTIONS ---

  Future<void> _updateGroupName() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final newName = _groupNameController.text.trim();

    try {
      await FirebaseFirestore.instance.collection('study_groups').doc(widget.groupId).update({
        'groupName': newName,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group name updated successfully!'), backgroundColor: Colors.green),
        );
        // Pop back to chat page with new name (optional, but good UX)
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await _showConfirmDialog(
      'Delete Group', 
      'Are you sure you want to permanently delete this study group? This cannot be undone.'
    );
    if (!confirmed) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('study_groups').doc(widget.groupId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted successfully!'), backgroundColor: Colors.green),
        );
        // Pop twice: once from settings, once from chat, back to group list
        Navigator.pop(context); 
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete group: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  // --- MEMBER MANAGEMENT HELPERS ---

  // Fetches full roster (excluding self and current members)
  Future<List<Map<String, dynamic>>> _getAvailableRoster(List<String> currentMembers) async {
    final classDoc = await FirebaseFirestore.instance.collection('classes').doc(widget.classId).get();
    
    // --- Defensive null check on classDoc.data() and fallback to empty list ---
    final classData = classDoc.data();
    final studentIds = List<String>.from(classData?['studentIds'] ?? []);
    final instructorId = classData?['instructorId'] as String?;
    
    // Combine all UIDs from the class
    final allUids = {
      ...studentIds, 
      if (instructorId != null) instructorId
    }.toList();

    // Filter out the current user and existing group members
    final uidsToFetch = allUids
        .where((uid) => uid != _currentUser.uid && !currentMembers.contains(uid))
        .toList();

    if (uidsToFetch.isEmpty) return [];

    // Use batch fetching to circumvent the 10-item 'whereIn' limit
    return _fetchUsersDataInBatches(uidsToFetch, instructorId); // Pass instructorId
  }

  // Helper function to fetch user data in batches (max 10 per query)
  // FIX: Added instructorId to properly set 'isInstructor' for the CheckboxListTile
  Future<List<Map<String, dynamic>>> _fetchUsersDataInBatches(List<String> uids, String? instructorId) async {
    const batchSize = 10;
    final List<Map<String, dynamic>> allUsers = [];

    for (int i = 0; i < uids.length; i += batchSize) {
      final batchUids = uids.sublist(i, (i + batchSize > uids.length) ? uids.length : i + batchSize);
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batchUids)
          .get();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Check for empty/missing document data immediately
        if (data.isEmpty) continue; 
        
        final name = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
        
        // FIX for "type 'Null' is not a 'bool'" error
        // Ensure 'isInstructor' is explicitly set to a boolean
        final bool isInstructor = doc.id == instructorId; 
        
        allUsers.add({
          ...data, 
          'uid': doc.id, 
          'name': name.isEmpty ? (data['email'] ?? 'User') : name,
          'isInstructor': isInstructor, // Now guaranteed to be a bool
        });
      }
    }
    return allUsers;
  }
  
  // --- UI AND DIALOGS ---

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }
  
  void _showAddMemberDialog(List<String> currentMembers) async {
    // This future call now uses the robust batch method
    List<Map<String, dynamic>> roster = await _getAvailableRoster(currentMembers);
    
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        // --- selectedUids is defined here, managed by the StatefulBuilder ---
        List<String> selectedUids = []; 
        
        // FIX: Wrap the entire AlertDialog content/actions in a single StatefulBuilder
        // This ensures the button's `onPressed` logic is rebuilt when checkboxes change.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Members'),
              content: roster.isEmpty
                ? const Text('No other members available to add to this group.')
                : SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: roster.length,
                      itemBuilder: (context, index) {
                        final member = roster[index];
                        final memberUid = member['uid']; 
                        
                        if (memberUid == null) return const SizedBox.shrink();

                        final isSelected = selectedUids.contains(memberUid);
                        return CheckboxListTile(
                          title: Text(member['name']),
                          // Now safe because 'isInstructor' is guaranteed a bool in _fetchUsersDataInBatches
                          subtitle: Text(member['isInstructor'] == true ? 'Instructor' : 'Student'), 
                          value: isSelected,
                          onChanged: (bool? value) {
                            setDialogState(() { // <-- Use setDialogState to rebuild the AlertDialog
                              if (value == true) {
                                selectedUids.add(memberUid);
                              } else {
                                selectedUids.remove(memberUid);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                // FIX APPLIED HERE: onPressed now correctly re-evaluates `selectedUids.isEmpty`
                ElevatedButton(
                  onPressed: selectedUids.isEmpty ? null : () { 
                    _addMembers(selectedUids);
                    Navigator.pop(context);
                  },
                  child: const Text('Add Selected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary, 
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          }, // End of StatefulBuilder
        );
      },
    );
  }
  
  Future<void> _addMembers(List<String> uids) async {
    try {
      // Add UIDs to both memberUids (if not already member) and inviteeUids
      await FirebaseFirestore.instance.collection('study_groups').doc(widget.groupId).update({
        'memberUids': FieldValue.arrayUnion(uids),
        'inviteeUids': FieldValue.arrayUnion(uids),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Members added successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add members: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<void> _removeMember(String uid, String name) async {
    final confirmed = await _showConfirmDialog(
      'Remove Member', 
      'Are you sure you want to remove $name from the group?'
    );
    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance.collection('study_groups').doc(widget.groupId).update({
        'memberUids': FieldValue.arrayRemove([uid]),
        'inviteeUids': FieldValue.arrayRemove([uid]), 
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name removed from group.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        // This is where the permission error was showing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings (Admin)'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Rename Group Section ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Change Group Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _groupNameController,
                        decoration: const InputDecoration(
                          labelText: 'New Group Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value!.isEmpty ? 'Name cannot be empty' : null,
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _updateGroupName,
                          icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                          label: Text(_isSaving ? 'Saving...' : 'Save Name'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // --- 2. Member Management Section ---
            const Text('Manage Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),

            // StreamBuilder to keep member list updated
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('study_groups').doc(widget.groupId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data?.data();
                final memberUids = List<String>.from(data?['memberUids'] ?? []);
                final creatorId = data?['createdBy'] as String?;

                // Pass instructorId to FutureBuilder
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('classes').doc(widget.classId).get(),
                  builder: (context, classSnapshot) {
                    final classData = classSnapshot.data?.data();
                    final instructorId = classData?['instructorId'] as String?;

                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchUsersDataInBatches(memberUids, instructorId),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
                        }
                        final members = userSnapshot.data ?? [];
                        
                        // Separate the creator
                        final otherMembers = members.where((m) => m['uid'] != creatorId).toList();
                        final creator = members.firstWhere((m) => m['uid'] == creatorId, orElse: () => {'name': 'Unknown Admin', 'uid': ''});


                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Add Member Button
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showAddMemberDialog(memberUids),
                                icon: const Icon(Icons.person_add),
                                label: const Text('Add Members'),
                              ),
                            ),
                            
                            // Admin/Creator
                            ListTile(
                              leading: const Icon(Icons.star, color: Colors.amber),
                              title: Text(creator['name'] ?? 'Admin'),
                              subtitle: const Text('Group Admin'),
                              trailing: const Text('(You)'),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),

                            // Other Members
                            ...otherMembers.map((member) {
                              return ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(member['name'] ?? 'Member'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => _removeMember(member['uid'] as String, member['name'] as String),
                                ),
                              );
                            }).toList(),

                            if (members.length <= 1)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('No other members yet.'),
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
            
            const SizedBox(height: 30),

            // --- 3. Delete Group Section ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.red, width: 1)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Danger Zone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 10),
                    const Text('Permanently delete this study group. All chat history will be lost.', style: TextStyle(color: Colors.red)),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _deleteGroup,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Delete Group'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}