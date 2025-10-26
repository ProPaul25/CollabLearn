// lib/assignment_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // For web/mobile file handling
import 'dart:io';

// Simplified Assignment Model (redefined here for clarity, though typically in a model file)
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

  // Helper to format timestamp
  String _formatDueDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // --- 1. FETCH SUBMISSION STATUS ---
  Future<void> _fetchSubmissionStatus() async {
    if (user == null) return;

    // Check for an existing submission record for this user and assignment
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
  
  // --- 2. PICK FILE ---
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'zip', 'png', 'jpg'], // Common doc formats
    );

    if (result != null) {
      if (mounted) {
        setState(() {
          _pickedFile = result.files.first;
        });
      }
    }
  }

  // --- 3. UPLOAD AND SUBMIT ---
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
          const SnackBar(content: Text('Submission failed: The due date has passed.'), backgroundColor: Colors.red),
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
      final storagePath = 'submissions/${widget.assignment.courseId}/${widget.assignment.id}/${user!.uid}_${_pickedFile!.name}';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      
      // Determine upload method (Web vs. Mobile)
      UploadTask uploadTask;
      final SettableMetadata metadata = SettableMetadata(contentType: 'application/octet-stream');

      if (kIsWeb) {
        uploadTask = storageRef.putData(_pickedFile!.bytes!, metadata);
      } else {
        uploadTask = storageRef.putFile(File(_pickedFile!.path!), metadata);
      }

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred.toDouble() / snapshot.totalBytes.toDouble();
          });
        }
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Get student name for easy instructor view
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final studentName = '${userDoc.data()?['firstName'] ?? ''} ${userDoc.data()?['lastName'] ?? ''}'.trim();


      // 4. Save/Update Submission Record in Firestore
      final submissionData = {
        'assignmentId': widget.assignment.id,
        'courseId': widget.assignment.courseId,
        'studentId': user!.uid,
        'studentName': studentName,
        'submittedFileUrl': downloadUrl,
        'submittedFileName': _pickedFile!.name,
        'submissionTime': submissionTime,
        'graded': false,
        'score': null,
      };

      // Check if this is an update (re-submission) or a new submission
      if (_currentSubmission != null) {
        // Update existing record
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
        // New submission
        await FirebaseFirestore.instance.collection('assignment_submissions').add(submissionData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assignment submitted successfully!'), backgroundColor: Colors.green),
        );
        _fetchSubmissionStatus(); // Refresh status immediately
        _pickedFile = null; // Clear picked file
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
                  LinearProgressIndicator(value: _uploadProgress, color: primaryColor),
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
