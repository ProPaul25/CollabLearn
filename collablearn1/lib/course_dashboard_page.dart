// lib/course_dashboard_page.dart - FIXED

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'study_materials_view_page.dart'; 
import 'doubt_polls_view_page.dart';
import 'people_view_page.dart';
import 'attendance_management_page.dart';
import 'create_announcement_page.dart'; 
import 'assignment_detail_page.dart'; 
import 'doubt_poll_detail_page.dart';
import 'announcement_detail_page.dart';
import 'stream_page.dart' show Announcement; 
import 'study_groups_view_page.dart'; 
import 'package:url_launcher/url_launcher.dart';

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
            StreamTab( 
              className: widget.className,
              classCode: widget.classCode,
              classId: widget.classId,     
              isInstructor: isInstructor, 
            ),
            StudyMaterialsViewPage(classId: widget.classId), 
            PeopleViewPage(classId: widget.classId,isInstructor: isInstructor),
            AttendanceManagementPage(classId: widget.classId),
            DoubtPollsViewPage(classId: widget.classId), 
            StudyGroupsViewPage(classId: widget.classId),
          ];
          return _widgetOptions.elementAt(_selectedIndex);
        },
      ), 
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.stream), label: 'Stream'),
          BottomNavigationBarItem(icon: Icon(Icons.class_outlined), label: 'Classworks'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'People'),
          BottomNavigationBarItem(icon: Icon(Icons.check_box), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Discussion'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Groups'),
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
// DEDICATED STREAM TAB WIDGET
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

  Stream<List<AssignmentItem>> _getUpcomingAssignmentsStream(String courseId) {
    
    final DateTime now = DateTime.now();
    final DateTime startOfTodayLocal = DateTime(now.year, now.month, now.day);
    final Timestamp startOfToday = Timestamp.fromDate(startOfTodayLocal);

    return FirebaseFirestore.instance
        .collection('assignments')
        .where('courseId', isEqualTo: courseId)
        .where('dueDate', isGreaterThanOrEqualTo: startOfToday) 
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AssignmentItem.fromFirestore(doc)) 
          .toList();
    });
  }

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

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $uri');
    }
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
          
          if (isInstructor)
            Container(
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

          if (isInstructor)
            Container(
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
              
              final visibleItems = upcomingItems.take(3).toList();
              final hiddenItems = upcomingItems.length > 3 ? upcomingItems.skip(3).toList() : <AssignmentItem>[];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...visibleItems.map((assignment) {
                    return _buildUpcomingItem(context, assignment);
                  }).toList(),
                  
                  if (hiddenItems.isNotEmpty)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isDark ? const Color(0xFF1C2237) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                      child: ExpansionTile(
                        title: Text(
                          'View ${hiddenItems.length} more',
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
                        ),
                        leading: Icon(Icons.expand_more, color: primaryColor),
                        children: hiddenItems.map((assignment) {
                          return _buildUpcomingItem(context, assignment);
                        }).toList(),
                      ),
                    ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 25),

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
                  if (data['type'] == 'material') {
                    return _buildMaterialFeedCard(context, data);
                  }
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

  Widget _buildUpcomingItem(BuildContext context, AssignmentItem assignment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String formattedDueDate() {
      final date = assignment.dueDate.toDate();
      final duration = date.difference(DateTime.now());
      
      final now = DateTime.now();
      final isDueToday = date.year == now.year && date.month == now.month && date.day == now.day;

      if (duration.isNegative) {
        return isDueToday ? 'Due Today' : 'Overdue';
      }
      if (isDueToday) return 'Due Today';
      if (duration.inDays < 1) return 'Due Today'; 
      if (duration.inDays < 2) return 'Due Tomorrow';
      return 'Due in ${duration.inDays} days';
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

  Widget _buildAnnouncementFeedCard(BuildContext context, Map<String, dynamic> data) {
    final announcement = Announcement(
      id: '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      postedBy: data['postedBy'] ?? '',
      postedOn: data['lastActivityTimestamp'] ?? Timestamp.now(),
      courseId: data['courseId'] ?? '', 
      postedById: data['postedById'] ?? '',  // FIXED: Added missing postedById argument
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
        title: Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _buildDoubtFeedCard(BuildContext context, Map<String, dynamic> data) {
    final pollId = data['pollId'] as String? ?? '';
    final lastActivity = data['lastActivityTimestamp'] as Timestamp? ?? Timestamp.now();
    final answersCount = data['answersCount'] as int? ?? 0;
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
        title: Text(data['question'] ?? 'No Question', style: const TextStyle(fontWeight: FontWeight.w600)),
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
                postedById: data['postedById'] ?? '',  // FIXED: Changed from undefined 'poll' to 'data'
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMaterialFeedCard(BuildContext context, Map<String, dynamic> data) {
    final lastActivity = data['lastActivityTimestamp'] as Timestamp? ?? Timestamp.now();
    final fileUrl = data['fileUrl'] as String? ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: const CircleAvatar(
          backgroundColor: Colors.purple,
          child: Icon(Icons.book_outlined, color: Colors.white),
        ),
        title: Text(
          data['title'] ?? 'New Material',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('File: ${data['fileName'] ?? '...'}'), 
            const SizedBox(height: 8),
            Text(
              'Posted by ${data['postedBy']} • ${_timeAgo(lastActivity)}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _launchUrl(fileUrl), 
        trailing: const Icon(Icons.download_for_offline, color: Colors.grey),
      ),
    );
  }
}