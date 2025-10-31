// lib/course_dashboard_page.dart - FINAL VERSION

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'study_materials_view_page.dart'; 
import 'doubt_polls_view_page.dart';
import 'people_view_page.dart';
import 'attendance_management_page.dart';
// import 'stream_page.dart'; // <-- NO LONGER NEEDED
import 'create_announcement_page.dart'; 
import 'assignment_detail_page.dart'; 
import 'study_materials_view_page.dart' show AssignmentItem;
// NEW IMPORTS
import 'doubt_poll_detail_page.dart';
import 'announcement_detail_page.dart';
import 'stream_page.dart' show Announcement; // Only for Announcement model

class CourseDashboardPage extends StatefulWidget {
  // ... (Constructor is unchanged)
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
  // ... (All code here is unchanged)
  int _selectedIndex = 0;
  late final Future<bool> _isInstructorFuture;

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
      
      body: FutureBuilder<bool>(
        future: _isInstructorFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bool isInstructor = snapshot.data ?? false;

          final List<Widget> _widgetOptions = <Widget>[
            // 0: Stream
            StreamTab( // <-- This is the fully updated StreamTab
              className: widget.className,
              classCode: widget.classCode,
              classId: widget.classId,     
              isInstructor: isInstructor, 
            ),
            // 1: Classworks
            StudyMaterialsViewPage(classId: widget.classId), 
            // 2: People
            PeopleViewPage(classId: widget.classId),
            // 3: Attendance
            AttendanceManagementPage(classId: widget.classId),
            // 4: Discussion
            DoubtPollsViewPage(classId: widget.classId), 
          ];

          return _widgetOptions.elementAt(_selectedIndex);
        },
      ), 
      
      bottomNavigationBar: BottomNavigationBar(
        // ... (Unchanged)
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.stream), label: 'Stream'),
          BottomNavigationBarItem(icon: Icon(Icons.class_outlined), label: 'Classworks'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'People'),
          BottomNavigationBarItem(icon: Icon(Icons.check_box), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Discussion'),
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

// ===================================================================
// 1. DEDICATED STREAM TAB WIDGET (FULLY REBUILT)
// ===================================================================

class StreamTab extends StatelessWidget {
  final String className;
  final String classCode;
  final String classId;     
  final bool isInstructor; 

  const StreamTab({
    super.key,
    required this.className,
    required this.classCode,
    required this.classId,     
    required this.isInstructor, 
  });

  // --- FIX: Stream for Upcoming Assignments (Unchanged) ---
  Stream<List<AssignmentItem>> _getUpcomingAssignmentsStream(String courseId) {
    return FirebaseFirestore.instance
        .collection('assignments')
        .where('courseId', isEqualTo: courseId)
        .where('dueDate', isGreaterThan: Timestamp.now()) 
        .orderBy('dueDate', descending: false)
        .limit(3)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AssignmentItem.fromFirestore(doc))
          .toList();
    });
  }

  // --- NEW: Stream for the unified Class Feed ---
  Stream<List<DocumentSnapshot>> _getClassFeedStream(String courseId) {
    return FirebaseFirestore.instance
        .collection('class_feed')
        .where('courseId', isEqualTo: courseId)
        .orderBy('lastActivityTimestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  String _timeAgo(Timestamp timestamp) {
      final duration = DateTime.now().difference(timestamp.toDate());
      if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
      if (duration.inHours < 24) return '${duration.inHours}h ago';
      return '${timestamp.toDate().day}/${timestamp.toDate().month}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          // --- Class Info Card (Instructor Only) ---
          if (isInstructor)
            Container(
              // ... (Unchanged)
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(className, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text('Class Code:', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  SelectableText(classCode, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  const Text('Share this code with students to join.', style: TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            ),
          
          if (isInstructor)
            const SizedBox(height: 25),

          // --- Announce Button (Instructor Only) ---
          if (isInstructor)
            Container(
              // ... (Unchanged)
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1C2237) : Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))]),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.1), child: Icon(Icons.campaign, color: primaryColor)),
                title: Text('Announce something to your class...', style: TextStyle(color: Colors.grey.shade600)),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => CreateAnnouncementPage(classId: classId)));
                },
              ),
            ),
          
          if (isInstructor)
            const SizedBox(height: 25),

          // --- Upcoming Events/Assignments Section (Unchanged) ---
          Text(
            'Upcoming Activities',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<AssignmentItem>>(
            stream: _getUpcomingAssignmentsStream(classId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LinearProgressIndicator());
              }
              final upcomingItems = snapshot.data ?? [];
              if (upcomingItems.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No upcoming assignments or quizzes.')),
                );
              }
              return Column(
                children: upcomingItems.map((assignment) {
                  return _buildUpcomingItem(context, assignment);
                }).toList(),
              );
            },
          ),
          
          const SizedBox(height: 25),

          // --- FIX: Recent Posts/Activity Feed (Now reads from class_feed) ---
          Text(
            'Recent Posts', 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 10),
          
          StreamBuilder<List<DocumentSnapshot>>(
            stream: _getClassFeedStream(classId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading feed: ${snapshot.error}'));
              }
              final feedItems = snapshot.data ?? [];

              if (feedItems.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No announcements or doubts posted yet.'),
                  ),
                );
              }

              return Column(
                children: feedItems.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['type'] == 'announcement') {
                    return _buildAnnouncementFeedCard(context, data);
                  }
                  if (data['type'] == 'doubt') {
                    return _buildDoubtFeedCard(context, data);
                  }
                  return const SizedBox.shrink();
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Widget for "Upcoming Item" (Unchanged) ---
  Widget _buildUpcomingItem(BuildContext context, AssignmentItem assignment) {
    // ... (This function is unchanged)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String formattedDueDate() {
      final date = assignment.dueDate.toDate();
      final duration = date.difference(DateTime.now());
      if (duration.inDays > 0) return 'Due in ${duration.inDays} days';
      if (duration.inHours > 0) return 'Due in ${duration.inHours} hours';
      return 'Due Today!';
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? const Color(0xFF1C2237) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: ListTile(
        leading: const Icon(Icons.assignment, color: Colors.deepOrange),
        title: Text(assignment.title),
        subtitle: Text(formattedDueDate(), style: const TextStyle(color: Colors.orange)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AssignmentDetailPage(assignment: assignment.toFullAssignment()),
            ),
          );
        },
      ),
    );
  }

  // --- NEW: Card for "Announcement" items in the feed ---
  Widget _buildAnnouncementFeedCard(BuildContext context, Map<String, dynamic> data) {
    final announcement = Announcement(
      id: '', // Not needed for detail navigation from here
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      postedBy: data['postedBy'] ?? '',
      postedOn: data['lastActivityTimestamp'] ?? Timestamp.now(),
      courseId: data['courseId'] ?? '',
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: const CircleAvatar(
          backgroundColor: Colors.blueAccent,
          child: Icon(Icons.campaign_outlined, color: Colors.white),
        ),
        title: Text(
          announcement.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(announcement.content, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(
              'Posted by ${announcement.postedBy} • ${_timeAgo(announcement.postedOn)}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AnnouncementDetailPage(announcement: announcement),
            ),
          );
        },
      ),
    );
  }

  // --- NEW: Card for "Doubt" items in the feed ---
  Widget _buildDoubtFeedCard(BuildContext context, Map<String, dynamic> data) {
    final pollId = data['pollId'] as String? ?? '';
    final lastActivity = data['lastActivityTimestamp'] as Timestamp? ?? Timestamp.now();
    final answersCount = data['answersCount'] as int? ?? 0;
    
    // Determine the text based on answers
    String activityText;
    if (answersCount == 0) {
      activityText = 'Posted by ${data['postedBy']} • ${_timeAgo(lastActivity)}';
    } else {
      activityText = '$answersCount ${answersCount == 1 ? "answer" : "answers"} • Last reply ${_timeAgo(lastActivity)}';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.help_outline, color: Colors.white),
        ),
        title: Text(
          data['question'] ?? 'No Question',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              activityText,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
        isThreeLine: false,
        onTap: () {
          // Navigate to the full doubt detail page
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DoubtPollDetailPage(
                pollId: pollId,
                classId: classId,
                initialPollData: {
                  'question': data['question'] ?? '',
                  'postedBy': data['postedBy'] ?? '',
      'postedById': data['postedById'] ?? '',
                  'postedOn': data['postedOn'] as Timestamp? ?? Timestamp.now(),
                  'answersCount': answersCount,
                },
              ),
            ),
          );
        },
      ),
    );
  }
}