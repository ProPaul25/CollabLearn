// lib/submit_attendance_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubmitAttendancePage extends StatefulWidget {
  final String sessionCode;
  final String sessionId;

  const SubmitAttendancePage({
    super.key,
    required this.sessionCode,
    required this.sessionId,
  });

  @override
  State<SubmitAttendancePage> createState() => _SubmitAttendancePageState();
}

class _SubmitAttendancePageState extends State<SubmitAttendancePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    final submittedCode = _codeController.text.trim();

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Get the session document to check validity and end time
      final sessionDoc = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .doc(widget.sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Attendance session not found.');
      }

      final sessionData = sessionDoc.data()!;
      final validCode = sessionData['sessionCode'] == submittedCode;
      final endTime = (sessionData['endTime'] as Timestamp).toDate();
      final isExpired = DateTime.now().isAfter(endTime);

      if (!validCode) {
        throw Exception('Invalid attendance code.');
      }
      if (isExpired) {
        throw Exception('Attendance session has expired.');
      }

      // 2. Check if the student has already submitted attendance for this session
      final existingRecord = await FirebaseFirestore.instance
          .collection('attendance_records')
          .where('sessionId', isEqualTo: widget.sessionId)
          .where('studentId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existingRecord.docs.isNotEmpty) {
        throw Exception('You have already marked attendance for this session.');
      }

      // 3. Record attendance
      await FirebaseFirestore.instance.collection('attendance_records').add({
        'sessionId': widget.sessionId,
        'studentId': user.uid,
        'timestamp': Timestamp.now(),
        // Additional field for future reporting
        'courseId': sessionData['courseId'], 
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance marked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
        title: const Text('Mark Attendance'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Enter the 4-digit attendance code provided by the instructor.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 5),
                decoration: InputDecoration(
                  labelText: 'Attendance Code',
                  hintText: 'e.g., 1234',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  counterText: "", // Hide the default counter
                ),
                validator: (value) {
                  if (value == null || value.length != 4) {
                    return 'Code must be exactly 4 digits.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitCode,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_isLoading ? 'Submitting...' : 'Submit Attendance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}