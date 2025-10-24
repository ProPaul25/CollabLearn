// lib/study_materials_view_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // Used to open the file URL
import 'package:firebase_auth/firebase_auth.dart';
import 'upload_material_page.dart'; // Import the upload page

// --- Data Model ---
class StudyMaterial {
  final String id;
  final String title;
  final String description;
  final String fileUrl;
  final String fileName;
  final String uploaderName;
  final Timestamp uploadedOn;
  final String uploaderId;

  StudyMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
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
      fileName: data['fileName'] ?? 'file',
      uploaderName: data['uploaderName'] ?? 'Unknown Uploader',
      uploadedOn: data['uploadedOn'] ?? Timestamp.now(),
      uploaderId: data['uploaderId'] ?? '',
    );
  }
}
// --- End Data Model ---

class StudyMaterialsViewPage extends StatelessWidget {
  final String classId;

  const StudyMaterialsViewPage({
    super.key,
    required this.classId,
  });

  Stream<List<StudyMaterial>> getMaterialsStream(String courseId) {
    return FirebaseFirestore.instance
        .collection('study_materials')
        .where('courseId', isEqualTo: courseId)
        .orderBy('uploadedOn', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => StudyMaterial.fromFirestore(doc))
          .toList();
    });
  }

  // --- Helper Functions ---

  // NOTE: You would typically fetch the user's role from their Firestore document
  // For this implementation, we will use a basic check for demonstration.
  // Replace this with your actual role checking logic.
  bool isInstructor(BuildContext context) {
    // Replace with actual role check from user data
    return true; // Assume true for testing instructor features
  }

  // Function to open the file URL
  Future<void> _launchUrl(String url) async {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        // Use the global function launchUrl and global enum LaunchMode
        throw Exception('Could not launch $uri');
      }
    }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isUserInstructor = isInstructor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: StreamBuilder<List<StudyMaterial>>(
        stream: getMaterialsStream(classId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading materials: ${snapshot.error.toString()}'));
          }

          final materials = snapshot.data ?? [];

          if (materials.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  isUserInstructor 
                      ? 'No materials uploaded yet. Tap the button to share resources.'
                      : 'No study materials have been shared for this course.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final material = materials[index];
              return MaterialCard(
                material: material,
                onView: () => _launchUrl(material.fileUrl),
                isUploader: material.uploaderId == currentUserId,
              );
            },
          );
        },
      ),
      
      // FAB for Instructor to upload new material
      floatingActionButton: isUserInstructor
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => UploadMaterialPage(classId: classId),
                  ),
                );
              },
              label: const Text('Upload Material'),
              icon: const Icon(Icons.add),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}


// --- Material Card Widget ---
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
  
  // Simple helper to determine the file icon
  IconData _getIcon(String fileName) {
    if (fileName.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (fileName.endsWith('.pptx') || fileName.endsWith('.ppt')) return Icons.slideshow;
    if (fileName.endsWith('.docx') || fileName.endsWith('.doc')) return Icons.description;
    if (fileName.endsWith('.zip') || fileName.endsWith('.rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }
}