// lib/landing_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:collablearn1/edit_profile_page.dart';
import 'package:collablearn1/join_class_page.dart';
import 'package:collablearn1/create_class_page.dart'; // NEW IMPORT
import 'dart:convert';
import 'dart:typed_data';

class LandingPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const LandingPage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  String _userName = "User";
  String _userEmail = "";
  String _userRole = "";
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // We need to re-fetch the user data in case it was updated
      await user.reload(); 
      final refreshedUser = FirebaseAuth.instance.currentUser;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(refreshedUser!.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && mounted) {
          setState(() {
            _userName = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}";
            _userEmail = refreshedUser.email ?? data['email'] ?? ''; // Prioritize fresh email from Auth
            _userRole = data['role'] ?? 'student';

            String? imageBase64 = data['profileImageBase64'];
            if (imageBase64 != null && imageBase64.isNotEmpty) {
              _profileImageBytes = base64Decode(imageBase64);
            } else {
              _profileImageBytes = null;
            }
          });
        }
      } else if (mounted) {
        setState(() {
          _userName = refreshedUser.displayName ?? "User";
          _userEmail = refreshedUser.email ?? "";
          _userRole = "student";
          _profileImageBytes = null;
        });
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  // --- NAVIGATION DRAWER METHODS ---
  Widget _buildDrawerHeader() {
    return UserAccountsDrawerHeader(
      accountName: Text(
        _userName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      accountEmail: Text(_userEmail),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        backgroundImage: _profileImageBytes != null
            ? MemoryImage(_profileImageBytes!)
            : null,
        child: _profileImageBytes == null
            ? const Icon(Icons.person, size: 40, color: Colors.grey)
            : null,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    if (_userRole == 'instructor') {
      return [
        ListTile(leading: const Icon(Icons.class_outlined), title: const Text('My Classes'), onTap: () => Navigator.pop(context)),
        // UPDATED: Navigate to CreateClassPage
        ListTile(leading: const Icon(Icons.add_box_outlined), title: const Text('Create Class'), onTap: () {
          Navigator.pop(context); // Close the drawer
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateClassPage()));
        }),
        ListTile(leading: const Icon(Icons.people_alt_outlined), title: const Text('Student Management'), onTap: () => Navigator.pop(context)),
      ];
    } else { // Student
      return [
        ListTile(leading: const Icon(Icons.class_outlined), title: const Text('My Classes'), onTap: () => Navigator.pop(context)),
        ListTile(leading: const Icon(Icons.person_add_alt_1_outlined), title: const Text('Join Class'), onTap: () {
          Navigator.pop(context); // Close the drawer first
          Navigator.push(context, MaterialPageRoute(builder: (context) => const JoinClassPage()));
        }),
      ];
    }
  }
  // --- END OF NAVIGATION DRAWER METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HOME'),
        // AppBar is now opaque for a cleaner look
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
        elevation: 1, // Add a slight shadow
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: widget.onToggleTheme,
          ),
          Tooltip(
            message: 'Sign Out',
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.deepPurple),
              onPressed: _logout,
            ),
          ),
        ],
      ),
      // The Drawer now builds its content based on the user's role
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _buildDrawerHeader(),
            ..._buildMenuItems(),
            const Divider(),
            // CHANGE 1: Edit Profile is now a functional button in the drawer
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfilePage()),
                ).then((_) {
                  // This is called when we return from the EditProfilePage.
                  // It refreshes the user's data to show any changes.
                  _loadUserData();
                });
              },
            ),
            ListTile(
              leading: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
              title: const Text('Toggle Theme'),
              onTap: () {
                widget.onToggleTheme();
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () {
                _logout();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      // The body of the Scaffold remains the same
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/background.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(widget.isDarkMode ? 0.4 : 0.0),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: _buildProfileCard(),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40.0),
                  topRight: Radius.circular(40.0),
                ),
              ),
              child: _buildNoClassesView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFE8CFFF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.account_circle, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text(
                    'Welcome!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : null,
                    child: _profileImageBytes == null
                        ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CHANGE 2 & 3: Removed the "Edit Profile" link and adjusted text sizes
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 20, // Increased for prominence
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userEmail,
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userRole,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontStyle: FontStyle.italic
                          ),
                        ),
                        // The InkWell for "Edit Profile" has been removed from here.
                      ],
                    ),
                  ),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      'IIT Ropar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoClassesView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "You aren't in any class!",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 30),
        if (_userRole == 'instructor') _buildCreateClassButton(),
        const SizedBox(height: 20),
        _buildJoinClassButton(),
        const Spacer(),
        Image.asset(
          'assets/logo.png',
          height: 60,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildCreateClassButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.pinkAccent, Colors.purpleAccent]),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // UPDATED: Navigate to CreateClassPage
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateClassPage()));
              },
              borderRadius: BorderRadius.circular(30),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Create Class',
                    style: TextStyle(
                      color: Colors.pink,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinClassButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const JoinClassPage()));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: const Text('Join Class'),
        ),
      ),
    );
  }
}