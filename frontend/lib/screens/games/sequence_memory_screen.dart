import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thefastandtherich/providers/auth_provider.dart';
import 'package:thefastandtherich/services/api_service.dart';

class SequenceMemoryScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String attemptId;
  final String seed;
  final String gameId;

  const SequenceMemoryScreen({
    super.key,
    required this.matchId,
    required this.attemptId,
    required this.seed,
    required this.gameId,
  });

  @override
  ConsumerState<SequenceMemoryScreen> createState() => _SequenceMemoryScreenState();
}

class _SequenceMemoryScreenState extends ConsumerState<SequenceMemoryScreen> {
  late final Random _random;
  List<int> _sequence = [];
  List<int> _playerInput = [];
  int _round = 1;
  int _maxRounds = 5;
  bool _showingSequence = false;
  bool _finished = false;
  int? _currentHighlight;
  int _score = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    // Random mit seed initialisiert via Konstruktor
    _startTime = DateTime.now();
    _startRound();
  }

  void _startRound() {
    _playerInput = [];
    _sequence = [];
    for (int i = 0; i < _round + 2; i++) {
      _sequence.add(_random.nextInt(9));
    }
    _showSequence();
  }

  void _showSequence() async {
    setState(() => _showingSequence = true);
    for (int index in _sequence) {
      if (!mounted) return;
      setState(() => _currentHighlight = index);
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _currentHighlight = null);
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (mounted) setState(() => _showingSequence = false);
  }

  void _onTileTap(int index) {
    if (_showingSequence || _finished) return;

    setState(() {
      _playerInput.add(index);
      _currentHighlight = index;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _currentHighlight = null);
    });

    // Prüfe Eingabe
    final currentIndex = _playerInput.length - 1;
    if (_playerInput[currentIndex] != _sequence[currentIndex]) {
      _finishGame(false);
      return;
    }

    if (_playerInput.length == _sequence.length) {
      _score += _round * 10;
      if (_round >= _maxRounds) {
        _finishGame(true);
      } else {
        setState(() => _round++);
        Future.delayed(const Duration(milliseconds: 500), _startRound);
      }
    }
  }

  void _finishGame(bool success) {
    _finished = true;
    final duration = DateTime.now().difference(_startTime!).inMilliseconds;
    final finalScore = success ? _score : 0;

    _submitResult(finalScore, duration, success);
  }

  Future<void> _submitResult(int score, int durationMs, bool success) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.submitAttempt(
        widget.matchId, widget.attemptId,
        jsonEncode({'score': score, 'roundsCompleted': _round, 'success': success, 'seed': widget.seed, 'gameId': widget.gameId}),
        success ? durationMs : 99999,
      );
    } catch (e) {
      if (mounted) setState(() {});
    }
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Runde $_round / $_maxRounds', style: const TextStyle(fontSize: 20, color: Colors.grey)),
        const SizedBox(height: 8),
        Text('Punkte: $_score', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
        const SizedBox(height: 32),
        if (_showingSequence)
          const Text('Merke dir die Reihenfolge!', style: TextStyle(color: Colors.green, fontSize: 16))
        else
          const Text('Tippe die Reihenfolge nach!', style: TextStyle(color: Colors.amber, fontSize: 16)),
        const SizedBox(height: 32),
        SizedBox(
          width: 300, height: 300,
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: List.generate(9, (index) {
              final isHighlighted = _currentHighlight == index;
              return GestureDetector(
                onTap: () => _onTileTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: BoxDecoration(
                    color: isHighlighted ? Colors.amber : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isHighlighted ? Colors.white : Colors.grey.withOpacity(0.3)),
                  ),
                  child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 24, color: isHighlighted ? Colors.black : Colors.white))),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final success = _score > 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(success ? Icons.check_circle : Icons.cancel, size: 64, color: success ? Colors.green : Colors.red),
        const SizedBox(height: 16),
        Text(success ? 'Geschafft!' : 'Falsch!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: success ? Colors.green : Colors.red)),
        const SizedBox(height: 24),
        Text('Punkte: $_score', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amber)),
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
