import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'course_dashboard_page.dart'; // To access the unarchive method if needed
// You might need to import the page that contains the actual unarchive method, 
// if it's not CourseDashboardPage. For now, we'll implement the unarchive action here.


class ArchivedClassesPage extends StatefulWidget {
  const ArchivedClassesPage({super.key});

  @override
  State<ArchivedClassesPage> createState() => _ArchivedClassesPageState();
}

class _ArchivedClassesPageState extends State<ArchivedClassesPage> {
  final user = FirebaseAuth.instance.currentUser;

  // 1. Fetch only classes where the user is the instructor and the class is archived
  Stream<QuerySnapshot> _fetchArchivedClasses() {
    if (user == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('classes')
        .where('instructorId', isEqualTo: user!.uid)
        .where('isArchived', isEqualTo: true)
        .snapshots();
  }

  // 2. Unarchive function (similar to the one in CourseDashboardPage)
  Future<void> _unarchiveClass(String classId, String className) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unarchive Class'),
        content: Text('Are you sure you want to unarchive "$className"? It will reappear on your main class list.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unarchive'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('classes').doc(classId).update({
          'isArchived': false, 
        });

        if (!mounted) return;
        // Show success message and rely on the StreamBuilder to refresh the list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Class "$className" unarchived successfully!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unarchive class: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Classes'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchArchivedClasses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No archived classes found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final archivedClasses = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: archivedClasses.length,
            itemBuilder: (context, index) {
              final classData = archivedClasses[index].data() as Map<String, dynamic>;
              final classId = archivedClasses[index].id;
              final className = classData['className'] ?? 'Unknown Class';
              final classCode = classData['classCode'] ?? 'N/A';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.archive_outlined, color: Colors.deepOrange),
                  title: Text(className, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Code: $classCode'),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.unarchive, color: Colors.green),
                    label: const Text('Unarchive', style: TextStyle(color: Colors.green)),
                    onPressed: () => _unarchiveClass(classId, className),
                  ),
                  onTap: () {
                    // Optional: You could allow the instructor to view the dashboard 
                    // of an archived class, but for now, we focus on unarchiving.
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}