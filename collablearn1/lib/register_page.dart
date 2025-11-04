// lib/register_page.dart - UPDATED with Email Domain Restriction

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { instructor, student }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // --- DOMAIN RESTRICTION ---
  static const String _ALLOWED_DOMAIN = '@iitrpr.ac.in';
  // --------------------------
  
  final _formKey = GlobalKey<FormState>();
  UserRole? _selectedRole = UserRole.student;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _entryNoController = TextEditingController();
  final _instructorIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _entryNoController.dispose();
    _instructorIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    
    final email = _emailController.text.trim();
    
    // --- FINAL DOMAIN CHECK (Defense in Depth) ---
    if (!email.endsWith(_ALLOWED_DOMAIN)) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Registration restricted to @iitrpr.ac.in domain.'), backgroundColor: Colors.red),
            );
        }
        setState(() => _isLoading = false);
        return;
    }
    // ---------------------------------------------

    try {
      // 1. Authenticate user with Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception("User creation failed.");
      }

      String userIdentifier = '';
      Map<String, dynamic> userData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'role': _selectedRole.toString().split('.').last, // 'student' or 'instructor'
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'enrolledClasses': [], // Initialize enrolled classes array
        'profileImageBase64': null, // Initialize profile image
      };

      // 2. Set user-specific identifier (Entry No or Instructor ID)
      if (_selectedRole == UserRole.student) {
        userIdentifier = _entryNoController.text.trim();
        userData['entryNo'] = userIdentifier;
        userData['instructorId'] = '';
      } else {
        userIdentifier = _instructorIdController.text.trim();
        userData['instructorId'] = userIdentifier;
        userData['entryNo'] = '';
      }

      // 3. Perform batch write for user profile and lookup document
      final batch = FirebaseFirestore.instance.batch();
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.set(userDocRef, userData);

      // Create a lookup document for username/ID login functionality
      if (userIdentifier.isNotEmpty) {
        final lookupDocRef = FirebaseFirestore.instance.collection('user_lookups').doc(userIdentifier);
        // The lookup doc links the identifier (e.g., Entry No) to the user's email and UID.
        batch.set(lookupDocRef, {
          'uid': user.uid, 
          'email': email
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration Successful!'), backgroundColor: Colors.green),
        );
        // Navigate back to the LoginPage
        Navigator.pop(context); 
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak (min 6 characters).';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
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
            colorFilter: isDark ? ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken) : null,
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
                            Expanded(child: _buildTextField(controller: _firstNameController, labelText: 'First Name', hintText: 'First')),
                            const SizedBox(width: 15),
                            Expanded(child: _buildTextField(controller: _lastNameController, labelText: 'Last Name', hintText: 'Last')),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _emailController, 
                          labelText: 'Email Address', 
                          hintText: 'Email', 
                          keyboardType: TextInputType.emailAddress, 
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Email is required';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Enter a valid email';
                            
                            // --- DOMAIN CHECK IN VALIDATOR ---
                            if (!value.endsWith(_ALLOWED_DOMAIN)) {
                              return 'Must use an $_ALLOWED_DOMAIN email address.';
                            }
                            // ---------------------------------
                            return null;
                          }
                        ),
                        const SizedBox(height: 20),
                        if (_selectedRole == UserRole.student)
                          _buildTextField(controller: _entryNoController, labelText: 'Entry No', hintText: 'e.g., 2025CSM1016')
                        else
                          _buildTextField(controller: _instructorIdController, labelText: 'Instructor ID', hintText: 'Your unique Instructor ID'),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _passwordController,
                          labelText: 'Password',
                          hintText: 'Password',
                          obscureText: !_isPasswordVisible,
                          suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          labelText: 'Confirm Password',
                          hintText: 'Confirm',
                          obscureText: !_isConfirmPasswordVisible,
                          suffixIcon: IconButton(icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible)),
                          validator: (value) {
                            if (value != _passwordController.text) return 'Passwords do not match';
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
                            child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Text('Sign Up', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account? ', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                            GestureDetector(onTap: () => Navigator.pop(context), child: const Text('Sign In', style: TextStyle(color: Color(0xFF8A2BE2), fontWeight: FontWeight.bold))),
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
              Expanded(child: RadioListTile<UserRole>(title: const Text('Instructor'), value: UserRole.instructor, groupValue: _selectedRole, onChanged: (v) => setState(() => _selectedRole = v), activeColor: const Color(0xFF8A2BE2), dense: true)),
              Expanded(child: RadioListTile<UserRole>(title: const Text('Student'), value: UserRole.student, groupValue: _selectedRole, onChanged: (v) => setState(() => _selectedRole = v), activeColor: const Color(0xFF8A2BE2), dense: true)),
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
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) return 'This field is required';
        if (labelText == 'Password' && value.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }
}