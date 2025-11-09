// lib/create_assignment_page.dart - CORRECTED AND COMPLETE WITH BACKGROUND UPLOAD

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:cloudinary_public/cloudinary_public.dart'; 

// --- CLOUDINARY INSTANCE ---
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
  final Map<String, dynamic>? assignmentData;
  final String? assignmentId;

  const CreateAssignmentPage({
    super.key,
    required this.classId,
    this.assignmentData,
    this.assignmentId,
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
  TimeOfDay? _selectedDueTime;
  
  // File upload state
  PlatformFile? _pickedFile;
  String? _uploadedFileUrl;
  String? _uploadedFileName;

  bool _isLoading = false; // For saving metadata
  bool _isUploading = false; // For file upload process
  double _uploadProgress = 0;
  late bool _isEditing;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.assignmentData != null && widget.assignmentId != null;
    
    // Initialize fields if editing an existing assignment
    if (_isEditing) {
      final data = widget.assignmentData!;
      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _pointsController.text = (data['points'] ?? 0).toString();
      
      _uploadedFileUrl = data['fileUrl'];
      _uploadedFileName = data['fileName'];

      if (data['dueDate'] is Timestamp) {
        final date = (data['dueDate'] as Timestamp).toDate();
        _selectedDueDate = date;
        _selectedDueTime = TimeOfDay.fromDateTime(date);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<String> _getCurrentUserName() async {
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
  
  // --- File Picker Logic (MODIFIED) ---
  Future<void> _pickFile() async {
    if (_isUploading) return; // Prevent double click

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null) {
      final file = result.files.first;
      setState(() {
        _pickedFile = file;
        _uploadedFileUrl = null; 
        _uploadedFileName = null; 
      });
      // Start upload immediately after picking a file
      await _uploadOnSelection(file); 
    }
  }

  // --- NEW: Upload on Selection Function ---
  Future<void> _uploadOnSelection(PlatformFile file) async {
    if (file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: File bytes are null.')),
      );
      if (mounted) setState(() => _pickedFile = null);
      return;
    }

    setState(() {
      _isUploading = true; 
      _uploadProgress = 0;
    });

    final url = await _uploadFileToCloudinary(file);

    if (mounted) {
      setState(() {
        _isUploading = false;
        if (url != null) {
          _uploadedFileUrl = url;
          _uploadedFileName = file.name;
          _pickedFile = null; // Clear picked file once upload is successful
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('File upload complete!')),
          );
        } else {
           _pickedFile = null; // Clear picked file if upload fails
        }
      });
    }
  }

  // --- Cloudinary Upload Logic (Extracting from the original function) ---
  Future<String?> _uploadFileToCloudinary(PlatformFile file) async {
    try {
      final CloudinaryResourceType resourceType = file.extension == 'pdf' 
          ? CloudinaryResourceType.Auto
          : CloudinaryResourceType.Raw;

      final bytes = file.bytes!;      

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          bytes,
          resourceType: resourceType,
          folder: 'collab-learn/assignments/${widget.classId}',
          identifier: file.name,
        ),
        onProgress: (count, total) {
          if (mounted) {
            setState(() {
              _uploadProgress = count / total;
            });
          }
        },
      );
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      debugPrint('Cloudinary upload error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File upload failed: ${e.message}')),
        );
      }
      return null;
    } catch (e) {
      debugPrint('General upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred during file upload: $e')),
        );
      }
      return null;
    }
  }


  // --- Date/Time Picker Logic (Unchanged) ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && pickedDate != _selectedDueDate) {
      setState(() {
        _selectedDueDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedDueTime ?? TimeOfDay.now(),
    );
    if (pickedTime != null && pickedTime != _selectedDueTime) {
      setState(() {
        _selectedDueTime = pickedTime;
      });
    }
  }

  // --- Main Post/Edit Logic (MODIFIED for Metadata Only) ---
  Future<void> _postAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDueDate == null || _selectedDueTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date and time.')),
      );
      return;
    }
    if (_isUploading || _isLoading) return; 
    
    // Check if the user intends to attach a file but hasn't uploaded successfully
    if (_pickedFile != null && _uploadedFileUrl == null) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is still uploading or upload failed. Please wait or try again.')),
       );
       return;
    }

    setState(() {
      _isLoading = true;
    });
    
    // Use the final uploaded URL/Name state
    String? fileUrl = _uploadedFileUrl;
    String fileName = _uploadedFileName ?? '';

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userName = await _getCurrentUserName();
      final collection = FirebaseFirestore.instance.collection('assignments');
      
      final DateTime finalDueDate = _selectedDueDate!.add(
        Duration(hours: _selectedDueTime!.hour, minutes: _selectedDueTime!.minute),
      );

      final data = {
        'courseId': widget.classId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'points': int.tryParse(_pointsController.text) ?? 0,
        'dueDate': Timestamp.fromDate(finalDueDate),
        'fileUrl': fileUrl,
        'fileName': fileName, 
        'postedBy': userName,
        'postedById': user!.uid,
      };

      if (_isEditing && widget.assignmentId != null) {
        // EDIT LOGIC
        await collection.doc(widget.assignmentId).update({
          ...data, 
          'lastUpdatedOn': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment successfully updated!')),
          );
        }
      } else {
        // CREATE LOGIC
        await collection.add({
          ...data,
          'postedOn': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment successfully published!')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true); 
      }
    } catch (e) {
      debugPrint('Error posting/updating assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post/update assignment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Helper to format date/time for display (Unchanged) ---
  String _formatDateTime(DateTime date, TimeOfDay time) {
    final DateTime combined = date.add(Duration(hours: time.hour, minutes: time.minute));
    return DateFormat('MMM d, yyyy @ h:mm a').format(combined);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Assignment' : 'Create Assignment'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Assignment Title',
                    hintText: 'e.g., Weekly Project 1',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                  validator: (value) => value!.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 20),
                
                // 2. Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Provide details, instructions, and requirements.',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                  validator: (value) => value!.isEmpty ? 'Description is required' : null,
                ),
                const SizedBox(height: 20),
                
                // 3. Points
                TextFormField(
                  controller: _pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points',
                    hintText: 'e.g., 100',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return 'Points are required';
                    if (int.tryParse(value) == null) return 'Must be a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 4. Due Date & Time Pickers
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _selectedDueDate == null
                              ? 'Select Due Date'
                              : DateFormat('MMM d, yyyy').format(_selectedDueDate!),
                        ),
                        onPressed: () => _selectDate(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text(
                          _selectedDueTime == null
                              ? 'Select Due Time'
                              : _selectedDueTime!.format(context),
                        ),
                        onPressed: () => _selectTime(context),
                      ),
                    ),
                  ],
                ),
                if (_selectedDueDate != null && _selectedDueTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Due: ${_formatDateTime(_selectedDueDate!, _selectedDueTime!)}',
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 20),

                // 5. File Attachment
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploading ? null : _pickFile, 
                        icon: const Icon(Icons.attach_file),
                        label: Text(_isUploading ? 'Uploading...' : 'Attach File (Optional)'),
                      ),
                    ),
                  ],
                ),
                // Display picked file name only while uploading
                if (_pickedFile != null && _isUploading) 
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.insert_drive_file, color: primaryColor),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Uploading: ${_pickedFile!.name}', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  )
                // Display already uploaded file name
                else if (_uploadedFileUrl != null && _uploadedFileName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Attached: $_uploadedFileName', overflow: TextOverflow.ellipsis)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() { 
                            _uploadedFileUrl = null; 
                            _uploadedFileName = null; 
                          }),
                        ),
                      ],
                    ),
                  ),
           
                const SizedBox(height: 40),

                // --- UPLOAD PROGRESS BAR ---
                if (_isUploading)
                  Column(
                    children: [
                      LinearProgressIndicator(value: _uploadProgress.clamp(0.0, 1.0), color: primaryColor),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
                        child: Text('${(_uploadProgress * 100).toStringAsFixed(0)}% Uploading...'),
                      ),
                    ],
                  ),

                // 6. Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || _isUploading) ? null : _postAssignment, 
                    icon: (_isLoading || _isUploading)
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(_isEditing ? Icons.save : Icons.publish),
                    label: Text(
                        _isUploading 
                          ? 'Uploading...' 
                          : (_isLoading ? 'Saving...' : (_isEditing ? 'Save Changes' : 'Publish Assignment'))),
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
      ),
    );
  }
}