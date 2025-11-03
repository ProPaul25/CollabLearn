// lib/assignment_detail_page.dart - FIXED

import 'student_submission_detail.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'dart:typed_data'; 
import 'package:cloudinary_public/cloudinary_public.dart'; 
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
// Import models from the corrected file
import 'study_materials_view_page.dart'; 

// --- CLOUDINARY DEPENDENCY (Unchanged) ---
const String _CLOUD_NAME = 'dc51dx2da'; 
const String _UPLOAD_PRESET = 'CollabLearn'; 
final CloudinaryPublic cloudinary = CloudinaryPublic(_CLOUD_NAME, _UPLOAD_PRESET, cache: false);
// ----------------------------------------------

// --- The 'Assignment' class definition is REMOVED from this file ---
// It is now defined in and imported from 'study_materials_view_page.dart'


class AssignmentDetailPage extends StatefulWidget {
  final Assignment assignment; // This now correctly finds the Assignment model

  const AssignmentDetailPage({super.key, required this.assignment});

  @override
  State<AssignmentDetailPage> createState() => _AssignmentDetailPageState();
}

class _AssignmentDetailPageState extends State<AssignmentDetailPage> {
  // ... (State logic is unchanged) ...
  final User? user = FirebaseAuth.instance.currentUser;
  late Future<bool> _isInstructorFuture;
  String _instructorId = '';

  @override
  void initState() {
    super.initState();
    _isInstructorFuture = _checkIfInstructor();
  }

  Future<bool> _checkIfInstructor() async {
    if (user == null) return false;
    try {
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.assignment.courseId)
          .get();
      if (classDoc.exists) {
        _instructorId = classDoc.data()?['instructorId'] ?? '';
        return user!.uid == _instructorId;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  String _formatDueDate(Timestamp timestamp) {
    return DateFormat('MMM dd, yyyy HH:mm').format(timestamp.toDate());
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Build method is unchanged) ...
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment.title),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<bool>(
        future: _isInstructorFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final bool isInstructor = snapshot.data ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Due: ${_formatDueDate(widget.assignment.dueDate)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            Text('${widget.assignment.points} Points', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: primaryColor)),
                          ],
                        ),
                        const Divider(height: 20),
                        Text(widget.assignment.description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                        
                        if (widget.assignment.fileUrl != null && widget.assignment.fileName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 15.0),
                            child: InkWell(
                              onTap: () => _launchUrl(widget.assignment.fileUrl!),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ListTile(
                                  leading: Icon(Icons.attach_file, color: primaryColor),
                                  title: Text(widget.assignment.fileName!, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                  trailing: const Icon(Icons.download_for_offline, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (isInstructor)
                  _TeacherAssignmentView(
                    assignment: widget.assignment,
                    classId: widget.assignment.courseId,
                  )
                else
                  _StudentAssignmentView(
                    assignment: widget.assignment,
                    user: user!,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ===================================================================
// 1. STUDENT VIEW WIDGET (Unchanged)
// ===================================================================
class _StudentAssignmentView extends StatefulWidget {
  final Assignment assignment;
  final User user;

  const _StudentAssignmentView({
    required this.assignment,
    required this.user,
  });

  @override
  State<_StudentAssignmentView> createState() => _StudentAssignmentViewState();
}

class _StudentAssignmentViewState extends State<_StudentAssignmentView> {
  // ... (All state logic is unchanged) ...
  PlatformFile? _pickedFile;
  bool _isLoading = false;
  double _uploadProgress = 0;
  Map<String, dynamic>? _currentSubmission;
  bool _isFetchingStatus = true;

  @override
  void initState() {
    super.initState();
    _fetchSubmissionStatus();
  }

  String _formatSubmitDate(Timestamp timestamp) {
    return DateFormat('MMM dd, yyyy HH:mm').format(timestamp.toDate());
  }

  Future<void> _fetchSubmissionStatus() async {
    setState(() => _isFetchingStatus = true);
    final query = await FirebaseFirestore.instance
        .collection('assignment_submissions')
        .where('assignmentId', isEqualTo: widget.assignment.id)
        .where('studentId', isEqualTo: widget.user.uid)
        .limit(1)
        .get();

    if (mounted) {
      setState(() {
        if (query.docs.isNotEmpty) {
          _currentSubmission = query.docs.first.data();
        } else {
          _currentSubmission = null;
        }
        _isFetchingStatus = false;
      });
    }
  }
  
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'zip', 'png', 'jpg'],
    );
    if (result != null && mounted) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $uri');
    }
  }

  Future<void> _uploadAndSubmit() async {
    // ... (All submission logic is unchanged) ...
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
      
      CloudinaryResourceType resourceType = CloudinaryResourceType.Raw;
      if (['jpg', 'png'].contains(_pickedFile!.extension)) {
          resourceType = CloudinaryResourceType.Image;
      }
      
      CloudinaryFile fileToUpload;
      if (kIsWeb) {
        fileToUpload = CloudinaryFile.fromByteData(
          _pickedFile!.bytes!.buffer.asByteData(), 
          resourceType: resourceType,
          folder: 'collablearn/submissions/${widget.assignment.courseId}/${widget.assignment.id}',
          publicId: '${widget.user.uid}_${_pickedFile!.name}',
          identifier: _pickedFile!.name, 
        );
      } else {
        fileToUpload = CloudinaryFile.fromFile(
          _pickedFile!.path!, 
          resourceType: resourceType,
          folder: 'collablearn/submissions/${widget.assignment.courseId}/${widget.assignment.id}',
          publicId: '${widget.user.uid}_${_pickedFile!.name}',
        );
      }
      
      final CloudinaryResponse response = await cloudinary.uploadFile(
        fileToUpload,
        onProgress: (count, total) {
          if (mounted) setState(() => _uploadProgress = count / total);
        },
      );
      
      if (response.secureUrl.isEmpty) {
          throw Exception("Cloudinary upload failed.");
      }
      
      final downloadUrl = response.secureUrl; 
      final cloudinaryPublicId = response.publicId; 

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
      final studentName = '${userDoc.data()?['firstName'] ?? ''} ${userDoc.data()?['lastName'] ?? ''}'.trim();

      final submissionData = {
        'assignmentId': widget.assignment.id,
        'courseId': widget.assignment.courseId,
        'studentId': widget.user.uid,
        'studentName': studentName.isEmpty ? 'Unknown Student' : studentName,
        'submittedFileUrl': downloadUrl,
        'cloudinaryPublicId': cloudinaryPublicId, 
        'submittedFileName': _pickedFile!.name,
        'submissionTime': submissionTime,
        'graded': false,
        'score': null,
        'feedback': null,
      };

      if (_currentSubmission != null) {
        final existingRef = await FirebaseFirestore.instance
          .collection('assignment_submissions')
          .where('assignmentId', isEqualTo: widget.assignment.id)
          .where('studentId', isEqualTo: widget.user.uid)
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
    // ... (All build logic is unchanged) ...
    if (_isFetchingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    final primaryColor = Theme.of(context).colorScheme.primary;
    final isSubmitted = _currentSubmission != null;
    final isLate = DateTime.now().isAfter(widget.assignment.dueDate.toDate());
    final isGraded = _currentSubmission?['graded'] ?? false;
    final score = _currentSubmission?['score'];
    final feedback = _currentSubmission?['feedback'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Icon(isGraded ? Icons.check_circle : (isSubmitted ? Icons.upload_file : (isLate ? Icons.error : Icons.hourglass_empty)),
                    color: isGraded ? Colors.green : (isSubmitted ? Colors.blue : Colors.red)),
              const SizedBox(width: 10),
              Text(
                isGraded ? 'GRADED: $score/${widget.assignment.points}' : (isSubmitted ? 'SUBMITTED' : (isLate ? 'MISSING (LATE)' : 'NOT SUBMITTED')),
                style: TextStyle(fontWeight: FontWeight.bold, color: isGraded ? Colors.green : (isSubmitted ? Colors.blue : Colors.red)),
              ),
            ],
          ),
        ),
        
        if (isGraded && feedback != null && feedback.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Instructor Feedback:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(feedback),
                ],
              ),
            ),
          ),

        const SizedBox(height: 40),

        const Text('Your Submission', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Divider(),
        
        if (isSubmitted)
          Card(
            color: Colors.blue.shade50,
            child: ListTile(
              leading: Icon(Icons.file_present, color: Colors.blue.shade700),
              title: Text(_currentSubmission!['submittedFileName'] ?? 'Submitted File', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
              subtitle: Text('Submitted: ${_formatSubmitDate(_currentSubmission!['submissionTime'])}'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _launchUrl(_currentSubmission!['submittedFileUrl']),
            ),
          ),
        
        const SizedBox(height: 20),
        
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _pickFile,
          icon: const Icon(Icons.attach_file),
          label: Text(_pickedFile == null ? 'Select Answer File' : 'Change File'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade400,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        
        if (_pickedFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Text('Selected: ${_pickedFile!.name}', style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
        
        const SizedBox(height: 10),
        
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

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isLoading || isGraded) ? null : _uploadAndSubmit,
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
            label: Text(
              isGraded ? 'Graded - Cannot Resubmit' : (isSubmitted ? 'Re-Submit Assignment' : 'Submit Assignment')
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isGraded ? Colors.grey : primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
      ],
    );
  }
}

// ===================================================================
// 2. TEACHER VIEW WIDGET (Unchanged)
// ===================================================================
class _TeacherAssignmentView extends StatelessWidget {
  final Assignment assignment;
  final String classId;

  const _TeacherAssignmentView({
    required this.assignment,
    required this.classId,
  });
  
  // ... (All fetch logic is unchanged) ...
  Future<Map<String, dynamic>> _getSubmissionsData() async {
    // 1. Get all students in the class
    final classDoc = await FirebaseFirestore.instance.collection('classes').doc(classId).get();
    final studentIds = List<String>.from(classDoc.data()?['studentIds'] ?? []);
    
    // 2. Get all submissions for this assignment
    final submissionsSnapshot = await FirebaseFirestore.instance
        .collection('assignment_submissions')
        .where('assignmentId', isEqualTo: assignment.id)
        .get();
        
    // 3. Map submissions by studentId for easy lookup
    final Map<String, Map<String, dynamic>> submissionsMap = {};
    for (var doc in submissionsSnapshot.docs) {
      final data = doc.data();
      data['submissionDocId'] = doc.id; // Add the doc ID for navigation
      submissionsMap[data['studentId']] = data;
    }
    
    // 4. Fetch details for all students
    List<Map<String, dynamic>> allStudents = [];
    if (studentIds.isNotEmpty) {
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: studentIds)
          .get();
      allStudents = studentsSnapshot.docs.map((doc) => doc.data()..['uid'] = doc.id).toList();
    }
    
    // 5. Categorize students
    final List<Map<String, dynamic>> submitted = [];
    final List<Map<String, dynamic>> notSubmitted = [];

    for (var student in allStudents) {
      final studentId = student['uid'];
      final studentName = '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.trim();
      
      if (submissionsMap.containsKey(studentId)) {
        final submission = submissionsMap[studentId]!;
        submission['studentName'] = studentName.isEmpty ? 'Student' : studentName;
        submitted.add(submission);
      } else {
        notSubmitted.add({
          'studentName': studentName.isEmpty ? 'Student' : studentName,
          'studentId': studentId,
        });
      }
    }

    return {
      'totalStudents': studentIds.length,
      'submittedList': submitted,
      'notSubmittedList': notSubmitted,
    };
  }
  
  @override
  Widget build(BuildContext context) {
    // ... (All build logic is unchanged) ...
    final primaryColor = Theme.of(context).colorScheme.primary;

    return FutureBuilder<Map<String, dynamic>>(
      future: _getSubmissionsData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading submissions: ${snapshot.error}'));
        }
        
        final data = snapshot.data ?? {};
        final totalStudents = data['totalStudents'] ?? 0;
        final submittedList = data['submittedList'] as List<Map<String, dynamic>>? ?? [];
        final notSubmittedList = data['notSubmittedList'] as List<Map<String, dynamic>>? ?? [];
        
        final submittedCount = submittedList.length;
        final notSubmittedCount = notSubmittedList.length; 

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Submissions ($totalStudents)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          Text('$submittedCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                          const Text('Submitted'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          Text('$notSubmittedCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                          const Text('Not Submitted'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text('Submitted Files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            const Divider(),
            if (submittedList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('No submissions yet.'),
              ),
            ...submittedList.map((submission) {
              final isGraded = submission['graded'] as bool? ?? false;
              final score = submission['score'];
              
              // This now correctly finds the AssignmentItem model
              final assignmentItem = AssignmentItem(
                id: assignment.id,
                title: assignment.title,
                description: assignment.description,
                points: assignment.points,
                dueDate: assignment.dueDate,
                postedBy: assignment.postedBy,
                courseId: assignment.courseId,
                fileUrl: assignment.fileUrl,
                fileName: assignment.fileName,
              );
              
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: Icon(Icons.person, color: primaryColor),
                  title: Text(submission['studentName'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGraded ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      isGraded ? 'GRADED ($score)' : 'NEEDS GRADING',
                      style: TextStyle(color: isGraded ? Colors.green : Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => StudentSubmissionDetail(
                          submissionDocId: submission['submissionDocId'],
                          assignment: assignmentItem,
                          studentName: submission['studentName'],
                          isGraded: isGraded,
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
            
            const SizedBox(height: 20),
            Text('Not Submitted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            const Divider(),
            if (notSubmittedList.isEmpty && totalStudents > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('All students have submitted!'),
              ),
            ...notSubmittedList.map((student) {
              return ListTile(
                leading: Icon(Icons.person_outline, color: Colors.grey),
                title: Text(student['studentName'], style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                trailing: const Text('Missing', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}