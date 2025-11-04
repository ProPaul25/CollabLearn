// lib/create_class_page.dart - FIXED

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'course_dashboard_page.dart'; // <-- FIX: Changed to relative import

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  // ... (All logic is unchanged) ...
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();
  final _classDescriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _classNameController.dispose();
    _classDescriptionController.dispose();
    super.dispose();
  }

  String _generateClassCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    String code = '';
    for (int i = 0; i < 3; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    code += '-';
    for (int i = 0; i < 3; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    return code;
  }

  Future<void> _createClass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in.'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      final String classCode = _generateClassCode();
      final String className = _classNameController.text.trim();
      final String classDescription = _classDescriptionController.text.trim();

      final newClassRef = FirebaseFirestore.instance.collection('classes').doc(); 
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      final batch = FirebaseFirestore.instance.batch();

      batch.set(newClassRef, {
        'className': className,
        'classDescription': classDescription,
        'classCode': classCode,
        'instructorId': user.uid,
        'instructorEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'studentIds': [], 
      });

      batch.update(userDocRef, {
        'enrolledClasses': FieldValue.arrayUnion([newClassRef.id]),
      });

      await batch.commit();
      
      final newClassId = newClassRef.id;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Class "$className" created successfully! Code: $classCode'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDashboardPage(
              classId: newClassId,
              className: className,
              classCode: classCode,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create class: $e'), backgroundColor: Colors.red),
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
    // ... (Build method is unchanged) ...
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Class'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: primaryColor,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
            colorFilter: isDark
                ? ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken)
                : null,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 80.0),
            child: Form(
              key: _formKey,
              child: Card(
                color: isDark ? const Color(0xFF1C2239) : Colors.white,
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Class Details',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildTextField(
                        controller: _classNameController,
                        labelText: 'Class Name',
                        hintText: 'e.g., Computer Science I',
                        icon: Icons.title,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _classDescriptionController,
                        labelText: 'Description (Optional)',
                        hintText: 'Briefly describe the class',
                        icon: Icons.description,
                        maxLines: 3,
                        validator: (value) => null, // Optional field
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createClass,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Create Class',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    // ... (This helper method is unchanged) ...
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(fontSize: maxLines > 1 ? 16 : 18),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A314D) : const Color(0xFFF0F0F0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: maxLines > 1 ? const EdgeInsets.symmetric(vertical: 20, horizontal: 15) : null,
      ),
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter the $labelText';
        }
        return null;
      },
    );
  }
}