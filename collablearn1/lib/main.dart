import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // You can replace this with your actual background image
    const String backgroundImage = 'assets/background.jpg';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top Logo Section
                  Image.asset(
                    'assets/logo.png', // Replace with your logo
                    height: 400,
                  ),
                  const SizedBox(height: 50),
                  // Login Card
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30.0, vertical: 40.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Login.',
                            style: TextStyle(
                                fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 30),
                          // Username/Email Field
                          _buildTextField(
                            hintText: 'Your Name or your email',
                            prefixIcon: Icons.person_outline,
                            suffixIcon: Icons.check_circle_outline,
                          ),
                          const SizedBox(height: 20),
                          // Password Field
                          _buildTextField(
                            hintText: '********',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: Icons.visibility_off,
                            obscureText: true,
                          ),
                          const SizedBox(height: 40),
                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                // Add login logic here
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF0C1D54),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: const Text('Log In'),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Sign Up Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("You don't have a account? "),
                              GestureDetector(
                                onTap: () {
                                  // Add navigation to sign up page
                                },
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0C1D54),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text('or sign in with'),
                          const SizedBox(height: 20),
                          // Social Media Icons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialIcon('assets/google.png'),
                              const SizedBox(width: 20),
                              _buildSocialIcon('assets/facebook.png'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method for text fields
  Widget _buildTextField({
    required String hintText,
    required IconData prefixIcon,
    IconData? suffixIcon,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF0C1D54)),
          suffixIcon: suffixIcon != null
              ? Icon(suffixIcon, color: const Color(0xFF0C1D54))
              : null,
          border: InputBorder.none,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF0C1D54)),
          ),
        ),
      ),
    );
  }

  // Helper method for social media icons
  Widget _buildSocialIcon(String assetPath) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
         BoxShadow(
          color: Colors.grey.withValues(alpha: 0.2),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(0, 2),
        ),
        ],
      ),
      child: Center(
        child: Image.asset(
          assetPath,
          width: 30,
          height: 30,
        ),
      ),
    );
  }
}