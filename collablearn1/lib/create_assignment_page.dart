// lib/create_assignment_page.dart - CORRECTED

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart'; // <-- NEW IMPORT
import 'package:flutter/foundation.dart' show kIsWeb; // <-- NEW IMPORT
// <-- NEW IMPORT
import 'package:cloudinary_public/cloudinary_public.dart'; // <-- NEW IMPORT

// --- NEW: CLOUDINARY INSTANCE ---
const String _CLOUD_NAME = 'dc51dx2da'; 
const String _UPLOAD_PRESET = 'CollabLearn'; 

final CloudinaryPublic cloudinary = CloudinaryPublic(
  _CLOUD_NAME,
  _UPLOAD_PRESET,
  cache: false,
);
// ---------------------------------

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
  
  // --- NEW STATE FOR FILE UPLOAD ---
  PlatformFile? _pickedFile;
  double _uploadProgress = 0;
  // ---------------------------------

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<String> _getCurrentUserName() async {
    // ... (This function is unchanged)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      final String firstName = data?['firstName'] ?? '';
      final String lastName = data?['lastName'] ?? '';
      final String name = "$firstName $lastName".trim();
      return name.isEmpty ? (user.email ?? 'Instructor') : name;
    }
    return 'Instructor';
  }

  Future<void> _selectDueDate(BuildContext context) async {
    // ... (This function is unchanged)
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

  // --- NEW: FILE PICKER FUNCTION ---
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'pptx', 'docx', 'zip', 'jpg', 'png', 'doc', 'txt'],
    );
    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }
  // ---------------------------------

  // --- UPDATED: Handles assignment posting AND optional file upload ---
  Future<void> _postAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
       _isLoading = true;
       _uploadProgress = 0;
    });

    try {
      final userName = await _getCurrentUserName();
      final points = int.tryParse(_pointsController.text.trim()) ?? 0;
      
      String? downloadUrl;
      String? cloudinaryPublicId;
      String? fileName;

      // --- NEW: UPLOAD FILE IF ONE IS PICKED ---
      if (_pickedFile != null) {
        CloudinaryResourceType resourceType = CloudinaryResourceType.Raw;
        if (['jpg', 'png'].contains(_pickedFile!.extension)) {
            resourceType = CloudinaryResourceType.Image;
        }
        
        CloudinaryFile fileToUpload;
        if (kIsWeb) {
          if (_pickedFile!.bytes == null) throw Exception("File bytes missing for web upload.");
          fileToUpload = CloudinaryFile.fromByteData(
            _pickedFile!.bytes!.buffer.asByteData(), 
            resourceType: resourceType,
            folder: 'collablearn/assignments/${widget.classId}',
            identifier: _pickedFile!.name, 
          );
        } else {
          if (_pickedFile!.path == null) throw Exception("File path missing for mobile upload.");
          fileToUpload = CloudinaryFile.fromFile(
            _pickedFile!.path!, 
            resourceType: resourceType,
            folder: 'collablearn/assignments/${widget.classId}',
          );
        }

        final CloudinaryResponse response = await cloudinary.uploadFile(
          fileToUpload,
          onProgress: (count, total) {
            if (mounted) {
              setState(() {
                _uploadProgress = count / total;
              });
            }
          },
        );
        
        if (response.secureUrl.isEmpty) {
            throw Exception("Cloudinary upload failed to return a secure URL.");
        }
        
        downloadUrl = response.secureUrl;
        cloudinaryPublicId = response.publicId;
        fileName = _pickedFile!.name;
      }
      // --- END OF FILE UPLOAD ---

      // Save all data to Firestore
      await FirebaseFirestore.instance.collection('assignments').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'courseId': widget.classId,
        'points': points,
        'dueDate': Timestamp.fromDate(_selectedDueDate!),
        'postedBy': userName,
        'postedById': FirebaseAuth.instance.currentUser!.uid,
        'postedOn': Timestamp.now(),
        'type': 'assignment',
        // Add file data (will be null if no file was attached)
        'fileUrl': downloadUrl,
        'cloudinaryPublicId': cloudinaryPublicId,
        'fileName': fileName,
      });

      if (mounted) {
        Navigator.pop(context);
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
    // ... (rest of build method is unchanged until the attachment part)
    final primaryColor = Theme.of(context).colorScheme.primary;
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
                // ... (This row is unchanged)
                children: [
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
                        if (value == null || value.isEmpty) return 'Points needed';
                        if (int.tryParse(value) == null || (int.tryParse(value) ?? 0) <= 0) return 'Must be positive number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
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

              // --- NEW: ATTACHMENT SECTION ---
              const Text(
                'Attach File (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(_pickedFile == null ? 'Select File' : 'Change File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_pickedFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_pickedFile!.name, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              // --- END ATTACHMENT SECTION ---

              const SizedBox(height: 30),
              
              // --- NEW: UPLOAD PROGRESS BAR ---
              if (_isLoading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _uploadProgress.clamp(0.0, 1.0), color: primaryColor),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
                      child: Text('${(_uploadProgress * 100).toStringAsFixed(0)}% Uploading...'),
                    ),
                  ],
                ),

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
