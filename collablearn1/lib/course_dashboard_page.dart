// lib/course_dashboard_page.dart

import 'package:flutter/material.dart';

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

  // Placeholder pages based on your Figma design (Page 10, 11)
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    // Initialize the list of pages here
    _widgetOptions = <Widget>[
      // 0: Stream (The main feed)
      const Center(child: Text('Stream Page (Active Task/Feed)', style: TextStyle(fontSize: 30))),
      // 1: Classworks
      const Center(child: Text('Classworks Page (Assignments/Quizzes)', style: TextStyle(fontSize: 30))),
      // 2: People
      const Center(child: Text('People Page (Students/Instructor List)', style: TextStyle(fontSize: 30))),
      // 3: Attendance
      const Center(child: Text('Attendance Page (QR/Manual System)', style: TextStyle(fontSize: 30))),
      // 4: Discussion (Doubt Polls)
      const Center(child: Text('Discussion/Polls Page', style: TextStyle(fontSize: 30))),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // You can customize the color based on the selected theme later
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      // Display the content of the selected tab
      body: _widgetOptions.elementAt(_selectedIndex), 
      
      // Implement the Bottom Navigation Bar based on Figma (Page 10, 11)
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