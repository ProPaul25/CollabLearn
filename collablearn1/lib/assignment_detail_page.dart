// lib/assignment_detail_page.dart - CORRECTED

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // <-- NEW IMPORT

// Import necessary files
import 'study_materials_view_page.dart'; // Contains Assignment and AssignmentItem models
import 'create_assignment_page.dart';     // For instructor's Edit button
import 'submission_review_page.dart';    // For instructor's overall review page

// --- CLOUDINARY DEPENDENCY (Ensure these are correct) ---
const String _CLOUD_NAME = 'dc51dx2da';
const String _UPLOAD_PRESET = 'CollabLearn';

final CloudinaryPublic cloudinary =
    CloudinaryPublic(_CLOUD_NAME, _UPLOAD_PRESET, cache: false);
// --------------------------------------------------------

class AssignmentDetailPage extends StatefulWidget {
  final Assignment assignment; // Full Assignment model

  const AssignmentDetailPage({super.key, required this.assignment});

  @override
  State<AssignmentDetailPage> createState() => _AssignmentDetailPageState();
}

class _AssignmentDetailPageState extends State<AssignmentDetailPage> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  late final Future<bool> _isInstructorFuture;

  // Student submission state
  PlatformFile? _pickedFile;
  bool _isLoading = false;
  double _uploadProgress = 0;
  Map<String, dynamic>? _existingSubmission;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _isInstructorFuture = _isCurrentUserInstructor();
    _loadCurrentUserData();
  }

  // --- Role & Data Fetching ---

  Future<void> _loadCurrentUserData() async {
    if (_currentUser == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final String firstName = data?['firstName'] ?? '';
        final String lastName = data?['lastName'] ?? '';
        String calculatedName = "$firstName $lastName".trim();
        setState(() {
          _currentUserName = calculatedName.isEmpty
              ? (_currentUser.email ?? 'Anonymous')
              : calculatedName;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<bool> _isCurrentUserInstructor() async {
    if (_currentUser == null) return false;
    return widget.assignment.postedById == _currentUser.uid;
  }

  Future<void> _fetchUserSubmission() async {
    if (_currentUser == null) return;

    final submissionQuery = await FirebaseFirestore.instance
        // FIX 2: Changed 'submissions' to 'assignment_submissions'
        .collection('assignment_submissions')
        .where('assignmentId', isEqualTo: widget.assignment.id)
        .where('studentId', isEqualTo: _currentUser.uid)
        .limit(1)
        .get();

    if (mounted) {
      setState(() {
        if (submissionQuery.docs.isNotEmpty) {
          _existingSubmission = {
            ...submissionQuery.docs.first.data(),
            'submissionDocId': submissionQuery.docs.first.id,
          };
        } else {
          _existingSubmission = null;
        }
      });
    }
  }

  // --- File Handling and Submission Logic ---

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
        _uploadProgress = 0;
      });
    }
  }

  // --- Cloudinary Upload Logic (FIXED for Mobile + Web) ---
  Future<String?> _uploadFileToCloudinary(PlatformFile file) async {
    try {
      final CloudinaryResourceType resourceType = file.extension == 'pdf' 
          ? CloudinaryResourceType.Auto
          : CloudinaryResourceType.Raw;

      // FIX 1: Create the correct CloudinaryFile type based on platform
      CloudinaryFile fileToUpload;
      if (kIsWeb) {
        // WEB: Use bytes
        if (file.bytes == null) {
          _showSnackBar('Error: File bytes are null on web.');
          return null;
        }
        fileToUpload = CloudinaryFile.fromBytesData(
          file.bytes!,
          resourceType: resourceType,
          folder: 'collab-learn/submissions/${widget.assignment.courseId}',
          identifier: file.name,
        );
      } else {
        // MOBILE: Use path
        if (file.path == null) {
          _showSnackBar('Error: File path is null on mobile.');
          return null;
        }
        fileToUpload = CloudinaryFile.fromFile(
          file.path!,
          resourceType: resourceType,
          folder: 'collab-learn/submissions/${widget.assignment.courseId}',
          identifier: file.name,
        );
      }

      final response = await cloudinary.uploadFile(
        fileToUpload,
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
      _showSnackBar('File upload failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('General upload error: $e');
      _showSnackBar('An unexpected error occurred during file upload: $e');
      return null;
    }
  }


  Future<void> _submitAssignment() async {
    if (_pickedFile == null) {
      _showSnackBar('Please attach a file to submit.');
      return;
    }
    if (_currentUser == null || _currentUserName == null) {
      _showSnackBar('User data not loaded. Please try again.');
      return;
    }
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    final fileUrl = await _uploadFileToCloudinary(_pickedFile!);

    if (fileUrl == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final submissionData = {
        'assignmentId': widget.assignment.id,
        'studentId': _currentUser.uid,
        'studentName': _currentUserName,
        'submittedOn': FieldValue.serverTimestamp(),
        'fileUrl': fileUrl,
        'fileName': _pickedFile!.name,
        'isGraded': false,
        'grade': null,
        'feedback': null,
        // FIX 2: Added missing fields that student_submission_detail needs
        'courseId': widget.assignment.courseId, 
        'graded': false,
        'score': null,
      };

      if (_existingSubmission != null) {
        // RESUBMIT/UPDATE
        await FirebaseFirestore.instance
            // FIX 2: Changed 'submissions' to 'assignment_submissions'
            .collection('assignment_submissions')
            .doc(_existingSubmission!['submissionDocId'])
            .update(submissionData);
        _showSnackBar('Assignment successfully re-submitted!');
      } else {
        // NEW SUBMISSION
        await FirebaseFirestore.instance
            // FIX 2: Changed 'submissions' to 'assignment_submissions'
            .collection('assignment_submissions')
            .add(submissionData);
        _showSnackBar('Assignment successfully submitted!');
      }

      // Reload submission status
      await _fetchUserSubmission();
    } catch (e) {
      debugPrint('Error submitting assignment: $e');
      _showSnackBar('Failed to submit assignment: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _pickedFile = null;
          _uploadProgress = 0;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // --- UI Helpers ---

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      _showSnackBar('Could not open file.');
    }
  }

  Widget _buildFileLink(String url, String fileName, Color color) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                style: TextStyle(color: color, decoration: TextDecoration.underline),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Student View (Unchanged) ---
  Widget _buildStudentSubmissionView() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final dueDateTime = widget.assignment.dueDate.toDate();
    final isOverdue = DateTime.now().isAfter(dueDateTime);
    // FIXED: Removed unused deadlineText variable

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (_existingSubmission != null) {
      final isGraded = _existingSubmission!['isGraded'] == true;
      if (isGraded) {
        // FIX: Use 'score' field to match instructor's page
        statusText = 'GRADED: ${_existingSubmission!['score'] ?? 'N/A'} / ${widget.assignment.points}';
        statusColor = Colors.green.shade800;
        statusIcon = Icons.done_all;
      } else {
        statusText = isOverdue ? 'Submitted Late' : 'Submitted';
        statusColor = isOverdue ? Colors.orange.shade700 : Colors.green;
        statusIcon = Icons.check_circle;
      }
    } else {
      statusText = isOverdue ? 'MISSING / Overdue' : 'Assigned';
      statusColor = isOverdue ? Colors.red.shade700 : Colors.blue;
      statusIcon = isOverdue ? Icons.error_outline : Icons.pending_actions;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Submission Status Card
          Card(
            color: Color.fromRGBO(statusColor.red, statusColor.green, statusColor.blue, 0.1), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: statusColor)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 10),
                  Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  if (_existingSubmission != null && _existingSubmission!['isGraded'] == true)
                    Text('Points: ${_existingSubmission!['score'] ?? 'N/A'} / ${widget.assignment.points}', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Submission Form
          Text(
            _existingSubmission != null ? 'Resubmit Your Work' : 'Submit Your Work',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Divider(),
          
          if (_existingSubmission != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Submission:'),
                _buildFileLink(
                  _existingSubmission!['fileUrl'], // FIX: Use 'fileUrl'
                  _existingSubmission!['fileName'], // FIX: Use 'fileName'
                  Colors.blue.shade700,
                ),
                const SizedBox(height: 15),
              ],
            ),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_pickedFile != null ? 'Change File' : 'Pick File'),
                ),
              ),
            ],
          ),
          
          if (_pickedFile != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Selected: ${_pickedFile!.name}', overflow: TextOverflow.ellipsis)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() { _pickedFile = null; }),
                  ),
                ],
              ),
            ),

          if (_isLoading)
            Column(
              children: [
                const SizedBox(height: 10),
                LinearProgressIndicator(value: _uploadProgress.clamp(0.0, 1.0), color: primaryColor),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
                  child: Text('${(_uploadProgress * 100).toStringAsFixed(0)}% Uploading...'),
                ),
              ],
            ),
            
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitAssignment,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_existingSubmission != null ? Icons.refresh : Icons.send),
              label: Text(_isLoading 
                  ? 'Submitting...' 
                  : (_existingSubmission != null ? 'Resubmit Assignment' : 'Submit Assignment')),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          
          // Optional: Display grade/feedback
          if (_existingSubmission != null && _existingSubmission!['isGraded'] == true) ...[
            const SizedBox(height: 20),
            Text('Instructor Feedback', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Card(
              elevation: 0,
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  _existingSubmission!['feedback'] ?? 'No feedback provided.',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  // --- Instructor View (Unchanged) ---
  Widget _buildInstructorReviewView(String classId) {
    final assignmentItem = AssignmentItem(
      id: widget.assignment.id,
      title: widget.assignment.title,
      dueDate: widget.assignment.dueDate,
      description: widget.assignment.description,
      points: widget.assignment.points,
      postedBy: widget.assignment.postedBy,
      courseId: widget.assignment.courseId,
      postedById: widget.assignment.postedById, 
      fileUrl: widget.assignment.fileUrl,
      fileName: widget.assignment.fileName,
    );

    return SubmissionReviewPage(
      assignment: assignmentItem,
      classId: classId,
    );
  }

  // --- Main Build Method (Unchanged) ---
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final dueDateTime = widget.assignment.dueDate.toDate();
    final isOverdue = DateTime.now().isAfter(dueDateTime);
    final deadlineText = DateFormat('MMM d, yyyy @ h:mm a').format(dueDateTime);
    
    final assignmentDetails = SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.assignment.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.event, size: 18, color: isOverdue ? Colors.red : Colors.grey),
              const SizedBox(width: 5),
              Text(
                'Due: $deadlineText',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isOverdue ? Colors.red.shade700 : Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Icon(Icons.score, size: 18, color: Colors.amber.shade700),
              const SizedBox(width: 5),
              Text(
                '${widget.assignment.points} Points',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          
          Text(
            'Instructions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            widget.assignment.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          
          if (widget.assignment.fileUrl?.isNotEmpty == true) ...[ 
            const SizedBox(height: 20),
            Text(
              'Attachment',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            _buildFileLink(
              widget.assignment.fileUrl ?? '',
              widget.assignment.fileName ?? '',
              primaryColor,
            ),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    );

    return FutureBuilder<bool>(
      future: _isInstructorFuture,
      builder: (context, snapshot) {
        final isInstructor = snapshot.data ?? false;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Student View: Always fetch submission status before showing content
        if (!isInstructor) {
          _fetchUserSubmission();
        }
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Assignment Details'),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            actions: [
              if (isInstructor)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final shouldRefresh = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CreateAssignmentPage(
                            classId: widget.assignment.courseId,
                            assignmentId: widget.assignment.id,
                            assignmentData: { 
                              'title': widget.assignment.title,
                              'description': widget.assignment.description,
                              'points': widget.assignment.points,
                              'dueDate': widget.assignment.dueDate,
                              'courseId': widget.assignment.courseId,
                              'postedBy': widget.assignment.postedBy,
                              'postedById': widget.assignment.postedById,
                              'fileUrl': widget.assignment.fileUrl,
                              'fileName': widget.assignment.fileName,
                            },
                          ),
                        ),
                      );
                      if (shouldRefresh == true) {
                        setState(() {});
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Assignment'),
                    ),
                  ],
                ),
            ],
          ),
          
          // Use DefaultTabController for tabbed view
          body: isInstructor
              ? DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      // Assignment Details in the top scrollable area
                      Expanded(
                        child: TabBarView(
                          children: [
                            // 1. Details Tab
                            assignmentDetails,
                            // 2. Submissions Tab
                            _buildInstructorReviewView(widget.assignment.courseId),
                          ],
                        ),
                      ),
                      // Tab Bar fixed at the bottom
                      Container(
                        color: primaryColor,
                        child: const TabBar(
                          tabs: [
                            Tab(icon: Icon(Icons.info_outline), text: 'Details'),
                            Tab(icon: Icon(Icons.group), text: 'Submissions'),
                          ],
                          indicatorColor: Colors.white,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                )
              // Student View: Single view
              : Column(
                  children: [
                    // Assignment Details in a fixed height area
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: assignmentDetails,
                    ),
                    const Divider(height: 1),
                    // Submission View in the remaining area
                    Expanded(
                      child: _buildStudentSubmissionView(),
                    ),
                  ],
                ),
        );
      },
    );
  }
}