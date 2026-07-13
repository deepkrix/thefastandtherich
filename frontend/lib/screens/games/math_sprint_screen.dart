import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thefastandtherich/providers/auth_provider.dart';
import 'package:thefastandtherich/services/api_service.dart';

class MathSprintScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String attemptId;
  final String seed;
  final String gameId;

  const MathSprintScreen({
    super.key,
    required this.matchId,
    required this.attemptId,
    required this.seed,
    required this.gameId,
  });

  @override
  ConsumerState<MathSprintScreen> createState() => _MathSprintScreenState();
}

class _MathSprintScreenState extends ConsumerState<MathSprintScreen> {
  late final Random _random;
  int _correctAnswers = 0;
  int _totalQuestions = 0;
  int _maxQuestions = 10;
  int _timeLeft = 30;
  bool _finished = false;
  Timer? _timer;
  DateTime? _startTime;
  int? _num1, _num2, _operator;
  int? _correctAnswer;
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    // Random mit seed initialisiert via Konstruktor
    _startTime = DateTime.now();
    _generateQuestion();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _finished) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          _finishGame();
        }
      });
    });
  }

  void _generateQuestion() {
    _num1 = _random.nextInt(20) + 1;
    _num2 = _random.nextInt(20) + 1;
    _operator = _random.nextInt(3); // 0=+, 1=-, 2=*

    switch (_operator) {
      case 0:
        _correctAnswer = _num1! + _num2!;
        break;
      case 1:
        if (_num1! < _num2!) {
          final temp = _num1;
          _num1 = _num2;
          _num2 = temp;
        }
        _correctAnswer = _num1! - _num2!;
        break;
      case 2:
        _num1 = _random.nextInt(12) + 1;
        _num2 = _random.nextInt(12) + 1;
        _correctAnswer = _num1! * _num2!;
        break;
    }
  }

  void _checkAnswer(int answer) {
    if (_finished) return;

    final isCorrect = answer == _correctAnswer;
    if (isCorrect) _correctAnswers++;
    _totalQuestions++;

    _history.add('$_num1 ${_getOpSymbol()} $_num2 = $answer ${isCorrect ? "✓" : "✗"}');

    if (_totalQuestions >= _maxQuestions) {
      _finishGame();
      return;
    }

    setState(() => _generateQuestion());
  }

  String _getOpSymbol() {
    switch (_operator) {
      case 0: return '+';
      case 1: return '-';
      case 2: return '×';
      default: return '+';
    }
  }

  void _finishGame() {
    _timer?.cancel();
    setState(() => _finished = true);
    final duration = DateTime.now().difference(_startTime!).inMilliseconds;
    final score = _correctAnswers * 1000;
    _submitResult(score, duration);
  }

  Future<void> _submitResult(int score, int durationMs) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.submitAttempt(
        widget.matchId, widget.attemptId,
        jsonEncode({'correctAnswers': _correctAnswers, 'totalQuestions': _totalQuestions, 'score': score, 'seed': widget.seed, 'gameId': widget.gameId}),
        durationMs,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0F0F1B),
        child: Center(child: _finished ? _buildResult() : _buildGame()),
      ),
    );
  }

  Widget _buildGame() {
    final op = _getOpSymbol();
    // Generiere 4 Antwortmöglichkeiten (1 richtig, 3 falsch)
    final answers = <int>{_correctAnswer!};
    while (answers.length < 4) {
      answers.add(_correctAnswer! + _random.nextInt(20) - 10);
    }
    final answerList = answers.toList()..shuffle(_random);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text('Richtig: $_correctAnswers', style: const TextStyle(fontSize: 18, color: Colors.green)),
            Text('Zeit: ${_timeLeft}s', style: TextStyle(fontSize: 18, color: _timeLeft < 10 ? Colors.red : Colors.amber)),
          ],
        ),
        const SizedBox(height: 48),
        Text('$_num1 $op $_num2 = ?', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 48),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: answerList.map((ans) {
            return ElevatedButton(
              onPressed: () => _checkAnswer(ans),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.amber)),
              ),
              child: Text('$ans', style: const TextStyle(fontSize: 24)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResult() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text('Zeit abgelaufen!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 24),
        Text('Richtig: $_correctAnswers / $_totalQuestions', style: const TextStyle(fontSize: 28, color: Colors.amber)),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _history.length,
            itemBuilder: (context, index) => Text(_history[index], style: const TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
          child: const Text('Zurück zur Lobby', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
