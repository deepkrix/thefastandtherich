import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thefastandtherich/providers/auth_provider.dart';
import 'package:thefastandtherich/services/api_service.dart';

class PrecisionTimingScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String attemptId;
  final String seed;
  final String gameId;

  const PrecisionTimingScreen({
    super.key,
    required this.matchId,
    required this.attemptId,
    required this.seed,
    required this.gameId,
  });

  @override
  ConsumerState<PrecisionTimingScreen> createState() => _PrecisionTimingScreenState();
}

class _PrecisionTimingScreenState extends ConsumerState<PrecisionTimingScreen> {
  bool _running = false;
  bool _finished = false;
  double _pointerPosition = 0.0;
  double _targetPosition = 0.5;
  int? _deviation;
  String? _error;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    final seedValue = widget.seed.hashCode.abs();
    _targetPosition = (seedValue % 100) / 100.0;
    _startAnimation();
  }

  void _startAnimation() {
    _running = true;
    const fps = 60;
    const period = 2000;
    final startTime = DateTime.now().millisecondsSinceEpoch;

    _animationTimer = Timer.periodic(const Duration(milliseconds: 1000 ~/ fps), (timer) {
      if (!_running || !mounted) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
      setState(() {
        _pointerPosition = 0.5 + 0.5 * sin(2 * pi * elapsed / period);
      });
    });
  }

  void _onTap() {
    if (!_running || _finished) return;
    _running = false;
    _animationTimer?.cancel();
    final deviation = ((_pointerPosition - _targetPosition).abs() * 100).round();
    setState(() {
      _finished = true;
      _deviation = deviation;
    });
    _submitResult(deviation);
  }

  Future<void> _submitResult(int deviation) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.submitAttempt(
        widget.matchId, widget.attemptId,
        jsonEncode({'deviation': deviation, 'finalPosition': _pointerPosition, 'targetPosition': _targetPosition, 'seed': widget.seed, 'gameId': widget.gameId}),
        deviation,
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Einreichung fehlgeschlagen: $e');
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: const Color(0xFF0F0F1B),
          child: Center(child: _finished ? _buildResult() : _buildGame()),
        ),
      ),
    );
  }

  Widget _buildGame() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Stoppe den Zeiger in der Zielzone!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 48),
        SizedBox(
          width: 300, height: 60,
          child: Stack(
            children: [
              Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: const LinearGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.yellow, Colors.red]))),
              Positioned(left: _targetPosition * 300 - 15, child: Container(width: 30, height: 60, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(4)))),
              AnimatedPositioned(duration: const Duration(milliseconds: 16), left: _pointerPosition * 300 - 4, child: Container(width: 8, height: 60, color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 48),
        const Text('TIPPE um zu stoppen!', style: TextStyle(color: Colors.amber, fontSize: 18)),
      ],
    );
  }

  Widget _buildResult() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text('Ergebnis eingereicht!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 24),
        Text('Abweichung: ${_deviation}%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amber)),
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
