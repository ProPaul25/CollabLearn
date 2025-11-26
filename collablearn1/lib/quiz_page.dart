// lib/quiz_page.dart 

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'quiz_model.dart';
// For navigation after submission

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

class _QuizPageState extends State<QuizPage> with SingleTickerProviderStateMixin {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  bool _isLoading = true;
  bool _quizStarted = false;
  bool _quizSubmitted = false;
  
  List<QuizQuestion> _questions = [];
  Map<String, int?> _studentAnswers = {}; // Map<QuestionId, SelectedOptionIndex>
  
  late int _secondsRemaining;
  Timer? _timer;

  // Animation controllers for dynamic effects
  late AnimationController _cardAnimationController;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.durationMinutes * 60;
    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkSubmissionStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cardAnimationController.dispose();
    _pageController.dispose();
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
        // Navigate back to dashboard 
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

  // Helper to determine timer color
  Color _getTimerColor(Color primaryColor) {
    if (_secondsRemaining <= 60) return Colors.red;
    if (_secondsRemaining <= 180) return Colors.orange;
    return primaryColor;
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
                _buildTimerDisplay(primaryColor),
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

  // Animated Timer Display in AppBar
  Widget _buildTimerDisplay(Color primaryColor) {
    final color = _getTimerColor(primaryColor);
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Row(
        children: [
          Icon(Icons.timer, color: color, size: 20),
          const SizedBox(width: 4),
          // AnimatedSwitcher provides a smooth fade between time updates
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Text(
              _formatTime(),
              // Use a Key to force the AnimatedSwitcher to recognize a change
              key: ValueKey<int>(_secondsRemaining), 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
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

  // Modified Quiz Taking View using PageView and Navigation Buttons
  Widget _buildQuizTakingView(Color primaryColor) {
    return Column(
      children: [
        // Question Navigation Tracker
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_questions.length, (index) {
              final isAnswered = _studentAnswers[_questions[index].id] != null;
              final isCurrent = index == _currentPage;
              
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index, 
                    duration: const Duration(milliseconds: 400), 
                    curve: Curves.easeInOut
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: isCurrent 
                        ? primaryColor 
                        : (isAnswered ? Colors.green.shade400 : Colors.grey.shade300),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent ? primaryColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isCurrent || isAnswered ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        
        // PageView for Questions
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _questions.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _cardAnimationController.forward(from: 0.0); // Reset and start animation
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_cardAnimationController),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.98, end: 1.0).animate(_cardAnimationController),
                    child: _buildQuestionCard(index, primaryColor),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Bottom Navigation
        _buildPageNavigationControls(primaryColor),
        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Widget _buildQuestionCard(int index, Color primaryColor) {
    final question = _questions[index];
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${index + 1} of ${_questions.length}. (${question.points} Points)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: primaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              question.questionText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Divider(height: 25),
            
            // Options
            ...List.generate(question.options.length, (optionIndex) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: _studentAnswers[question.id] == optionIndex ? primaryColor.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _studentAnswers[question.id] == optionIndex ? primaryColor : Colors.grey.shade300,
                  ),
                ),
                child: RadioListTile<int>(
                  title: Text(question.options[optionIndex], style: TextStyle(color: _studentAnswers[question.id] == optionIndex ? primaryColor : null)),
                  value: optionIndex,
                  groupValue: _studentAnswers[question.id],
                  onChanged: (int? value) {
                    setState(() {
                      _studentAnswers[question.id] = value;
                    });
                  },
                  activeColor: primaryColor,
                ),
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildPageNavigationControls(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          ElevatedButton.icon(
            onPressed: _currentPage > 0 
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 400), 
                      curve: Curves.easeInOut
                    );
                  }
                : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor.withOpacity(0.1),
              foregroundColor: primaryColor,
              elevation: 0,
            ),
          ),
          
          // Next Button
          ElevatedButton.icon(
            onPressed: _currentPage < _questions.length - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 400), 
                      curve: Curves.easeInOut
                    );
                  }
                : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}