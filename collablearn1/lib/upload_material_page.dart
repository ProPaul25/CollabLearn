// lib/upload_material_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // NEW IMPORT

class UploadMaterialPage extends StatefulWidget {
  final String classId;

  const UploadMaterialPage({
    super.key,
    required this.classId,
  });

  @override
  State<UploadMaterialPage> createState() => _UploadMaterialPageState();
}

class _UploadMaterialPageState extends State<UploadMaterialPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  PlatformFile? _pickedFile;
  bool _isLoading = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Helper to fetch the current user's name
  Future<String> _getCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return userDoc.data()?['name'] ?? 'Instructor';
    }
    return 'Instructor';
  }

  // --- 1. PICK FILE ---
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // You can add more allowed extensions here
      allowedExtensions: ['pdf', 'pptx', 'docx', 'zip', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  // --- 2. UPLOAD & SUBMIT (FIXED FOR WEB) ---
  Future<void> _uploadAndSubmit() async {
    if (!_formKey.currentState!.validate() || _pickedFile == null) {
      // ... (validation code)
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userName = await _getCurrentUserName();
      final storageRef = FirebaseStorage.instance.ref()
          .child('course_materials/${widget.classId}/${_pickedFile!.name}');

      // 1. Choose the correct upload method based on the platform
      UploadTask uploadTask;
      
      // Define metadata with a fallback content type.
      final SettableMetadata metadata = SettableMetadata(
          // Using a generic binary type is safe. Firebase will often infer a better type.
          contentType: 'application/octet-stream' 
      );
      
      if (kIsWeb) {
        // FIX: Use putData() with the file bytes and the safe metadata.
        uploadTask = storageRef.putData(
          _pickedFile!.bytes!,
          metadata, // Use the fallback metadata
        );
      } else {
        // For mobile/desktop, use putFile() with the file path
        // The content type is often inferred better on mobile/desktop
        uploadTask = storageRef.putFile(
          File(_pickedFile!.path!),
          metadata,
        );
      }

      // ... (rest of the upload and Firestore logic)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred.toDouble() / snapshot.totalBytes.toDouble();
        });
      });

      // Wait for upload completion and get download URL
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 2. Save metadata to Firestore
      await FirebaseFirestore.instance.collection('study_materials').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'fileUrl': downloadUrl,
        'fileName': _pickedFile!.name,
        'fileSize': _pickedFile!.size,
        'fileExtension': _pickedFile!.extension,
        'courseId': widget.classId,
        'uploaderId': user!.uid,
        'uploaderName': userName,
        'uploadedOn': Timestamp.now(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Study material uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Study Material'),
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
                decoration: const InputDecoration(labelText: 'Title (e.g., Week 5 Slides)'),
                validator: (value) => value!.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 20),
              
              // Description Field
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) => value!.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 30),

              // File Picker Button
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(_pickedFile == null ? 'Select File' : 'Change File'),
              ),
              
              const SizedBox(height: 10),
              
              // Selected File Display
              if (_pickedFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file, color: primaryColor),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_pickedFile!.name, overflow: TextOverflow.ellipsis)),
                      Text('${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),

              const SizedBox(height: 40),

              // Upload Progress Bar
              if (_isLoading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _uploadProgress, color: primaryColor),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('${(_uploadProgress * 100).toStringAsFixed(0)}% Uploaded'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _uploadAndSubmit,
                  icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload),
                  label: Text(_isLoading ? 'Uploading...' : 'Upload Material'),
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