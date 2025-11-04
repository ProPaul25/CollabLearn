// lib/quiz_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class QuizQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex; // Index of the correct option (0-based)
  final int points;

  QuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.points,
  });
  
  // Factory constructor for Firestore conversion
  factory QuizQuestion.fromFirestore(Map<String, dynamic> data, String id) {
    return QuizQuestion(
      id: id,
      questionText: data['questionText'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
      points: data['points'] ?? 0,
    );
  }

  // To map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'points': points,
    };
  }
}

class Quiz {
  final String id;
  final String title;
  final String courseId;
  final String postedBy;
  final Timestamp postedOn;
  final int durationMinutes;
  final int totalPoints;

  Quiz({
    required this.id,
    required this.title,
    required this.courseId,
    required this.postedBy,
    required this.postedOn,
    required this.durationMinutes,
    required this.totalPoints,
  });

  factory Quiz.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Quiz data is null");
    return Quiz(
      id: doc.id,
      title: data['title'] ?? 'Untitled Quiz',
      courseId: data['courseId'] ?? '',
      postedBy: data['postedBy'] ?? 'Instructor',
      postedOn: data['postedOn'] ?? Timestamp.now(),
      durationMinutes: data['durationMinutes'] ?? 0,
      totalPoints: data['totalPoints'] ?? 0,
    );
  }
}