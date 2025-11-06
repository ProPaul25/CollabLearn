// lib/edit_profile_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _entryNoController = TextEditingController();
  // NEW: Controller for the editable email field
  final _emailController = TextEditingController(); 

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordSectionVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmNewPasswordVisible = false;

  Uint8List? _pickedImageBytes;
  String? _existingImageBase64;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _entryNoController.dispose();
    _emailController.dispose(); // NEW: Dispose email controller
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        setState(() {
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _entryNoController.text = data['entryNo'] ?? '';
          _emailController.text = data['email'] ?? user.email ?? ''; // NEW: Populate email controller
          _existingImageBase64 = data['profileImageBase64'];
        });
      } else if (mounted) {
        setState(() {
          _emailController.text = user.email ?? '';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedImage != null && mounted) {
      final imageBytes = await pickedImage.readAsBytes();
      setState(() {
        _pickedImageBytes = imageBytes;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    String originalEmail = '';

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not found. Please log in again.");
      }
      originalEmail = user.email ?? '';

      // --- NEW: EMAIL UPDATE LOGIC ---
      final newEmail = _emailController.text.trim();
      bool emailChanged = newEmail != originalEmail;
      if (emailChanged) {
        try {
          // This sends a verification link to the new email.
          await user.verifyBeforeUpdateEmail(newEmail);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Verification link sent to new email. Please verify to complete the change.'),
                backgroundColor: Colors.blue,
              ),
            );
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            throw Exception('This operation is sensitive and requires recent authentication. Please log out and log back in to change your email.');
          } else if (e.code == 'email-already-in-use') {
            throw Exception('This email is already in use by another account.');
          }
          throw Exception('Failed to update email: ${e.message}');
        }
      }

      if (_isPasswordSectionVisible && _newPasswordController.text.isNotEmpty) {
        try {
          await user.updatePassword(_newPasswordController.text.trim());
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            throw Exception('This operation is sensitive and requires recent authentication. Please log out and log back in to change your password.');
          }
          throw Exception('Failed to update password: ${e.message}');
        }
      }

      Map<String, dynamic> dataToUpdate = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'entryNo': _entryNoController.text.trim(),
        'email': newEmail, // Save the new email to Firestore
      };

      if (_pickedImageBytes != null) {
        String base64Image = base64Encode(_pickedImageBytes!);
        dataToUpdate['profileImageBase64'] = base64Image;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        dataToUpdate,
        SetOptions(merge: true),
      );

      final newDisplayName = "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";
      if (user.displayName != newDisplayName) {
        await user.updateDisplayName(newDisplayName);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ImageProvider? profileImage;
    if (_pickedImageBytes != null) {
      profileImage = MemoryImage(_pickedImageBytes!);
    } else if (_existingImageBase64 != null) {
      profileImage = MemoryImage(base64Decode(_existingImageBase64!));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
              child: Container(
                padding: const EdgeInsets.all(25.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C2239) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Your Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: profileImage,
                        child: profileImage == null
                            ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                            : null,
                      ),
                    ),
                    TextButton(
                      onPressed: _pickImage,
                      child: Text(
                        profileImage == null
                            ? 'Add Profile Picture'
                            : 'Change Profile Picture',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildTextField(
                      controller: _firstNameController,
                      labelText: 'First Name',
                      hintText: 'Enter your first name',
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _lastNameController,
                      labelText: 'Last Name',
                      hintText: 'Enter your last name',
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _entryNoController,
                      labelText: 'Entry No',
                      hintText: 'Enter your entry number',
                    ),
                    const SizedBox(height: 20),

                    // --- NEW: Editable Email Field ---
                    _buildTextField(
                      controller: _emailController,
                      labelText: 'Email Address',
                      hintText: 'Enter your email address',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email cannot be empty';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isPasswordSectionVisible = !_isPasswordSectionVisible;
                        });
                      },
                      child: Text(
                        _isPasswordSectionVisible ? 'Cancel Password Change' : 'Change Password',
                        style: TextStyle(color: _isPasswordSectionVisible ? Colors.red : Theme.of(context).colorScheme.primary),
                      ),
                    ),

                    if (_isPasswordSectionVisible)
                      Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: _newPasswordController,
                            labelText: 'New Password',
                            hintText: 'Enter new password',
                            isPassword: true,
                            isPasswordVisible: _isNewPasswordVisible,
                            onVisibilityToggle: () {
                              setState(() {
                                _isNewPasswordVisible = !_isNewPasswordVisible;
                              });
                            },
                            validator: (value) {
                              if (value != null && value.isNotEmpty && value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            labelText: 'Confirm New Password',
                            hintText: 'Re-enter new password',
                            isPassword: true,
                            isPasswordVisible: _isConfirmNewPasswordVisible,
                            onVisibilityToggle: () {
                              setState(() {
                                _isConfirmNewPasswordVisible = !_isConfirmNewPasswordVisible;
                              });
                            },
                            validator: (value) {
                              if (_newPasswordController.text.isNotEmpty && value != _newPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onVisibilityToggle,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword && !isPasswordVisible,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        filled: true,
        fillColor: isDark ? const Color(0xFF2A314D) : const Color(0xFFF0F0F0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: onVisibilityToggle,
              )
            : null,
      ),
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return 'This field cannot be empty';
        }
        return null;
      },
    );
  }
}