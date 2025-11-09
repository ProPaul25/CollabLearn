// lib/upload_material_page.dart - CORRECTED WITH BACKGROUND UPLOAD

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:cloudinary_public/cloudinary_public.dart'; 

// --- (Cloudinary setup is unchanged) ---
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
  String? _uploadedFileUrl; 
  String? _uploadedFileName; 
  
  bool _isLoading = false; // For saving metadata
  bool _isUploading = false; // For file upload process
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

  // --- File Picker Logic (MODIFIED) ---
  Future<void> _pickFile() async {
    if (_isUploading) return;
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'pptx', 'docx', 'zip', 'jpg', 'png'],
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
    if (file.bytes == null && file.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: File data is missing.')),
      );
      if (mounted) setState(() => _pickedFile = null);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      // 1. Determine Resource Type
      CloudinaryResourceType resourceType;
      if (file.extension!.contains('pdf') || file.extension!.contains('doc') || file.extension!.contains('zip') || file.extension!.contains('pptx')) {
          resourceType = CloudinaryResourceType.Raw; 
      } else {
          resourceType = CloudinaryResourceType.Image;
      }
      
      // 2. Prepare File for Upload
      CloudinaryFile fileToUpload;
      if (kIsWeb) {
        if (file.bytes == null) throw Exception("File bytes missing for web upload.");
        fileToUpload = CloudinaryFile.fromByteData(
          file.bytes!.buffer.asByteData(), 
          resourceType: resourceType,
          folder: 'collablearn/materials/${widget.classId}',
          identifier: file.name, 
        );
      } else {
        if (file.path == null) throw Exception("File path missing for mobile upload.");
        fileToUpload = CloudinaryFile.fromFile(
          file.path!, 
          resourceType: resourceType,
          folder: 'collablearn/materials/${widget.classId}',
        );
      }

      // 3. Upload to Cloudinary
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('File upload complete! Fill out the details and submit.')),
        );
        setState(() {
          _uploadedFileUrl = response.secureUrl;
          _uploadedFileName = file.name;
          // Keep picked file to display name, size, and extension
          _pickedFile = file; 
        });
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
      if (mounted) setState(() => _isUploading = false);
    }
  }


  // --- UPDATED: _uploadAndSubmit (Only saves metadata now) ---
  Future<void> _uploadAndSubmit() async {
    if (!_formKey.currentState!.validate() || _pickedFile == null) {
      if (_pickedFile == null) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a file to upload.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    
    if (_uploadedFileUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is still uploading or upload failed. Please wait or re-select the file.'), backgroundColor: Colors.red),
        );
        return;
    }

    setState(() {
      _isLoading = true; 
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userName = await _getCurrentUserName();
      final postTime = Timestamp.now();
      
      final downloadUrl = _uploadedFileUrl!;
      final fileName = _uploadedFileName!;

      // 4. Use a Batch Write
      final batch = FirebaseFirestore.instance.batch();

      // Operation 1: Save metadata to 'study_materials' (for Classworks tab)
      final materialRef = FirebaseFirestore.instance.collection('study_materials').doc();
      batch.set(materialRef, {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'fileUrl': downloadUrl, 
        'fileName': fileName,
        'fileSize': _pickedFile!.size, 
        'fileExtension': _pickedFile!.extension,
        'courseId': widget.classId,
        'uploaderId': user.uid,
        'uploaderName': userName,
        'uploadedOn': postTime,
      });

      // Operation 2: Save to 'class_feed' (for Stream tab)
      final feedRef = FirebaseFirestore.instance.collection('class_feed').doc();
      batch.set(feedRef, {
        'type': 'material',
        'title': _titleController.text.trim(),
        'fileName': fileName,
        'fileUrl': downloadUrl,
        'courseId': widget.classId,
        'postedBy': userName,
        'postedById': user.uid,
        'lastActivityTimestamp': postTime,
        'pollId': null,
      });

      await batch.commit();

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
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title (e.g., Week 5 Slides)'),
                validator: (value) => value!.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) => value!.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(_pickedFile == null ? 'Select File' : 'Change File'),
              ),
              const SizedBox(height: 10),
              if (_pickedFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        _uploadedFileUrl != null ? Icons.check_circle : Icons.insert_drive_file, 
                        color: _uploadedFileUrl != null ? Colors.green : primaryColor
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_pickedFile!.name, overflow: TextOverflow.ellipsis)),
                      Text('${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
              if (_isUploading)
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isLoading || _isUploading) ? null : _uploadAndSubmit,
                  icon: (_isLoading || _isUploading) ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload),
                  label: Text(
                      _isUploading 
                        ? 'Uploading...' 
                        : (_isLoading ? 'Saving Metadata...' : 'Upload Material')),
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