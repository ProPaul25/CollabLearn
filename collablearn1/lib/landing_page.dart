// lib/landing_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:collablearn1/edit_profile_page.dart';
import 'package:collablearn1/join_class_page.dart';
import 'package:collablearn1/create_class_page.dart'; 
import 'package:collablearn1/course_dashboard_page.dart';
import 'package:collablearn1/user_progress_tracker_page.dart'; 
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
  
  // --- STATE VARIABLES for Classes ---
  List<Map<String, dynamic>> _enrolledClasses = [];
  bool _isClassesLoading = true;
  // -------------------------

  @override
  void initState() {
    super.initState();
    // Data loading is handled in didChangeDependencies for reliable refresh
  }

  // --- FIX: Force reload whenever the widget comes into focus ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData(); 
  }
  // -----------------------------------------------------------------

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // We need to re-fetch the user data in case it was updated
      await user.reload(); 
      final refreshedUser = FirebaseAuth.instance.currentUser;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(refreshedUser!.uid).get();
      
      // Initialize an empty list of IDs
      List<dynamic> classIds = []; 

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && mounted) {
          setState(() {
            _userName = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}";
            _userEmail = refreshedUser.email ?? data['email'] ?? ''; 
            _userRole = data['role'] ?? 'student';

            String? imageBase64 = data['profileImageBase64'];
            if (imageBase64 != null && imageBase64.isNotEmpty) {
              _profileImageBytes = base64Decode(imageBase64);
            } else {
              _profileImageBytes = null;
            }
          });
          
          // Safely extract the enrolledClasses array
          if (data.containsKey('enrolledClasses') && data['enrolledClasses'] is List) {
            classIds = List<String>.from(data['enrolledClasses']);
          }
          
          _fetchEnrolledClasses(classIds); 
        }
      } else if (mounted) {
        setState(() {
          _userName = refreshedUser.displayName ?? "User";
          _userEmail = refreshedUser.email ?? "";
          _userRole = "student";
          _profileImageBytes = null;
        });
        _fetchEnrolledClasses([]);
      }
    }
  }

  // --- METHOD TO FETCH CLASSES ---
  Future<void> _fetchEnrolledClasses(List<dynamic> classIds) async {
    if (classIds.isEmpty) {
      if (mounted) setState(() {
        _enrolledClasses = [];
        _isClassesLoading = false;
      });
      return;
    }

    try {
      // Set loading state before query
      if (mounted) setState(() => _isClassesLoading = true); 

      // Fetch class details for all IDs using an 'whereIn' query
      // Note: Sublisting the list ensures we respect the 10-item limit of Firestore's whereIn operator.
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where(FieldPath.documentId, whereIn: classIds.sublist(0, classIds.length > 10 ? 10 : classIds.length))
          .get();

      final classes = classesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['classId'] = doc.id; // Add the document ID for navigation
        return data;
      }).toList();

      if (mounted) {
        setState(() {
          _enrolledClasses = classes;
        });
      }
    } catch (e) {
      debugPrint('Error fetching enrolled classes: $e');
      // If the query fails, ensure UI still updates
      if (mounted) setState(() => _enrolledClasses = []); 
    } finally {
      if (mounted) setState(() => _isClassesLoading = false);
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
    // Instructor Menu
    if (_userRole == 'instructor') {
      return [
        ListTile(leading: const Icon(Icons.class_outlined), title: const Text('My Classes'), onTap: () => Navigator.pop(context)),
        ListTile(leading: const Icon(Icons.add_box_outlined), title: const Text('Create Class'), onTap: () {
          Navigator.pop(context); 
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateClassPage())); 
        }),
        ListTile(leading: const Icon(Icons.people_alt_outlined), title: const Text('Student Management'), onTap: () => Navigator.pop(context)),
      ];
    } else { // Student Menu
      return [
        ListTile(leading: const Icon(Icons.class_outlined), title: const Text('My Classes'), onTap: () => Navigator.pop(context)),
        ListTile(leading: const Icon(Icons.person_add_alt_1_outlined), title: const Text('Join Class'), onTap: () {
          Navigator.pop(context); 
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
        elevation: 1, 
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _buildDrawerHeader(),
            ..._buildMenuItems(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.show_chart), 
              title: const Text('Performance Report'),
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserProgressTrackerPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfilePage()),
                ).then((_) {
                  // We keep this .then() call to ensure profile data is reloaded immediately after profile edit
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
              // --- Display Classes or No Classes View ---
              child: _buildClassesView(),
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
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 20, 
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


  // --- NEW METHOD: Conditional View for Classes ---
  Widget _buildClassesView() {
    if (_isClassesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_enrolledClasses.isEmpty) {
      return _buildNoClassesView();
    }

    // Display the list of enrolled classes
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
          child: Text(
            _userRole == 'instructor' ? "My Classes" : "Enrolled Classes",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _enrolledClasses.length,
            itemBuilder: (context, index) {
              final classData = _enrolledClasses[index];
              return _buildClassListItem(context, classData);
            },
          ),
        ),
      ],
    );
  }

  // --- NEW METHOD: Class List Item ---
  Widget _buildClassListItem(BuildContext context, Map<String, dynamic> classData) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(Icons.class_, color: Theme.of(context).colorScheme.primary),
        title: Text(
          classData['className'] ?? 'Unnamed Class',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Code: ${classData['classCode'] ?? 'N/A'}'),
        trailing: _userRole == 'instructor'
            ? const Icon(Icons.chevron_right)
            : const Icon(Icons.group_add, color: Colors.green),
        onTap: () {
          // Navigate to the specific class dashboard page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseDashboardPage(
                classId: classData['classId'],
                className: classData['className'],
                classCode: classData['classCode'],
              ),
            ),
          ); 
        },
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
          height: 100,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildCreateClassButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
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