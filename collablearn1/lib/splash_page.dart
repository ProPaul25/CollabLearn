import 'package:flutter/material.dart';
import 'dart:async';
import 'package:collablearn1/main.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Initialize the animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Duration of the animation
    );

    // Define the animation for the logo's opacity and scale
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInCubic, // Use a curve for a smoother effect
    );

    // Start the animation
    _controller.forward();

    // Navigate to the next page after a delay
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MyApp(), // Navigate to your main app widget
        ),
      );
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
            scale: _animation, // The logo grows from a smaller size
            child: FadeTransition(
              opacity: _animation, // The logo fades in
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