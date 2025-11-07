// lib/add_co_instructor_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCoInstructorPage extends StatefulWidget {
  final String classId;

  const AddCoInstructorPage({super.key, required this.classId});

  @override
  State<AddCoInstructorPage> createState() => _AddCoInstructorPageState();
}

class _AddCoInstructorPageState extends State<AddCoInstructorPage> {
  final _emailController = TextEditingController();
  String? _searchResultId;
  String? _searchResultName;
  bool _isLoading = false;
  bool _isAdding = false;
  
  List<String> _currentInstructorIds = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentInstructors();
  }

  Future<void> _loadCurrentInstructors() async {
    final classDoc = await FirebaseFirestore.instance.collection('classes').doc(widget.classId).get();
    if (classDoc.exists) {
      final data = classDoc.data();
      setState(() {
        // Handle both old single field and new array field
        _currentInstructorIds = List<String>.from(data?['instructorIds'] ?? [data?['instructorId']]).where((id) => id.isNotEmpty).toList();
      });
    }
  }

  Future<void> _searchUserByEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    
    // Clear previous results and show loading
    setState(() {
      _isLoading = true;
      _searchResultId = null;
      _searchResultName = null;
    });

    try {
      // 1. Search the 'users' collection for the email.
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first;
        final userData = userDoc.data();
        final userId = userDoc.id;
        
        // 2. Validation: Check if the user is already an instructor
        if (_currentInstructorIds.contains(userId)) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('This user is already an instructor for this course.'), backgroundColor: Colors.orange)
            );
            return;
        }

        setState(() {
          _searchResultId = userId;
          _searchResultName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
          // FIX: Use the user's email as a fallback for the display name
          if (_searchResultName!.isEmpty) _searchResultName = userData['email'] ?? userDoc.id;
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found or email incorrect.'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addInstructor() async {
    if (_searchResultId == null || _isAdding) return;

    setState(() {
      _isAdding = true;
    });

    try {
      // Use arrayUnion to safely add the UID to the list of instructors
      await FirebaseFirestore.instance.collection('classes').doc(widget.classId).update({
        'instructorIds': FieldValue.arrayUnion([_searchResultId]),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_searchResultName} added as co-instructor!'), backgroundColor: Colors.green)
        );
        // Refresh the PeopleViewPage
        Navigator.pop(context); 
      }
    } catch (e) {
      debugPrint('Add instructor error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add instructor: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Co-Instructor'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the email of the user you want to add as a co-instructor.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Instructor Email',
                border: const OutlineInputBorder(),
                suffixIcon: _isLoading 
                    ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchUserByEmail,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _searchUserByEmail,
              child: const Text('Search User'),
            ),
            
            const SizedBox(height: 30),

            // --- Search Result Card ---
            if (_searchResultId != null && _searchResultName != null)
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.green),
                  title: Text(_searchResultName!),
                  subtitle: Text(_emailController.text.trim()),
                  trailing: _isAdding 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : ElevatedButton(
                          onPressed: _addInstructor,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Add', style: TextStyle(color: Colors.white)),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}