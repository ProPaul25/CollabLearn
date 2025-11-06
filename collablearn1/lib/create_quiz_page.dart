// lib/create_quiz_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import models

class CreateQuizPage extends StatefulWidget {
  final String classId;

  const CreateQuizPage({super.key, required this.classId});

  @override
  State<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends State<CreateQuizPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '15'); // Default 15 mins
  bool _isLoading = false;
  
  // List to hold question data for creation
  final List<Map<String, dynamic>> _questions = [];

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }
  
  Future<String> _getCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Instructor';
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    final String firstName = data?['firstName'] ?? '';
    final String lastName = data?['lastName'] ?? '';
    final String name = "$firstName $lastName".trim();
    return name.isEmpty ? (user.email ?? 'Instructor') : name;
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'questionText': TextEditingController(),
        'points': TextEditingController(text: '1'),
        'options': List.generate(4, (_) => TextEditingController()),
        'correctAnswerIndex': 0, // Default to option 1
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }
  
  Future<void> _publishQuiz() async {
    if (!_formKey.currentState!.validate() || _questions.isEmpty) {
      if (_questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one question.'), backgroundColor: Colors.orange));
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userName = await _getCurrentUserName();
      final duration = int.tryParse(_durationController.text.trim()) ?? 0;
      int totalPoints = 0;

      // 1. Calculate Total Points and Validate Questions
      for (var qData in _questions) {
        final points = int.tryParse(qData['points'].text.trim()) ?? 0;
        totalPoints += points;
      }

      // 2. Create the main Quiz document
      final quizRef = FirebaseFirestore.instance.collection('quizzes').doc();
      await quizRef.set({
        'title': _titleController.text.trim(),
        'courseId': widget.classId,
        'postedBy': userName,
        'postedOn': Timestamp.now(),
        'durationMinutes': duration,
        'totalPoints': totalPoints,
      });

      // 3. Add Questions to the subcollection
      final batch = FirebaseFirestore.instance.batch();
      for (var qData in _questions) {
        final questionRef = quizRef.collection('questions').doc();
        batch.set(questionRef, {
          'questionText': qData['questionText'].text.trim(),
          'options': qData['options'].map((c) => c.text.trim()).toList(),
          'correctAnswerIndex': qData['correctAnswerIndex'],
          'points': int.tryParse(qData['points'].text.trim()) ?? 0,
        });
      }
      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz published successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish quiz: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Quiz'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Quiz Title'),
                    validator: (value) => value!.isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Time Limit (minutes)', suffixText: 'minutes'),
                    validator: (value) => (int.tryParse(value!) ?? 0) <= 0 ? 'Enter a valid duration' : null,
                  ),
                  const SizedBox(height: 30),
                  
                  const Text('Questions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  
                  ...List.generate(_questions.length, (index) => _buildQuestionCard(index)),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _addQuestion,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add Question'),
                    ),
                  ),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _publishQuiz,
                  icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.publish),
                  label: Text(_isLoading ? 'Publishing...' : 'Publish Quiz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final qData = _questions[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),
            TextFormField(
              controller: qData['questionText'],
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Question Text', border: UnderlineInputBorder()),
              validator: (value) => value!.isEmpty ? 'Text is required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: qData['points'],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Points for this question'),
              validator: (value) => (int.tryParse(value!) ?? 0) <= 0 ? 'Need points' : null,
            ),
            const SizedBox(height: 20),
            const Text('Options (Mark Correct Answer)', style: TextStyle(fontWeight: FontWeight.w600)),
            
            ...List.generate(4, (optionIndex) {
              return Row(
                children: [
                  Radio<int>(
                    value: optionIndex,
                    groupValue: qData['correctAnswerIndex'],
                    onChanged: (int? value) {
                      setState(() {
                        qData['correctAnswerIndex'] = value!;
                      });
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: qData['options'][optionIndex],
                      decoration: InputDecoration(hintText: 'Option ${optionIndex + 1}'),
                      validator: (value) => value!.isEmpty ? 'Option is required' : null,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}