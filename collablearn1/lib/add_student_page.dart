// lib/add_student_page.dart - FIXED FOR USER ENROLLMENT

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddStudentPage extends StatefulWidget {
  final String classId;

  const AddStudentPage({super.key, required this.classId});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _emailController = TextEditingController();
  String? _searchResultId;
  String? _searchResultName;
  bool _isLoading = false;
  bool _isAdding = false;
  
  List<String> _currentStudentIds = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentStudents();
  }

  Future<void> _loadCurrentStudents() async {
    final classDoc = await FirebaseFirestore.instance.collection('classes').doc(widget.classId).get();
    if (classDoc.exists) {
      setState(() {
        _currentStudentIds = List<String>.from(classDoc.data()?['studentIds'] ?? []).where((id) => id.isNotEmpty).toList();
      });
    }
  }

  Future<void> _searchUserByEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResultId = null;
      _searchResultName = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first;
        final userData = userDoc.data();
        final userId = userDoc.id;
        
        // Validation: Check if the user is already a student
        if (_currentStudentIds.contains(userId)) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('This user is already a student in this course.'), backgroundColor: Colors.orange)
            );
            return;
        }

        setState(() {
          _searchResultId = userId;
          _searchResultName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
          if (_searchResultName!.isEmpty) _searchResultName = userDoc.id;
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

  Future<void> _addStudent() async {
    if (_searchResultId == null || _isAdding) return;

    setState(() {
      _isAdding = true;
    });

    try {
      // 1. Add student to the class document's studentIds array
      await FirebaseFirestore.instance.collection('classes').doc(widget.classId).update({
        'studentIds': FieldValue.arrayUnion([_searchResultId]),
      });
      
      // 2. (Optional but Recommended): Update the user's profile to reflect course enrollment
      // FIX: Uncommented and used arrayUnion for enrolledClasses
      await FirebaseFirestore.instance.collection('users').doc(_searchResultId).update({
        'enrolledClasses': FieldValue.arrayUnion([widget.classId]),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_searchResultName} added as student!'), backgroundColor: Colors.green)
        );
        // Pop back to PeopleViewPage
        Navigator.pop(context); 
      }
    } catch (e) {
      debugPrint('Add student error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add student: $e'), backgroundColor: Colors.red)
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
    // ... (rest of the build method remains the same)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Student'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the email of the student you want to add to the course.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Student Email',
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
              onPressed: _emailController.text.trim().isEmpty || _isLoading ? null : _searchUserByEmail,
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
                          onPressed: _addStudent,
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