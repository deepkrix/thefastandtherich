import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thefastandtherich/providers/auth_provider.dart';
import 'package:thefastandtherich/services/api_service.dart';

class AimClickScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String attemptId;
  final String seed;
  final String gameId;

  const AimClickScreen({
    super.key,
    required this.matchId,
    required this.attemptId,
    required this.seed,
    required this.gameId,
  });

  @override
  ConsumerState<AimClickScreen> createState() => _AimClickScreenState();
}

class _AimClickScreenState extends ConsumerState<AimClickScreen> {
  late final Random _random;
  int _targetsHit = 0;
  int _targetsTotal = 10;
  int _misses = 0;
  bool _finished = false;
  DateTime? _startTime;
  Offset? _targetPosition;
  final double _targetSize = 60;
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    // Random mit seed initialisiert via Konstruktor
    _startTime = DateTime.now();
    _spawnTarget();
  }

  void _spawnTarget() {
    if (_targetsHit >= _targetsTotal) {
      _finishGame();
      return;
    }
    final margin = _targetSize + 20;
    setState(() {
      _targetPosition = Offset(
        margin + _random.nextDouble() * (_screenSize.width - margin * 2),
        margin + _random.nextDouble() * (_screenSize.height - margin * 2),
      );
    });
  }

  void _onTargetHit() {
    setState(() => _targetsHit++);
    _spawnTarget();
  }

  void _onMiss() {
    setState(() => _misses++);
  }

  void _finishGame() {
    setState(() => _finished = true);
    final duration = DateTime.now().difference(_startTime!).inMilliseconds;
    final score = (_targetsHit * 1000) - (_misses * 500);
    _submitResult(max(score, 0), duration);
  }

  Future<void> _submitResult(int score, int durationMs) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.submitAttempt(
        widget.matchId, widget.attemptId,
        jsonEncode({'targetsHit': _targetsHit, 'misses': _misses, 'score': score, 'seed': widget.seed, 'gameId': widget.gameId}),
        durationMs,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    return Scaffold(
      body: GestureDetector(
        onTapDown: (details) {
          if (_finished) return;
          if (_targetPosition == null) return;
          final dist = (details.localPosition - _targetPosition!).distance;
          if (dist < _targetSize / 2) {
            _onTargetHit();
          } else {
            _onMiss();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: const Color(0xFF0F0F1B),
          child: Stack(
            children: [
              if (!_finished) ...[
                Positioned(
                  top: 16, left: 16,
                  child: Text('Treffer: $_targetsHit / $_targetsTotal', style: const TextStyle(fontSize: 20, color: Colors.amber)),
                ),
                Positioned(
                  top: 16, right: 16,
                  child: Text('Fehler: $_misses', style: const TextStyle(fontSize: 20, color: Colors.redAccent)),
                ),
                if (_targetPosition != null)
                  Positioned(
                    left: _targetPosition!.dx - _targetSize / 2,
                    top: _targetPosition!.dy - _targetSize / 2,
                    child: Container(
                      width: _targetSize, height: _targetSize,
                      decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    ),
                  ),
              ] else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      const Text('Geschafft!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 24),
                      Text('Treffer: $_targetsHit / $_targetsTotal', style: const TextStyle(fontSize: 24, color: Colors.amber)),
                      Text('Fehler: $_misses', style: const TextStyle(fontSize: 18, color: Colors.redAccent)),
                      const SizedBox(height: 48),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                        child: const Text('Zurück zur Lobby', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
