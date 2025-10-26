// lib/course_dashboard_page.dart - CORRECTED

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW IMPORT
import 'package:cloud_firestore/cloud_firestore.dart'; // NEW IMPORT
import 'study_materials_view_page.dart';
import 'doubt_polls_view_page.dart';
import 'people_view_page.dart';
import 'attendance_management_page.dart';
import 'stream_page.dart'; // NEW IMPORT (for real announcements)
import 'create_announcement_page.dart'; // NEW IMPORT (for navigation)

class CourseDashboardPage extends StatefulWidget {
  final String classId;
  final String className;
  final String classCode;

  const CourseDashboardPage({
    super.key,
    required this.classId,
    required this.className,
    required this.classCode,
  });

  @override
  State<CourseDashboardPage> createState() => _CourseDashboardPageState();
}

class _CourseDashboardPageState extends State<CourseDashboardPage> {
  int _selectedIndex = 0;
  
  // --- FIX 1: Add a Future to check the user's role ---
  late final Future<bool> _isInstructorFuture;

  // --- FIX 2: Helper function to check role ---
  Future<bool> _isCurrentUserInstructor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final classDoc = await FirebaseFirestore.instance.collection('classes').doc(widget.classId).get();
    final data = classDoc.data();
    if (data == null) return false;
    return data['instructorId'] == user.uid;
  }

  @override
  void initState() {
    super.initState();
    // Initialize the role-checking future
    _isInstructorFuture = _isCurrentUserInstructor();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      
      // --- FIX 3: Wrap the body in a FutureBuilder to wait for the role ---
      body: FutureBuilder<bool>(
        future: _isInstructorFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Determine role. Default to 'false' (student) if error
          final bool isInstructor = snapshot.data ?? false;

          // Define the widget options *inside* the builder
          final List<Widget> _widgetOptions = <Widget>[
            // 0: Stream
            StreamTab(
              className: widget.className,
              classCode: widget.classCode,
              classId: widget.classId,     // Pass classId
              isInstructor: isInstructor, // Pass the role down
            ),
            // 1: Classworks
            StudyMaterialsViewPage(classId: widget.classId),
            // 2: People
            PeopleViewPage(classId: widget.classId),
            // 3: Attendance
            AttendanceManagementPage(classId: widget.classId),
            // 4: Discussion (Doubt Polls)
            DoubtPollsViewPage(classId: widget.classId), 
          ];

          // Display the selected tab's content
          return _widgetOptions.elementAt(_selectedIndex);
        },
      ), 
      
      // Implement the Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.stream),
            label: 'Stream',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_outlined),
            label: 'Classworks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'People',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: 'Discussion',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, 
      ),
    );
  }
}

// -------------------------------------------------------------------
// 1. DEDICATED STREAM TAB WIDGET (NOW MODIFIED)
// -------------------------------------------------------------------

class StreamTab extends StatelessWidget {
  final String className;
  final String classCode;
  final String classId;     // <-- NEW: Added to navigate
  final bool isInstructor; // <-- NEW: Added to check role

  const StreamTab({
    super.key,
    required this.className,
    required this.classCode,
    required this.classId,     // <-- NEW
    required this.isInstructor, // <-- NEW
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          // --- FIX 4: Conditionally show the Class Info Card ---
          if (isInstructor)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    className,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Class Code:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SelectableText(
                    classCode, 
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // This text is now hidden from students
                  const Text(
                    'Share this code with students to join.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          
          // --- FIX 5: Add a gap ONLY if the card was shown ---
          if (isInstructor)
            const SizedBox(height: 25),

          // --- FIX 6: Conditionally show the "Announce" button ---
          if (isInstructor)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2237) : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: primaryColor),
                ),
                title: Text(
                  'Announce something to your class...',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                // --- FIX 7: Navigate to the correct page ---
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CreateAnnouncementPage(classId: classId),
                    ),
                  );
                },
              ),
            ),
          
          // --- FIX 8: Add a gap ONLY if the button was shown ---
          if (isInstructor)
            const SizedBox(height: 25),

          // 3. Upcoming Events/Assignments Section (Visible to everyone)
          Text(
            'Upcoming Activities',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          _buildUpcomingItem(context, 'Assignment 1: Due Tomorrow', Icons.assignment, Colors.orange),
          _buildUpcomingItem(context, 'Quiz on Chapter 3: Friday', Icons.quiz, Colors.blue),
          
          const SizedBox(height: 25),

          // 4. Recent Posts/Activity Feed
          Text(
            'Recent Posts', // This title comes from StreamTab
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          
          // --- FIX 9: Show REAL announcements, not placeholders ---
          // This embeds the real announcement list from stream_page.dart
          StreamPage(classId: classId),
        ],
      ),
    );
  }

  Widget _buildUpcomingItem(BuildContext context, String title, IconData icon, Color color) {
    // ... (This widget is unchanged)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? const Color(0xFF1C2237) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // TODO: Navigate to the specific item
        },
      ),
    );
  }
  
  // --- REMOVED _buildActivityPost as it's replaced by the real StreamPage ---
}

// --- REMOVED _PlaceholderPage as it's no longer used ---