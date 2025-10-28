// lib/upload_material_page.dart - FINAL CLOUDINARY UPLOAD FIX (v7)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'dart:typed_data'; // Required for ByteData/Uint8List manipulation

// --- CLOUDINARY DEPENDENCY & INITIALIZATION ---
import 'package:cloudinary_public/cloudinary_public.dart'; 

const String _CLOUD_NAME = 'dc51dx2da'; 
const String _UPLOAD_PRESET = 'CollabLearn'; 

final CloudinaryPublic cloudinary = CloudinaryPublic(
  _CLOUD_NAME,
  _UPLOAD_PRESET,
  cache: false,
);
// ------------------------------------


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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'pptx', 'docx', 'zip', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }


  // --- 2. UPLOAD & SUBMIT (MODIFIED CLOUDINARY LOGIC) ---
  Future<void> _uploadAndSubmit() async {
    if (!_formKey.currentState!.validate() || _pickedFile == null) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userName = await _getCurrentUserName();
      
      CloudinaryResourceType resourceType;
      if (_pickedFile!.extension!.contains('pdf') || _pickedFile!.extension!.contains('doc') || _pickedFile!.extension!.contains('zip') || _pickedFile!.extension!.contains('pptx')) {
          resourceType = CloudinaryResourceType.Raw; 
      } else {
          resourceType = CloudinaryResourceType.Image;
      }
      
      // 1. Upload to Cloudinary
      CloudinaryFile fileToUpload;

      if (kIsWeb) {
        if (_pickedFile!.bytes == null) throw Exception("File bytes missing for web upload.");
        // FIX: Removed unsupported 'extension' parameter
        fileToUpload = CloudinaryFile.fromByteData(
          _pickedFile!.bytes!.buffer.asByteData(), 
          resourceType: resourceType,
          folder: 'collablearn/materials/${widget.classId}',
          identifier: _pickedFile!.name, 
        );
      } else {
        if (_pickedFile!.path == null) throw Exception("File path missing for mobile upload.");
        // FIX: Removed unsupported 'extension' parameter
        fileToUpload = CloudinaryFile.fromFile(
          _pickedFile!.path!, 
          resourceType: resourceType,
          folder: 'collablearn/materials/${widget.classId}',
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
      
      final downloadUrl = response.secureUrl;
      final cloudinaryPublicId = response.publicId;

      // 2. Save metadata to Firestore
      await FirebaseFirestore.instance.collection('study_materials').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'fileUrl': downloadUrl, // <-- CLOUDINARY SECURE URL
        'cloudinaryPublicId': cloudinaryPublicId, // <-- New Field
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
    } on CloudinaryException catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cloudinary upload failed: ${e.message}'), backgroundColor: Colors.red),
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
                    LinearProgressIndicator(value: _uploadProgress.clamp(0.0, 1.0), color: primaryColor),
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