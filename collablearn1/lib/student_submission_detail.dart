// lib/student_submission_detail.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:url_launcher/url_launcher.dart';
import 'study_materials_view_page.dart'; // Import AssignmentItem model

class StudentSubmissionDetail extends StatefulWidget {
  final String submissionDocId;
  final AssignmentItem assignment;
  final String studentName;
  final bool isGraded;

  const StudentSubmissionDetail({
    super.key,
    required this.submissionDocId,
    required this.assignment,
    required this.studentName,
    required this.isGraded,
  });

  @override
  State<StudentSubmissionDetail> createState() => _StudentSubmissionDetailState();
}

class _StudentSubmissionDetailState extends State<StudentSubmissionDetail> {
  final _gradeController = TextEditingController();
  final _feedbackController = TextEditingController(); // Added feedback controller
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load initial grade and feedback if already graded
    if (widget.isGraded) {
      _fetchInitialGrade();
    }
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialGrade() async {
    final submissionDoc = await FirebaseFirestore.instance.collection('assignment_submissions').doc(widget.submissionDocId).get();
    final data = submissionDoc.data();
    if (data != null) {
      // Pre-fill fields
      if (data.containsKey('score') && data['score'] != null) {
        _gradeController.text = data['score'].toString();
      }
      if (data.containsKey('feedback') && data['feedback'] != null) {
        _feedbackController.text = data['feedback'].toString();
      }
    }
  }

  // Helper to open the submitted file URL
  Future<void> _launchUrl(String url) async {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $uri');
      }
    }

  // Save the grade and feedback to Firestore
  Future<void> _saveGrade() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final score = int.tryParse(_gradeController.text.trim());
      final feedback = _feedbackController.text.trim();

      await FirebaseFirestore.instance.collection('assignment_submissions').doc(widget.submissionDocId).update({
        'score': score,
        'graded': true,
        'feedback': feedback, // Save instructor feedback
        'gradedOn': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grade and review saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to the Submission Review List
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save grade: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Stream the submission details for real-time updates 
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('assignment_submissions').doc(widget.submissionDocId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final submissionData = snapshot.data!.data();
        if (submissionData == null) {
          return const Scaffold(body: Center(child: Text('Submission not found.')));
        }

        // --- NEW: submissionData['submittedFileUrl'] now holds the Cloudinary URL ---
        final fileUrl = submissionData['submittedFileUrl'] as String? ?? '';
        final fileName = submissionData['submittedFileName'] as String? ?? 'Submission File';
        final isGraded = submissionData['graded'] ?? false;
        final score = submissionData['score'];

        // Ensure controllers reflect the latest data from the stream if initially empty
        if (_gradeController.text.isEmpty && score != null) {
          _gradeController.text = score.toString();
        }
        if (_feedbackController.text.isEmpty && submissionData['feedback'] != null) {
          _feedbackController.text = submissionData['feedback'].toString();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.studentName} - Grading'),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assignment: ${widget.assignment.title}', style: Theme.of(context).textTheme.headlineSmall),
                  const Divider(),

                  // --- Submission Info (File Download) ---
                  Card(
                    elevation: 2,
                    color: Colors.lightGreen.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.file_download, color: Colors.green),
                      title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Submitted on: ${(submissionData['submissionTime'] as Timestamp).toDate().toString().split('.')[0]}'),
                      trailing: const Icon(Icons.open_in_new),
                      // This tap uses the Cloudinary URL
                      onTap: fileUrl.isNotEmpty ? () => _launchUrl(fileUrl) : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Grading Input ---
                  Text('Grade Details (Max Points: ${widget.assignment.points})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _gradeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Score',
                            hintText: 'Enter score',
                            suffixText: '/ ${widget.assignment.points}',
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                          ),
                          validator: (value) {
                            final inputScore = int.tryParse(value ?? '');
                            if (inputScore == null) return 'Enter a number';
                            if (inputScore < 0 || inputScore > widget.assignment.points) {
                              return 'Score must be between 0 and ${widget.assignment.points}';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveGrade,
                          icon: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save),
                          label: Text(isGraded ? 'Update Grade' : 'Save Grade'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isGraded ? Colors.orange : primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // --- Feedback Input ---
                  TextFormField(
                    controller: _feedbackController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Review/Feedback (Optional)',
                      hintText: 'Provide constructive feedback here...',
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- Current Status Display ---
                  Card(
                    color: isGraded 
                        ? const Color(0x1A4CAF50) // Semi-transparent Green
                        : const Color(0x1AF44336), // Semi-transparent Red
                    child: ListTile(
                      leading: Icon(isGraded ? Icons.grade : Icons.pending, color: isGraded ? Colors.green : Colors.red),
                      title: Text(isGraded ? 'Current Grade: $score / ${widget.assignment.points}' : 'Awaiting Grading'),
                      subtitle: Text(isGraded ? 'Graded on: ${(submissionData['gradedOn'] as Timestamp?)?.toDate().toString().split('.')[0] ?? 'N/A'}' : 'Submission received.'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}