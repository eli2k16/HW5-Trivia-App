import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html_unescape/html_unescape.dart'; 

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

void main() {
  runApp(QuizApp());
}

class QuizApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: QuizSetupScreen(),
    );
  }
}

class QuizSetupScreen extends StatefulWidget {
  @override
  _QuizSetupScreenState createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  final List<int> questionCounts = [5, 10, 15];
  List<dynamic>? categories;
  int selectedQuestionCount = 5;
  String? selectedCategoryId;
  String selectedDifficulty = 'easy';
  String selectedType = 'multiple';

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    final response =
        await http.get(Uri.parse('https://opentdb.com/api_category.php'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        categories = data['trivia_categories'];
        selectedCategoryId = categories?.first['id'].toString();
      });
    } else {
      throw Exception('Failed to load categories');
    }
  }

  void startQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          numberOfQuestions: selectedQuestionCount,
          categoryId: selectedCategoryId!,
          difficulty: selectedDifficulty,
          type: selectedType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/quiz.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: categories == null
            ? Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Setup Your Quiz',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<int>(
                        value: selectedQuestionCount,
                        onChanged: (value) =>
                            setState(() => selectedQuestionCount = value!),
                        items: questionCounts.map((count) {
                          return DropdownMenuItem(
                            value: count,
                            child: Text(
                              '$count Questions',
                              style: TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: selectedCategoryId,
                        onChanged: (value) =>
                            setState(() => selectedCategoryId = value),
                        items: categories!.map((category) {
                          return DropdownMenuItem(
                            value: category['id'].toString(),
                            child: Text(
                              category['name'],
                              style: TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: selectedDifficulty,
                        onChanged: (value) =>
                            setState(() => selectedDifficulty = value!),
                        items: ['easy', 'medium', 'hard']
                            .map((difficulty) {
                              return DropdownMenuItem(
                                value: difficulty,
                                child: Text(
                                  difficulty.capitalize(),
                                  style: TextStyle(color: Colors.black),
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: selectedType,
                        onChanged: (value) =>
                            setState(() => selectedType = value!),
                        items: ['multiple', 'boolean']
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type == 'boolean'
                                        ? 'True/False'
                                        : 'Multiple Choice',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: startQuiz,
                      child: Text('Start Quiz',
                          style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final int numberOfQuestions;
  final String categoryId;
  final String difficulty;
  final String type;

  const QuizScreen({
    required this.numberOfQuestions,
    required this.categoryId,
    required this.difficulty,
    required this.type,
  });

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<dynamic>? questions;
  int currentQuestionIndex = 0;
  int score = 0;
  bool isAnswered = false;
  String feedback = '';
  Timer? timer;
  int timeRemaining = 15;

  @override
  void initState() {
    super.initState();
    fetchQuestions();
  }

Future<void> fetchQuestions() async {
  final url =
      'https://opentdb.com/api.php?amount=${widget.numberOfQuestions}&category=${widget.categoryId}&difficulty=${widget.difficulty}&type=${widget.type}';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    setState(() {
      questions = data['results'];
      if (questions!.isEmpty) {
        feedback = 'No questions found.';
      } else {
        // Decode HTML entities in question text and shuffle answers
        for (var question in questions!) {
          // Decode the question text using `html_unescape` for full decoding
          question['question'] = HtmlUnescape().convert(question['question']);

          // Decode each answer choice using `html_unescape` for full decoding
          var decodedIncorrectAnswers = <String>[];
          for (var answer in question['incorrect_answers']) {
            decodedIncorrectAnswers.add(HtmlUnescape().convert(answer));
          }
          
          // Also decode the correct answer
          String decodedCorrectAnswer = HtmlUnescape().convert(question['correct_answer']);

          // Add the decoded answers to the list and shuffle them
          var answers = List<String>.from(decodedIncorrectAnswers);
          answers.add(decodedCorrectAnswer);
          answers.shuffle(); // Shuffle answers once
          question['shuffled_answers'] = answers; // Store shuffled answers
        }
        startTimer(); // Start the timer after loading the questions
      }
    });
  } else {
    throw Exception('Failed to load questions');
  }
}


  void startTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (timeRemaining > 0) {
        setState(() => timeRemaining--);
      } else {
        timer.cancel();
        setState(() => feedback = "Time's up!");
      }
    });
  }

  void answerQuestion(bool isCorrect) {
    if (!isAnswered) {
      setState(() {
        isAnswered = true;
        if (isCorrect) {
          score++;
          feedback = 'Correct!';
        } else {
          feedback = 'Incorrect!';
        }
        timer?.cancel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/quiz.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: questions == null
            ? Center(child: CircularProgressIndicator())
            : questions!.isEmpty
                ? Center(
                    child: Text(
                      feedback,
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Question ${currentQuestionIndex + 1}/${questions!.length}',
                          style: TextStyle(color: Colors.black, fontSize: 20),
                        ),
                        SizedBox(height: 20),

                      // Display the remaining time
                      Text(
                        'Time Remaining: $timeRemaining',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                        ),
                      ),
                      
                        SizedBox(height: 20),
                        Text(
                          questions![currentQuestionIndex]['question'],
                          style: TextStyle(color: Colors.black, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 40),
                        ...(widget.type == 'boolean'
                            ? ['True', 'False']
                                .map((answer) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () => answerQuestion(answer == 'True'),
                                        child: Text(answer),
                                      ),
                                    ))
                                .toList()
                            : (questions![currentQuestionIndex]
                                        ['shuffled_answers'] as List<String>)
                                    .map((answer) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: ElevatedButton(
                                            onPressed: () => answerQuestion(answer == questions![currentQuestionIndex]['correct_answer']),
                                            child: Text(answer),
                                          ),
                                        ))
                                    .toList()),
                        SizedBox(height: 20),
                        if (feedback.isNotEmpty)
                          Text(
                            feedback,
                            style: TextStyle(
                              fontSize: 20,
                              color: feedback == 'Correct!' ? Colors.green : Colors.red,
                            ),
                          ),
                        SizedBox(height: 20),
                        if (isAnswered)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                if (currentQuestionIndex < questions!.length - 1) {
                                  currentQuestionIndex++;
                                  isAnswered = false;
                                  feedback = '';
                                  timeRemaining = 15;
                                  startTimer();
                                } else {
                                  Navigator.pop(context);
                                }
                              });
                            },
                            child: Text(currentQuestionIndex == questions!.length - 1
                                ? 'Finish Quiz'
                                : 'Next Question'),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
