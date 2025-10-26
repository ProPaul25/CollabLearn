// lib/create_assignment_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // REQUIRED: This import must be present to use DateFormat

class CreateAssignmentPage extends StatefulWidget {
  final String classId;

  const CreateAssignmentPage({
    super.key,
    required this.classId,
  });

  @override
  State<CreateAssignmentPage> createState() => _CreateAssignmentPageState();
}

class _CreateAssignmentPageState extends State<CreateAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController();

  DateTime? _selectedDueDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  // Fetches the current user's name (instructor)
  Future<String> _getCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      // Assuming 'firstName' and 'lastName' are used for the full name
      final data = userDoc.data();
      final String firstName = data?['firstName'] ?? '';
      final String lastName = data?['lastName'] ?? '';
      final String name = "$firstName $lastName".trim();
      return name.isEmpty ? (user.email ?? 'Instructor') : name;
    }
    return 'Instructor';
  }

  // Handles the due date and time picker
  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDueDate ?? pickedDate),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  // Handles assignment posting to Firestore
  Future<void> _postAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userName = await _getCurrentUserName();
      final points = int.tryParse(_pointsController.text.trim()) ?? 0;

      await FirebaseFirestore.instance.collection('assignments').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'courseId': widget.classId,
        'points': points,
        'dueDate': Timestamp.fromDate(_selectedDueDate!),
        'postedBy': userName,
        'postedById': FirebaseAuth.instance.currentUser!.uid,
        'postedOn': Timestamp.now(),
        'type': 'assignment', // Used for filtering/display in Classworks tab
      });

      if (mounted) {
        Navigator.pop(context); // Close the page on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create assignment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    // DateFormat must be imported to be used here.
    final formattedDueDate = _selectedDueDate == null
        ? 'No Due Date Selected'
        : DateFormat('MMM dd, yyyy HH:mm').format(_selectedDueDate!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Assignment'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Assignment Title',
                  prefixIcon: Icon(Icons.assignment),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
                validator: (value) => value!.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 20),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Instructions/Description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
                validator: (value) => value!.isEmpty ? 'Instructions are required' : null,
              ),
              const SizedBox(height: 20),

              // Points and Due Date Row
              Row(
                children: [
                  // Points Field
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _pointsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Points',
                        prefixIcon: Icon(Icons.score),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) return 'Points needed';
                        if (int.tryParse(value) == null || (int.tryParse(value) ?? 0) <= 0) return 'Must be positive number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 15),

                  // Due Date Picker
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _isLoading ? null : () => _selectDueDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Due Date',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        ),
                        child: Text(
                          formattedDueDate,
                          style: TextStyle(color: _selectedDueDate == null ? Colors.grey : primaryColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Attachment Note
              const Text(
                'Note: Any necessary files (e.g., starter code, templates) should be uploaded separately in the Classworks tab as Study Materials.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 30),


              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _postAssignment,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.publish),
                  label: Text(_isLoading ? 'Publishing...' : 'Publish Assignment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
