// lib/edit_profile_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
// REMOVE: We no longer need firebase_storage
// import 'package:firebase_storage/firebase_storage.dart'; 
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:convert'; // ADD: Required for Base64 encoding

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
  String _userEmail = 'Loading...';

  // We only need to store the image as bytes now
  Uint8List? _pickedImageBytes;
  String? _existingImageBase64; // To hold the image string from Firestore

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
          _userEmail = data['email'] ?? '';
          // Load the Base64 string from Firestore
          _existingImageBase64 = data['profileImageBase64']; 
        });
      } else if (mounted) {
        setState(() {
          _userEmail = user.email ?? '';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50); // Reduced quality for smaller string

    if (pickedImage != null && mounted) {
      // Read the image as bytes regardless of platform
      final imageBytes = await pickedImage.readAsBytes();
      setState(() {
        _pickedImageBytes = imageBytes;
      });
    }
  }

  // THIS IS THE NEW, CORRECTED SAVE FUNCTION
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not found. Please log in again.");
      }

      // Prepare the data to be saved in Firestore
      Map<String, dynamic> dataToUpdate = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'entryNo': _entryNoController.text.trim(),
        'email': _userEmail,
      };

      // If a new image was picked, convert it to a Base64 string and add it to our data map.
      if (_pickedImageBytes != null) {
        String base64Image = base64Encode(_pickedImageBytes!);
        dataToUpdate['profileImageBase64'] = base64Image;
      }

      // Save the final map to Firestore.
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
            content: Text('Failed to update profile: $e'),
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
                    _buildReadOnlyField(
                      labelText: 'Email Address',
                      value: _userEmail,
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

  // Helper methods are unchanged
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        filled: true,
        fillColor: isDark ? const Color(0xFF2A314D) : const Color(0xFFF0F0F0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field cannot be empty';
        }
        return null;
      },
    );
  }

  Widget _buildReadOnlyField({required String labelText, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey[200],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ],
    );
  }
}