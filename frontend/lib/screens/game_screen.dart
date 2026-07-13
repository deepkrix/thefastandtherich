import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thefastandtherich/providers/auth_provider.dart';
import 'package:thefastandtherich/services/api_service.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String attemptId;
  final String seed;
  final String gameId;

  const GameScreen({
    super.key,
    required this.matchId,
    required this.attemptId,
    required this.seed,
    required this.gameId,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _waiting = true;
  bool _showSignal = false;
  bool _finished = false;
  DateTime? _signalTime;
  int? _reactionMs;
  String? _error;
  Timer? _signalTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    // Seed-basierte Verzögerung (serverseitig reproduzierbar)
    final seedValue = widget.seed.hashCode.abs();
    final delayMs = 2000 + (seedValue % 3000); // 2-5 Sekunden

    _signalTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) {
        setState(() {
          _waiting = false;
          _showSignal = true;
          _signalTime = DateTime.now();
        });
      }
    });
  }

  void _onTap() {
    if (_finished) return;

    if (_waiting) {
      // Zu früh getippt -> Disqualifikation
      setState(() {
        _finished = true;
        _error = 'Zu früh! Disqualifiziert.';
        _reactionMs = 99999;
      });
      _submitResult(99999);
      return;
    }

    if (_showSignal && _signalTime != null) {
      final now = DateTime.now();
      final diff = now.difference(_signalTime!).inMilliseconds;
      setState(() {
        _showSignal = false;
        _finished = true;
        _reactionMs = diff;
      });
      _submitResult(diff);
    }
  }

  Future<void> _submitResult(int durationMs) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.submitAttempt(
        widget.matchId,
        widget.attemptId,
        jsonEncode({
          'reactionMs': durationMs,
          'seed': widget.seed,
          'gameId': widget.gameId,
        }),
        durationMs,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ergebnis eingereicht!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Einreichung fehlgeschlagen: $e');
      }
    }
  }

  @override
  void dispose() {
    _signalTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _showSignal ? Colors.green : const Color(0xFF0F0F1B),
          child: Center(
            child: _finished
                ? _buildResult()
                : _buildGameArea(),
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_waiting) ...[
          const Icon(Icons.timer, size: 64, color: Colors.amber),
          const SizedBox(height: 24),
          const Text(
            'Warte auf das Signal...',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tippe SOFORT, sobald der Bildschirm GRÜN wird!',
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ] else if (_showSignal) ...[
          const Icon(Icons.flash_on, size: 80, color: Colors.white),
          const SizedBox(height: 24),
          const Text(
            'JETZT!',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ],
    );
  }

  Widget _buildResult() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_error != null) ...[
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          const Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Ergebnis eingereicht!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 24),
          Text(
            'Reaktionszeit: ${_reactionMs}ms',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amber),
          ),
        ],
        const SizedBox(height: 48),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: const Text('Zurück zur Lobby', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
