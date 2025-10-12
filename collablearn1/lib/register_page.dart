import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Import Google Sign-In

enum UserRole { instructor, student }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  UserRole? _selectedRole = UserRole.student;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _entryNoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _entryNoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // New method for Google Sign-in on the register page
  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        setState(() => _isLoading = false);
        return;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credentials
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Save additional user data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'firstName': googleUser.displayName?.split(' ').first ?? '',
        'lastName': googleUser.displayName?.split(' ').last ?? '',
        'entryNo': '', // Default empty for Google sign-ups
        'role': 'student', // Default to student for Google sign-ups
        'email': googleUser.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint("Google user signed up with UID: ${userCredential.user?.uid}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration with Google Successful!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to the login screen
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error with Google Sign-up. $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _onSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      // 1. Create user with Firebase Authentication
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Save additional user data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'entryNo': _entryNoController.text.trim(),
        'role': _selectedRole.toString().split('.').last, // Save as a string
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint("User created with UID: ${userCredential.user?.uid}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration Successful!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to the login screen
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else {
        message = 'An error occurred. Please try again.';
      }
      debugPrint("Firebase Auth Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Error during registration: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Could not save data. $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const String backgroundImage = 'assets/background.jpg';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.grey[850],
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),
                  Image.asset('assets/logo.png', height: 80),
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C2239) : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add, size: 30, color: Color(0xFF8A2BE2)),
                            SizedBox(width: 10),
                            Text('Register', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _firstNameController,
                                labelText: 'First Name',
                                hintText: 'First',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your first name';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: _buildTextField(
                                controller: _lastNameController,
                                labelText: 'Last Name',
                                hintText: 'Last',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your last name';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _emailController,
                          labelText: 'Email Address',
                          hintText: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _entryNoController,
                          labelText: 'Entry no',
                          hintText: 'Entry No',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your entry number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _passwordController,
                          labelText: 'Password',
                          hintText: 'Password',
                          obscureText: !_isPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          labelText: 'Confirm Password',
                          hintText: 'Confirm',
                          obscureText: !_isConfirmPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildRoleSelector(),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _onSignUp,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              backgroundColor: const Color(0xFF8A2BE2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                : const Text('Sign Up', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('or sign up with', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUpWithGoogle,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: const BorderSide(color: Colors.grey),
                              ),
                            ),
                            child: _isLoading
                                ? const Center(child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                  ))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset('assets/google.png', height: 24.0),
                                      const SizedBox(width: 8.0),
                                      const Text(
                                        'Sign up with Google',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account? ', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Sign In', style: TextStyle(color: Color(0xFF8A2BE2), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods
  Widget _buildRoleSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(15),
        color: isDark ? const Color(0xFF2A314D) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0, top: 8.0),
            child: Text('Role', style: TextStyle(color: Colors.black54, fontSize: 12)),
          ),
          Row(
            children: [
              Expanded(
                child: RadioListTile<UserRole>(
                  title: const Text('Instructor'),
                  value: UserRole.instructor,
                  groupValue: _selectedRole,
                  onChanged: (UserRole? value) {
                    setState(() => _selectedRole = value);
                  },
                  activeColor: const Color(0xFF8A2BE2),
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<UserRole>(
                  title: const Text('Student'),
                  value: UserRole.student,
                  groupValue: _selectedRole,
                  onChanged: (UserRole? value) {
                    setState(() => _selectedRole = value);
                  },
                  activeColor: const Color(0xFF8A2BE2),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade400)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF8A2BE2), width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF2A314D) : Colors.white,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
      ),
      validator: validator,
    );
  }
}