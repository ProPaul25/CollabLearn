// lib/splash_page.dart

import 'package:flutter/material.dart';
import 'dart:async'; // Import the async library for Timer
import 'package:collablearn1/main.dart'; // Import main.dart to access AuthGate

class SplashPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const SplashPage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500), // How long the logo fade takes
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // The 2-second timer remains the same
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        // --- THIS IS THE MODIFIED SECTION FOR SMOOTH TRANSITION ---
        Navigator.of(context).pushReplacement(
          // Replace MaterialPageRoute with PageRouteBuilder
          PageRouteBuilder(
            // The page we are navigating to
            pageBuilder: (context, animation, secondaryAnimation) => AuthGate(
              onToggleTheme: widget.onToggleTheme,
              isDarkMode: widget.isDarkMode,
            ),
            // The animation for the transition itself
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Use a FadeTransition for a smooth cross-fade effect
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            // Set the duration of the transition
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
        // --- END OF MODIFIED SECTION ---
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
          child: FadeTransition(
            opacity: _animation,
            child: Image.asset(
              'assets/logo.png',
              height: 200,
            ),
          ),
        ),
      ),
    );
  }
}