// lib/assignment_detail_page.dart - FINAL CLOUDINARY UPLOAD FIX (v7)

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
// ----------------------------------------------

// Simplified Assignment Model (unchanged)
class Assignment {
  final String id;
  final String title;
  final String description;
  final int points;
  final Timestamp dueDate;
  final String postedBy;
  final String courseId;

  Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.dueDate,
    required this.postedBy,
    required this.courseId,
  });
}

class AssignmentDetailPage extends StatefulWidget {
  final Assignment assignment;

  const AssignmentDetailPage({super.key, required this.assignment});

  @override
  State<AssignmentDetailPage> createState() => _AssignmentDetailPageState();
}

class _AssignmentDetailPageState extends State<AssignmentDetailPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  PlatformFile? _pickedFile;
  bool _isLoading = false;
  double _uploadProgress = 0;
  Map<String, dynamic>? _currentSubmission;

  @override
  void initState() {
    super.initState();
    _fetchSubmissionStatus();
  }

  String _formatDueDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchSubmissionStatus() async {
    if (user == null) return;

    final query = await FirebaseFirestore.instance
        .collection('assignment_submissions')
        .where('assignmentId', isEqualTo: widget.assignment.id)
        .where('studentId', isEqualTo: user!.uid)
        .limit(1)
        .get();

    if (mounted) {
      if (query.docs.isNotEmpty) {
        setState(() {
          _currentSubmission = query.docs.first.data();
        });
      } else {
        setState(() {
          _currentSubmission = null;
        });
      }
    }
  }
  
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'zip', 'png', 'jpg'],
    );

    if (result != null) {
      if (mounted) {
        setState(() {
          _pickedFile = result.files.first;
        });
      }
    }
  }

  // --- 3. UPLOAD AND SUBMIT (MODIFIED CLOUDINARY LOGIC) ---
  Future<void> _uploadAndSubmit() async {
    if (_pickedFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a file to submit.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    if (DateTime.now().isAfter(widget.assignment.dueDate.toDate())) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission failed: The due date has passed. If late submissions are allowed, please contact your instructor.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final submissionTime = Timestamp.now();
      
      CloudinaryResourceType resourceType;
      if (_pickedFile!.extension!.contains('pdf') || _pickedFile!.extension!.contains('doc') || _pickedFile!.extension!.contains('txt') || _pickedFile!.extension!.contains('zip') || _pickedFile!.extension!.contains('pptx')) {
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
          folder: 'collablearn/submissions/${widget.assignment.courseId}/${widget.assignment.id}',
          publicId: '${user!.uid}_${widget.assignment.id}',
          identifier: _pickedFile!.name, 
        );
      } else {
        if (_pickedFile!.path == null) throw Exception("File path missing for mobile upload.");
        // FIX: Removed unsupported 'extension' parameter
        fileToUpload = CloudinaryFile.fromFile(
          _pickedFile!.path!, 
          resourceType: resourceType,
          folder: 'collablearn/submissions/${widget.assignment.courseId}/${widget.assignment.id}',
          publicId: '${user!.uid}_${widget.assignment.id}',
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

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final studentName = '${userDoc.data()?['firstName'] ?? ''} ${userDoc.data()?['lastName'] ?? ''}'.trim();

      // 4. Save/Update Submission Record in Firestore
      final submissionData = {
        'assignmentId': widget.assignment.id,
        'courseId': widget.assignment.courseId,
        'studentId': user!.uid,
        'studentName': studentName,
        'submittedFileUrl': downloadUrl,
        'cloudinaryPublicId': cloudinaryPublicId, 
        'submittedFileName': _pickedFile!.name,
        'submissionTime': submissionTime,
        'graded': false,
        'score': null,
      };

      if (_currentSubmission != null) {
        final existingRef = await FirebaseFirestore.instance
          .collection('assignment_submissions')
          .where('assignmentId', isEqualTo: widget.assignment.id)
          .where('studentId', isEqualTo: user!.uid)
          .limit(1)
          .get();
        
        if (existingRef.docs.isNotEmpty) {
          await existingRef.docs.first.reference.update(submissionData);
        }
      } else {
        await FirebaseFirestore.instance.collection('assignment_submissions').add(submissionData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment submitted successfully!'), backgroundColor: Colors.green),
        );
        _fetchSubmissionStatus(); 
        _pickedFile = null; 
      }
    } on CloudinaryException catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cloudinary submission failed: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isSubmitted = _currentSubmission != null;
    final isLate = DateTime.now().isAfter(widget.assignment.dueDate.toDate());
    final isGraded = _currentSubmission?['graded'] ?? false;
    final score = _currentSubmission?['score'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment.title),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- Assignment Metadata Card ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Due Date:', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text(_formatDueDate(widget.assignment.dueDate), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                    const SizedBox(height: 10),
                    Text('Points:', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text('${widget.assignment.points} Points', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                    const SizedBox(height: 10),
                    Text('Posted By:', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text(widget.assignment.postedBy, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Status Box ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGraded ? Colors.green.withOpacity(0.1) : (isSubmitted ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isGraded ? Colors.green : (isSubmitted ? Colors.blue : Colors.red),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(isGraded ? Icons.check_circle : (isSubmitted ? Icons.upload_file : Icons.hourglass_empty),
                       color: isGraded ? Colors.green : (isSubmitted ? Colors.blue : Colors.red)),
                  const SizedBox(width: 10),
                  Text(
                    isGraded ? 'GRADED: $score/${widget.assignment.points}' : (isSubmitted ? 'SUBMITTED' : (isLate ? 'MISSING (LATE)' : 'NOT SUBMITTED')),
                    style: TextStyle(fontWeight: FontWeight.bold, color: isGraded ? Colors.green : (isSubmitted ? Colors.blue : Colors.red)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- Description ---
            const Text('Instructions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            Text(widget.assignment.description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
            const SizedBox(height: 40),

            // --- Submission Section ---
            const Text('Your Submission', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            
            // File Picker Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_pickedFile == null ? 'Select Answer Sheet (PDF/DOCX)' : 'File Selected: ${_pickedFile!.name}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Submission Details and Progress
            if (_pickedFile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text('Selected: ${_pickedFile!.name}', style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
            
            if (_isLoading)
              Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress.clamp(0.0, 1.0), color: primaryColor),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('${(_uploadProgress * 100).toStringAsFixed(0)}% Uploading...'),
                  ),
                  const SizedBox(height: 10),
                ],
              ),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || isGraded) ? null : _uploadAndSubmit,
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
                label: Text(
                  isGraded ? 'Graded - Cannot Resubmit' : (_currentSubmission != null ? 'Re-Submit Assignment' : 'Submit Assignment')
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isGraded ? Colors.grey : primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),

            if (isSubmitted && !isGraded)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Center(
                  child: Text('Last submitted on ${_formatDueDate(_currentSubmission!['submissionTime'])}.', style: TextStyle(color: Colors.blue.shade700)),
                ),
              ),

          ],
        ),
      ),
    );
  }
}