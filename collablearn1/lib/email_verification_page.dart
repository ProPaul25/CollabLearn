// lib/email_verification_page.dart - NEW FILE

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'main.dart'; // Import main.dart for AuthGate

class EmailVerificationPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const EmailVerificationPage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _auth = FirebaseAuth.instance;
  User? _user;
  Timer? _timer;
  bool _canResend = true;
  int _resendCooldown = 60; // Seconds

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    if (_user != null) {
      // Send the verification email immediately if it wasn't sent, or if the user landed here
      _sendVerificationEmail(); 
      // Start the timer to periodically check verification status
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  // Checks if the user's email has been verified and navigates if true.
  Future<void> _checkEmailVerified() async {
    // 1. Reload user data from Firebase to get the latest status
    await _user?.reload();
    final user = _auth.currentUser;

    if (user != null && user.emailVerified) {
      _timer?.cancel(); // Stop the timer

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified! Redirecting...'), backgroundColor: Colors.green),
        );
        // Navigate back through the AuthGate, which will now route to LandingPage
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => AuthGate( 
              onToggleTheme: widget.onToggleTheme, 
              isDarkMode: widget.isDarkMode
            ),
          ), 
          (route) => false, // Clear the stack
        );
      }
    }
  }

  // Resends the verification email and starts a cooldown timer
  Future<void> _sendVerificationEmail() async {
    if (!_canResend || _user == null) return;

    setState(() => _canResend = false);

    try {
      // Check if email is already verified before trying to resend
      await _user!.reload();
      if (_user!.emailVerified) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Email is already verified!'), backgroundColor: Colors.green),
           );
         }
         return;
      }
      
      await _user!.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification link resent!'), backgroundColor: Colors.blue),
        );
      }
      // Start the cooldown timer
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _resendCooldown--;
          });
          if (_resendCooldown <= 0) {
            timer.cancel();
            setState(() {
              _canResend = true;
              _resendCooldown = 60;
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend email: $e'), backgroundColor: Colors.red),
        );
      }
      // Reset resend capability if it failed instantly
      setState(() {
        _canResend = true;
        _resendCooldown = 60;
      });
    }
  }

  // Navigates the user back to the login page (e.g., if they want to try logging in or are giving up)
  void _backToLogin() {
    _timer?.cancel();
    // We navigate directly to the LoginPage from the current context
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Prevents back button
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_unread, size: 100, color: primaryColor),
              const SizedBox(height: 30),
              const Text(
                'A verification link has been sent to your email.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Please click the link in the email sent to ${_user?.email ?? 'your address'} to activate your account.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _canResend ? _sendVerificationEmail : null,
                  icon: const Icon(Icons.refresh),
                  label: Text(_canResend ? 'Resend Verification Email' : 'Resend in ${_resendCooldown}s'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _backToLogin,
                child: const Text('Back to Login'),
              ),
              const SizedBox(height: 40),
              const Text(
                'Note: You must verify your email to complete registration and access the app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}