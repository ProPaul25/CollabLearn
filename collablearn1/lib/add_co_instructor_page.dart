// lib/add_co_instructor_page.dart - FINAL FIX: Forcing Fresh Data on Search and fixing button state

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
  
  String? _currentStudentClassId; 

  @override
  void initState() {
    super.initState();
    // FIX: Add listener to email controller to trigger rebuilds for button state
    _emailController.addListener(_onEmailChanged);
  }
  
  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    super.dispose();
  }
  
  void _onEmailChanged() {
    if (mounted) {
      setState(() {});
    }
  }
  
  // Helper to get ALL current instructor UIDs AND the class document
  Future<Map<String, dynamic>> _getFreshClassData() async {
      // FIX: Ensure we explicitly request data from the server for validation
      final classDoc = await FirebaseFirestore.instance.collection('classes').doc(widget.classId).get(const GetOptions(source: Source.server));
      if (!classDoc.exists) return {'instructorIds': [], 'studentIds': []};

      final classData = classDoc.data();
      List<String> instructorIds = List<String>.from(classData?['instructorIds'] ?? []).where((id) => id.isNotEmpty).toList();
      
      // Include primary instructor for validation if using the legacy field
      final primaryId = classData?['instructorId'] as String?;
      if (primaryId != null && primaryId.isNotEmpty && !instructorIds.contains(primaryId)) {
        instructorIds.add(primaryId);
      }
      
      return {
        'classData': classData,
        'instructorIds': instructorIds,
        'studentIds': List<String>.from(classData?['studentIds'] ?? []),
      };
  }

  Future<void> _searchUserByEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _searchResultId = null;
      _searchResultName = null;
      _currentStudentClassId = null; 
    });

    try {
      // FORCE A FRESH READ OF CLASS DATA FROM SERVER
      final freshClassInfo = await _getFreshClassData();
      final currentInstructorIds = freshClassInfo['instructorIds'] as List<String>;
      final currentStudentIds = freshClassInfo['studentIds'] as List<String>;


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
        
        // 2. Validation: Check if the user is already an instructor (using the fresh list)
        if (currentInstructorIds.contains(userId)) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                // FIX: This message now correctly relies on server data
                const SnackBar(content: Text('This user is already an instructor for this course.'), backgroundColor: Colors.orange)
            );
            return;
        }

        // 3. Check if the user is currently a student in this class
        if (currentStudentIds.contains(userId)) {
          _currentStudentClassId = userId; // User is a student, mark for promotion logic
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: ${e.toString()}'), backgroundColor: Colors.red)
      );
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
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(_searchResultId);
      final classRef = FirebaseFirestore.instance.collection('classes').doc(widget.classId);

      // --- 1. Update the Class Document ---
      // Add user to instructorIds array
      batch.update(classRef, {
        'instructorIds': FieldValue.arrayUnion([_searchResultId]),
      });

      // If the user was a student, remove them from studentIds
      if (_currentStudentClassId != null) {
          batch.update(classRef, {
            'studentIds': FieldValue.arrayRemove([_searchResultId]),
          });
      }

      // --- 2. Update the User Document ---
      // Add the class to their instructedClasses array
      batch.update(userRef, {
        'instructedClasses': FieldValue.arrayUnion([widget.classId]),
      });
      
      // If the user was a student, remove the class from their enrolledClasses array
      if (_currentStudentClassId != null) {
        batch.update(userRef, {
          'enrolledClasses': FieldValue.arrayRemove([widget.classId]),
        });
      }
      
      // Commit the transaction
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_searchResultName} added as co-instructor!'), backgroundColor: Colors.green)
        );
        // Pop back to PeopleViewPage (passing true signals success and triggers refresh)
        Navigator.pop(context, true); 
      }
    } catch (e) {
      debugPrint('Add instructor error: $e');
      if (mounted) {
        // Since the security rules are complex, a blanket permission-denied check is safer.
        String message = 'Failed to add instructor: $e';
        if (e is FirebaseException && e.code == 'permission-denied') {
          // This happens when the user update rule fails
          message = 'Failed to add instructor: Check Firebase Security Rules for user update permissions (users collection).';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red)
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
    // Determine the text based on current status
    String buttonText = 'Add';
    String statusText = 'Add as Co-Instructor';
    if (_searchResultId != null && _currentStudentClassId != null) {
        buttonText = 'Promote';
        statusText = 'Promote from Student to Co-Instructor';
    }

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
                        onPressed: _emailController.text.trim().isNotEmpty && !_isLoading ? _searchUserByEmail : null, // FIX APPLIED HERE
                      ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              // FIX APPLIED HERE
              onPressed: _emailController.text.trim().isNotEmpty && !_isLoading ? _searchUserByEmail : null,
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
                  subtitle: Text(statusText), // Show status if promoting
                  trailing: _isAdding 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : ElevatedButton(
                          onPressed: _addInstructor,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: Text(buttonText, style: const TextStyle(color: Colors.white)),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}