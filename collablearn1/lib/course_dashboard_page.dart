// lib/course_dashboard_page.dart

import 'package:flutter/material.dart';
import 'doubt_polls_view_page.dart';

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

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      // 0: Stream (Already implemented with stream_page.dart)
      // 0: Stream (Uses the dedicated StreamTab widget)
        StreamTab(
          className: widget.className,
          classCode: widget.classCode,
        ),
      // 1: Classworks
      const Center(child: Text('Classworks Page (Assignments/Quizzes)', style: TextStyle(fontSize: 30))),
      // 2: People
      const Center(child: Text('People Page (Students/Instructor List)', style: TextStyle(fontSize: 30))),
      // 3: Attendance
      const Center(child: Text('Attendance Page (QR/Manual System)', style: TextStyle(fontSize: 30))),
      // 4: Discussion (Doubt Polls) - NOW USING THE REAL PAGE
      DoubtPollsViewPage(classId: widget.classId), 
    ];
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
      
      // Display the content of the selected tab
      body: _widgetOptions.elementAt(_selectedIndex), 
      
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
// 1. DEDICATED STREAM TAB WIDGET
// -------------------------------------------------------------------

class StreamTab extends StatelessWidget {
  final String className;
  final String classCode;

  // IMPORTANT: Removed the 'const' constructor here to be safe, 
  // though the original implementation should have worked.
  const StreamTab({
    super.key,
    required this.className,
    required this.classCode,
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
          // 1. Class Info Card (Code Display)
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
                // Correctly displaying the classCode property
                SelectableText(
                  classCode, 
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
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
          const SizedBox(height: 25),

          // 2. Announcement/Post Input Area
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
              onTap: () {
                // TODO: Implement functionality to create a new post/announcement
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Open New Announcement Composer')),
                );
              },
            ),
          ),
          const SizedBox(height: 25),

          // 3. Upcoming Events/Assignments Section (Simple List)
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
          _buildUpcomingItem(context, 'Live Lecture: Today @ 4 PM', Icons.live_tv, Colors.green),
          
          const SizedBox(height: 25),

          // 4. Recent Posts/Activity Feed (Placeholders)
          Text(
            'Recent Posts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          _buildActivityPost(context, 'Instructor posted a new link.', 'A quick reference to the external resources.'),
          _buildActivityPost(context, 'Student submitted a question.', 'When is the deadline for the final project?'),
          _buildActivityPost(context, 'System: New Assignment added.', 'Assignment 2: Introduction to Flutter.'),
        ],
      ),
    );
  }

  Widget _buildUpcomingItem(BuildContext context, String title, IconData icon, Color color) {
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

  Widget _buildActivityPost(BuildContext context, String title, String body) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2237) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '5 minutes ago',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 2. SIMPLIFIED PLACEHOLDER WIDGET
// -------------------------------------------------------------------

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderPage({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 10),
          Text(
            '$title Tab',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Content for this tab will go here.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}