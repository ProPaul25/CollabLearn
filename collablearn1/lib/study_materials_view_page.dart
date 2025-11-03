// lib/study_materials_view_page.dart - FINAL FIXED VERSION

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'upload_material_page.dart'; 
import 'create_assignment_page.dart'; 
import 'assignment_detail_page.dart'; 

// --- Data Models (All models defined here) ---

// --- MODEL 1: Assignment (Moved here to fix circular dependency) ---
class Assignment {
  final String id;
  final String title;
  final String description;
  final int points;
  final Timestamp dueDate;
  final String postedBy;
  final String courseId;
  final String? fileUrl; 
  final String? fileName; 

  Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.dueDate,
    required this.postedBy,
    required this.courseId,
    this.fileUrl, 
    this.fileName,
  });
}

// --- MODEL 2: StudyMaterial (Unchanged) ---
class StudyMaterial {
  final String id;
  final String title;
  final String description;
  final String fileUrl;
  final String cloudinaryPublicId;
  final String fileName;
  final String uploaderName;
  final Timestamp uploadedOn;
  final String uploaderId;
  final String type = 'material'; 

  StudyMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.cloudinaryPublicId,
    required this.fileName,
    required this.uploaderName,
    required this.uploadedOn,
    required this.uploaderId,
  });

  factory StudyMaterial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Material data is null");
    return StudyMaterial(
      id: doc.id,
      title: data['title'] ?? 'Untitled Material',
      description: data['description'] ?? 'No description provided.',
      fileUrl: data['fileUrl'] ?? '', 
      cloudinaryPublicId: data['cloudinaryPublicId'] ?? '',
      fileName: data['fileName'] ?? 'file',
      uploaderName: data['uploaderName'] ?? 'Unknown Uploader',
      uploadedOn: data['uploadedOn'] ?? Timestamp.now(),
      uploaderId: data['uploaderId'] ?? '',
    );
  }
}

// --- MODEL 3: AssignmentItem (UPDATED with fileUrl/fileName) ---
class AssignmentItem {
  final String id;
  final String title;
  final String description;
  final int points;
  final Timestamp dueDate;
  final String postedBy;
  final String courseId;
  final String? fileUrl;   // <-- UPDATED
  final String? fileName;  // <-- UPDATED
  final String type = 'assignment';

  AssignmentItem({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.dueDate,
    required this.postedBy,
    required this.courseId,
    this.fileUrl,  // <-- UPDATED
    this.fileName, // <-- UPDATED
  });

  factory AssignmentItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Assignment data is null");
    return AssignmentItem(
      id: doc.id,
      title: data['title'] ?? 'Untitled Assignment',
      description: data['description'] ?? 'No instructions.',
      points: data['points'] ?? 0,
      dueDate: data['dueDate'] ?? Timestamp.now(),
      postedBy: data['postedBy'] ?? 'Instructor',
      courseId: data['courseId'] ?? '',
      fileUrl: data['fileUrl'] as String?,   // <-- UPDATED
      fileName: data['fileName'] as String?, // <-- UPDATED
    );
  }
 
  // Convert to full Assignment model for navigation
  Assignment toFullAssignment() {
    // This now works because the Assignment class is defined above
    return Assignment(
      id: id,
      title: title,
      description: description,
      points: points,
      dueDate: dueDate,
      postedBy: postedBy,
      courseId: courseId,
      fileUrl: fileUrl,   // <-- UPDATED
      fileName: fileName, // <-- UPDATED
    );
  }
}
// --- End Data Models ---


class StudyMaterialsViewPage extends StatelessWidget {
  final String classId;

  const StudyMaterialsViewPage({
    super.key,
    required this.classId,
  });

  // --- (All streams and functions are unchanged) ---
  Stream<List<AssignmentItem>> getAssignmentsStream(String courseId) {
    return FirebaseFirestore.instance
        .collection('assignments')
        .where('courseId', isEqualTo: courseId)
        .orderBy('dueDate', descending: true) 
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AssignmentItem.fromFirestore(doc)).toList());
  }

  Stream<List<StudyMaterial>> getMaterialsStream(String courseId) {
    return FirebaseFirestore.instance
        .collection('study_materials')
        .where('courseId', isEqualTo: courseId)
        .orderBy('uploadedOn', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => StudyMaterial.fromFirestore(doc)).toList());
  }


  Future<bool> isCurrentUserInstructor(String instructorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.uid == instructorId;
  }

  Future<void> _launchUrl(String url) async {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $uri');
      }
    }
 
  void _showInstructorOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Create New...',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assignment, color: Colors.deepOrange),
              title: const Text('Create Assignment'),
              onTap: () {
                Navigator.pop(context); 
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CreateAssignmentPage(classId: classId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload, color: Colors.blue),
              title: const Text('Upload Study Material'),
              onTap: () {
                Navigator.pop(context); 
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => UploadMaterialPage(classId: classId),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildMaterialCard(BuildContext context, StudyMaterial material) {
      return MaterialCard(
        material: material,
        onView: () => _launchUrl(material.fileUrl), 
        isUploader: false, // Placeholder
      );
  }

  Widget _buildAssignmentCard(BuildContext context, AssignmentItem assignment) {
      return AssignmentCard(
        assignment: assignment,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              // This now works perfectly
              builder: (context) => AssignmentDetailPage(assignment: assignment.toFullAssignment()),
            ),
          );
        },
      );
  }
 
  @override
  Widget build(BuildContext context) {
    // --- (This entire build method is unchanged) ---
    final primaryColor = Theme.of(context).colorScheme.primary;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('classes').doc(classId).get(),
      builder: (context, classSnapshot) {
        if (!classSnapshot.hasData || classSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (classSnapshot.hasError || !classSnapshot.data!.exists) {
          return const Center(child: Text('Could not load class data.'));
        }

        final classData = classSnapshot.data!.data()!;
        final instructorId = classData['instructorId'] as String;

        return FutureBuilder<bool>(
          future: isCurrentUserInstructor(instructorId), 
          builder: (context, roleSnapshot) {
           
            final isUserInstructor = roleSnapshot.data ?? false; 

            return Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                 
                  // --- 1. Assignments Section ---
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10, top: 5),
                    child: Text('Assignments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  ),
                  StreamBuilder<List<AssignmentItem>>(
                    stream: getAssignmentsStream(classId),
                    builder: (context, assignmentSnapshot) {
                      if (assignmentSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final assignments = assignmentSnapshot.data ?? [];
                     
                      if (assignments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text('No assignments posted yet.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: assignments.map((assignment) => _buildAssignmentCard(context, assignment)).toList(),
                      );
                    },
                  ),
                 
                  const Divider(height: 30),

                  // --- 2. Study Materials Section ---
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10, top: 5),
                    child: Text('Study Materials', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                  StreamBuilder<List<StudyMaterial>>(
                    stream: getMaterialsStream(classId),
                    builder: (context, materialSnapshot) {
                      if (materialSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final materials = materialSnapshot.data ?? [];

                      if (materials.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text('No study materials uploaded yet.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        );
                      }
                     
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: materials.map((material) => _buildMaterialCard(context, material)).toList(),
                      );
                    },
                  ),
                ],
              ),
             
              floatingActionButton: isUserInstructor
                  ? FloatingActionButton.extended(
                      onPressed: () => _showInstructorOptions(context),
                      label: const Text('Create'),
                      icon: const Icon(Icons.add),
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}


// --- Study Material Card Widget (Unchanged) ---
class MaterialCard extends StatelessWidget {
  final StudyMaterial material;
  final VoidCallback onView;
  final bool isUploader;

  const MaterialCard({
    super.key,
    required this.material,
    required this.onView,
    required this.isUploader,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    String timeAgo(Timestamp timestamp) {
      final duration = DateTime.now().difference(timestamp.toDate());
      if (duration.inDays > 0) return '${timestamp.toDate().day}/${timestamp.toDate().month}';
      if (duration.inHours > 0) return '${duration.inHours}h ago';
      return '${duration.inMinutes}m ago';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Icon(_getIcon(material.fileName), color: primaryColor),
        ),
        title: Text(material.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(material.description, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              'By ${material.uploaderName} • ${timeAgo(material.uploadedOn)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.file_download),
          color: Colors.green,
          onPressed: onView,
        ),
        onTap: onView,
      ),
    );
  }
 
  IconData _getIcon(String fileName) {
    if (fileName.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (fileName.endsWith('.pptx') || fileName.endsWith('.ppt')) return Icons.slideshow;
    if (fileName.endsWith('.docx') || fileName.endsWith('.doc')) return Icons.description;
    if (fileName.endsWith('.zip') || fileName.endsWith('.rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }
}

// --- Assignment Card Widget (Unchanged) ---
class AssignmentCard extends StatelessWidget {
  final AssignmentItem assignment;
  final VoidCallback onTap;

  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = DateTime.now().isAfter(assignment.dueDate.toDate());
    final primaryColor = Theme.of(context).colorScheme.primary;
   
    // Format Due Date
    String formattedDueDate() {
      final date = assignment.dueDate.toDate();
      return 'Due: ${date.day}/${date.month} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isOverdue ? Colors.red.shade300 : Colors.transparent, width: 1)),
      color: isOverdue ? Colors.red.shade50.withOpacity(0.1) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue ? Colors.red : Colors.deepOrange,
          child: const Icon(Icons.assignment, color: Colors.white),
        ),
        title: Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Points: ${assignment.points}', style: TextStyle(color: primaryColor)),
            const SizedBox(height: 4),
            Text(
              formattedDueDate(),
              style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.grey),
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor),
        onTap: onTap,
      ),
    );
  }
}