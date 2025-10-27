// lib/start_attendance_session_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart'; // NEW: Import for QR code generation

class StartAttendanceSessionPage extends StatefulWidget {
  final String classId;

  const StartAttendanceSessionPage({super.key, required this.classId});

  @override
  State<StartAttendanceSessionPage> createState() =>
      _StartAttendanceSessionPageState();
}

class _StartAttendanceSessionPageState extends State<StartAttendanceSessionPage> {
  // Use the session ID directly as the payload for the QR code
  String _sessionId = ''; 
  int _timerSeconds = 5 * 60; // 5 minutes
  Timer? _timer;
  bool _isSessionActive = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startSession() async {
    if (_isSessionActive) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }
      
      final startTime = DateTime.now();
      final endTime = startTime.add(Duration(seconds: _timerSeconds));
      
      // 1. Create a document reference first to get the ID
      final sessionRef = FirebaseFirestore.instance.collection('attendance_sessions').doc();
      final newSessionId = sessionRef.id;


      // 2. Create the attendance session document, storing the ID as a field (optional, but good for data)
      await sessionRef.set({
        'courseId': widget.classId,
        'instructorId': user.uid,
        'sessionCode': newSessionId.substring(0, 4), // Keeping a dummy code for legacy/display purposes if needed, but QR uses ID
        'sessionId': newSessionId, // Store the ID explicitly
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'durationMinutes': 5,
      });

      // 3. Start the countdown timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _timerSeconds--;
            if (_timerSeconds <= 0) {
              _timer?.cancel();
              _isSessionActive = false;
            }
          });
        }
      });

      if (mounted) {
        setState(() {
          _sessionId = newSessionId;
          _isSessionActive = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Attendance'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isSessionActive)
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _startSession,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.qr_code_2),
                  label: Text(_isLoading ? 'Starting...' : 'START 5-MIN QR SESSION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              
              if (_isSessionActive) ...[
                Text(
                  'SCAN FOR ATTENDANCE',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                ),
                const SizedBox(height: 30),
                // --- NEW: QR CODE DISPLAY ---
                QrImageView(
                  data: _sessionId, // The QR code contains the session ID
                  version: QrVersions.auto,
                  size: 250.0,
                  foregroundColor: primaryColor,
                  errorStateBuilder: (cxt, err) {
                    return const Center(
                      child: Text('QR Code Failed to Load.'),
                    );
                  },
                ),
                // --- END QR CODE DISPLAY ---
                const SizedBox(height: 30),
                Text(
                  'Time Remaining:',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                Text(
                  _formatDuration(_timerSeconds),
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Students must scan this code now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
