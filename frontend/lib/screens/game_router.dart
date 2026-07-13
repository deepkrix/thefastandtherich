import 'package:flutter/material.dart';
import 'package:thefastandtherich/screens/game_screen.dart';
import 'package:thefastandtherich/screens/games/precision_timing_screen.dart';
import 'package:thefastandtherich/screens/games/sequence_memory_screen.dart';
import 'package:thefastandtherich/screens/games/aim_click_screen.dart';
import 'package:thefastandtherich/screens/games/math_sprint_screen.dart';

class GameRouter {
  static Widget route({
    required String matchId,
    required String attemptId,
    required String seed,
    required String gameId,
    required String gameName,
  }) {
    // Für MVP: Routing basierend auf gameName (später gameId)
    switch (gameName.toLowerCase()) {
      case 'precision timing':
        return PrecisionTimingScreen(matchId: matchId, attemptId: attemptId, seed: seed, gameId: gameId);
      case 'sequence memory':
        return SequenceMemoryScreen(matchId: matchId, attemptId: attemptId, seed: seed, gameId: gameId);
      case 'aim & click':
        return AimClickScreen(matchId: matchId, attemptId: attemptId, seed: seed, gameId: gameId);
      case 'math sprint':
        return MathSprintScreen(matchId: matchId, attemptId: attemptId, seed: seed, gameId: gameId);
      case 'reaction tap':
      default:
        return GameScreen(matchId: matchId, attemptId: attemptId, seed: seed, gameId: gameId);
    }
  }
}
