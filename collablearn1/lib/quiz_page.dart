// lib/quiz_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'quiz_model.dart';
import 'quiz_report_page.dart'; // For navigation after submission

class QuizPage extends StatefulWidget {
  final String quizId;
  final String quizTitle;
  final int durationMinutes;

  const QuizPage({
    super.key,
    required this.quizId,
    required this.quizTitle,
    required this.durationMinutes,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  bool _isLoading = true;
  bool _quizStarted = false;
  bool _quizSubmitted = false;
  
  List<QuizQuestion> _questions = [];
  Map<String, int?> _studentAnswers = {}; // Map<QuestionId, SelectedOptionIndex>
  
  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.durationMinutes * 60;
    _checkSubmissionStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  // 1. Check if the student has already submitted
  Future<void> _checkSubmissionStatus() async {
    final submissionDoc = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .collection('submissions')
        .doc(_currentUser.uid)
        .get();

    if (submissionDoc.exists) {
      if (mounted) {
        setState(() {
          _quizSubmitted = true;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Fetch questions and start the timer
  Future<void> _startQuiz() async {
    setState(() {
      _isLoading = true;
      _quizStarted = true;
    });

    try {
      final questionsSnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('questions')
          .get();

      final fetchedQuestions = questionsSnapshot.docs
          .map((doc) => QuizQuestion.fromFirestore(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _questions = fetchedQuestions;
          _studentAnswers = {for (var q in fetchedQuestions) q.id: null};
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load quiz: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // 3. Timer logic
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsRemaining--;
          if (_secondsRemaining <= 0) {
            timer.cancel();
            _autoSubmit();
          }
        });
      }
    });
  }

  // 4. Submission logic (Manual or Auto)
  Future<void> _submitQuiz({bool auto = false}) async {
    if (_quizSubmitted) return;
    _timer?.cancel();
    setState(() {
      _isLoading = true;
      _quizSubmitted = true;
    });

    try {
      // Fetch the questions again to ensure we have the correct answers
      final questionsSnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('questions')
          .get();
      
      final correctAnswersMap = {
          for (var doc in questionsSnapshot.docs)
            doc.id: QuizQuestion.fromFirestore(doc.data(), doc.id)
      };

      int score = 0;
      int maxScore = 0;
      final studentSubmission = <String, dynamic>{};

      _questions.forEach((q) {
        final correctQ = correctAnswersMap[q.id]!;
        final studentAnswerIndex = _studentAnswers[q.id];
        maxScore += correctQ.points;
        
        final isCorrect = studentAnswerIndex != null && studentAnswerIndex == correctQ.correctAnswerIndex;
        if (isCorrect) {
          score += correctQ.points;
        }

        studentSubmission[q.id] = {
          'answerIndex': studentAnswerIndex,
          'isCorrect': isCorrect,
          'pointsAwarded': isCorrect ? correctQ.points : 0,
        };
      });
      
      final quizRef = FirebaseFirestore.instance.collection('quizzes').doc(widget.quizId);
      final submissionRef = quizRef.collection('submissions').doc(_currentUser.uid);
      
      await submissionRef.set({
        'studentId': _currentUser.uid,
        'studentEmail': _currentUser.email,
        'submissionTime': Timestamp.now(),
        'score': score,
        'maxScore': maxScore,
        'autoSubmitted': auto,
        'answers': studentSubmission,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quiz submitted! Score: $score/$maxScore')),
        );
        // Navigate back to dashboard (or a dedicated report page if implemented later)
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red));
      }
      _quizSubmitted = false; 
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _autoSubmit() {
    if (mounted) {
      _submitQuiz(auto: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time\'s up! Quiz auto-submitted.'), backgroundColor: Colors.orange),
      );
    }
  }
  
  String _formatTime() {
    final minutes = (_secondsRemaining / 60).floor();
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizTitle),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !_quizStarted || _quizSubmitted,
        actions: _quizStarted && !_quizSubmitted
            ? [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Text(_formatTime(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]
            : [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quizSubmitted
              ? _buildSubmittedView(primaryColor)
              : _quizStarted
                  ? _buildQuizTakingView(primaryColor)
                  : _buildStartView(primaryColor),
      floatingActionButton: _quizStarted && !_quizSubmitted
          ? FloatingActionButton.extended(
              onPressed: _submitQuiz,
              label: const Text('Submit Quiz'),
              icon: const Icon(Icons.send),
              backgroundColor: Colors.green,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStartView(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rate_review, size: 80, color: Colors.purple),
            const SizedBox(height: 20),
            Text(widget.quizTitle, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Time Limit: ${widget.durationMinutes} minutes', style: const TextStyle(fontSize: 18, color: Colors.red)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _startQuiz,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittedView(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text(widget.quizTitle, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            const Text('You have already submitted this quiz.', style: TextStyle(fontSize: 18, color: Colors.green)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizTakingView(Color primaryColor) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final question = _questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 20),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Q${index + 1}. (${question.points} Points) ${question.questionText}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Divider(),
                ...List.generate(question.options.length, (optionIndex) {
                  return RadioListTile<int>(
                    title: Text(question.options[optionIndex]),
                    value: optionIndex,
                    groupValue: _studentAnswers[question.id],
                    onChanged: (int? value) {
                      setState(() {
                        _studentAnswers[question.id] = value;
                      });
                    },
                    activeColor: primaryColor,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}