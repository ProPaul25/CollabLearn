import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collablearn1/main.dart'; // Import main.dart to access LoginPage class
import 'package:collablearn1/landing_page.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const SplashPage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInCubic,
    );

    _controller.forward();

    // After the splash screen delay, navigate to the correct page
    Timer(const Duration(seconds: 3), () {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // User is logged in, navigate to the LandingPage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => LandingPage(
              onToggleTheme: widget.onToggleTheme,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
      } else {
        // User is not logged in, navigate to the LoginPage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => LoginPage(
              onToggleTheme: widget.onToggleTheme,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const String backgroundImage = 'assets/background.jpg';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage(backgroundImage),
            fit: BoxFit.cover,
            colorFilter: isDark
                ? ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken)
                : null,
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _animation,
            child: FadeTransition(
              opacity: _animation,
              child: Image.asset(
                'assets/logo.png',
                height: 200,
              ),
            ),
          ),
        ),
      ),
    );
  }
}