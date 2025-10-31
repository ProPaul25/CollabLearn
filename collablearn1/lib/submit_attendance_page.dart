// lib/submit_attendance_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; 
// REMOVED: import 'package:flutter/foundation.dart'; (Was unnecessary and causing spurious errors)

class SubmitAttendancePage extends StatefulWidget {
  const SubmitAttendancePage({
    super.key,
    required String sessionCode, 
    required String sessionId, 
  });

  @override
  State<SubmitAttendancePage> createState() => _SubmitAttendancePageState();
}

class _SubmitAttendancePageState extends State<SubmitAttendancePage> {
  bool _isProcessing = false;
  // Initialize MobileScannerController
  MobileScannerController cameraController = MobileScannerController();
  bool _scanCompleted = false; 

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }
  
  // --- Core Submission Logic (Unchanged) ---
  Future<void> _submitAttendance(String sessionId) async {
    if (_isProcessing || _scanCompleted) return;

    setState(() {
      _isProcessing = true;
      _scanCompleted = true; 
    });
    
    try {
      await cameraController.stop();
    } catch (e) {
      // Ignore error
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnackbar('User not logged in. Please log in again.', Colors.red);
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    try {
      final sessionDoc = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Invalid or expired QR code/Session not found.');
      }

      final sessionData = sessionDoc.data()!;
      final endTime = (sessionData['endTime'] as Timestamp).toDate();
      final isExpired = DateTime.now().isAfter(endTime);

      if (isExpired) {
        throw Exception('Attendance session has expired.');
      }

      final existingRecord = await FirebaseFirestore.instance
          .collection('attendance_records')
          .where('sessionId', isEqualTo: sessionId)
          .where('studentId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existingRecord.docs.isNotEmpty) {
        throw Exception('You have already marked attendance for this session.');
      }

      await FirebaseFirestore.instance.collection('attendance_records').add({
        'sessionId': sessionId,
        'studentId': user.uid,
        'timestamp': Timestamp.now(),
        'courseId': sessionData['courseId'], 
      });

      _showSnackbar('Attendance marked successfully via QR code!', Colors.green);
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _showSnackbar('Submission failed: ${e.toString().replaceFirst("Exception: ", "")}', Colors.red);
      _scanCompleted = false; 
      cameraController.start(); 
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
  
  // Helper widget for overlay text (retains context)
  Widget _buildOverlayText(Color primaryColor) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isProcessing ? 'Processing Submission...' : 'Position the QR code inside the box.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isProcessing ? Colors.orange : primaryColor,
              ),
            ),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 10.0),
                child: CircularProgressIndicator(),
              ),
            const SizedBox(height: 10),
            const Text(
              'Ensure the code is clear and the session is active.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Attendance QR Code'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // --- Functional Mobile Scanner ---
          MobileScanner(
              controller: cameraController, 
              onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && !_scanCompleted) {
                      final String scannedSessionId = barcodes.first.rawValue ?? '';
                      if (scannedSessionId.isNotEmpty) {
                          _submitAttendance(scannedSessionId);
                      }
                  }
              },
              // Widget shown while the camera is initializing
              placeholderBuilder: (context, child) => Center(child: CircularProgressIndicator(color: primaryColor)),
              
              // Optional: Widget to show if permission is denied/unavailable
              errorBuilder: (context, error, child) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Camera is unavailable or permission was permanently denied. Please check app settings.', 
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold)
                    ),
                  ),
                );
              }
          ),
          
          // --- Scanner Overlay UI (Visual Guide) ---
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: primaryColor, width: 5),
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          
          // --- Status and Instruction Text ---
          _buildOverlayText(primaryColor),
          
          // --- Flashlight Button ---
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 80.0, right: 20),
              child: IconButton(
                icon: ValueListenableBuilder(
                  // Now listening directly to the torchState property which is a ValueNotifier<TorchState>
                  valueListenable: cameraController.torchState,
                  builder: (context, state, child) {
                    if (state == TorchState.off) {
                      return const Icon(Icons.flash_off, color: Colors.white);
                    } else {
                      return const Icon(Icons.flash_on, color: Colors.yellow);
                    }
                  },
                ),
                onPressed: () => cameraController.toggleTorch(),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}