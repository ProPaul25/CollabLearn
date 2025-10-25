// lib/start_attendance_session_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:async';

class StartAttendanceSessionPage extends StatefulWidget {
  final String classId;

  const StartAttendanceSessionPage({super.key, required this.classId});

  @override
  State<StartAttendanceSessionPage> createState() =>
      _StartAttendanceSessionPageState();
}

class _StartAttendanceSessionPageState extends State<StartAttendanceSessionPage> {
  String _sessionCode = '';
  int _timerSeconds = 5 * 60; // 5 minutes
  Timer? _timer;
  bool _isSessionActive = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _generateAttendanceCode() {
    const chars = '0123456789';
    Random random = Random();
    String code = '';
    for (int i = 0; i < 4; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    return code;
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
      
      final code = _generateAttendanceCode();
      final startTime = DateTime.now();
      final endTime = startTime.add(Duration(seconds: _timerSeconds));

      // 1. Create the attendance session document
      await FirebaseFirestore.instance.collection('attendance_sessions').add({
        'courseId': widget.classId,
        'instructorId': user.uid,
        'sessionCode': code,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'durationMinutes': 5,
      });

      // 2. Start the countdown timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _timerSeconds--;
            if (_timerSeconds <= 0) {
              _timer?.cancel();
              _isSessionActive = false;
              // Optionally update Firestore session to mark as 'expired' if needed
            }
          });
        }
      });

      if (mounted) {
        setState(() {
          _sessionCode = code;
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

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
                      : const Icon(Icons.start),
                  label: Text(_isLoading ? 'Starting...' : 'START 5-MIN SESSION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              
              if (_isSessionActive) ...[
                Text(
                  'ACTIVE SESSION CODE',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Text(
                      _sessionCode,
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        letterSpacing: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
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
                  'Students must submit this code now.',
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