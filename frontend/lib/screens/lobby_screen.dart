import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thefastandtherich/providers/auth_provider.dart';
import 'package:thefastandtherich/providers/wallet_provider.dart';
import 'package:thefastandtherich/screens/wallet_screen.dart';
import 'package:thefastandtherich/screens/game_router.dart';
import 'package:thefastandtherich/services/api_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

final _wsChannelProvider = StateProvider<WebSocketChannel?>((ref) => null);

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  int _selectedStake = 1;
  List<dynamic> _matches = [];
  bool _loading = true;
  String? _error;

  final List<int> _stakes = [1, 2, 5, 10, 100, 500];

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _loadMatches();
  }

  void _connectWebSocket() async {
    final api = ref.read(apiServiceProvider);
    final token = await api.getAccessToken();
    if (token == null) return;

    final wsUrl = '${api.getWebSocketUrl()}$token';
    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      ref.read(_wsChannelProvider.notifier).state = channel;

      channel.stream.listen((message) {
        final data = jsonDecode(message);
        if (data['type'] == 'match.updated' || data['type'] == 'match.countdown') {
          _loadMatches();
        }
        if (data['type'] == 'wallet.balance.updated') {
          ref.read(walletProvider.notifier).loadWallet();
        }
      }, onError: (e) {
        debugPrint('WS Error: $e');
      });
    } catch (e) {
      debugPrint('WS Connect Error: $e');
    }
  }

  Future<void> _loadMatches() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.getMatches(_selectedStake);
      if (mounted) {
        setState(() {
          _matches = response.data ?? [];
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    final channel = ref.read(_wsChannelProvider);
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.amber.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Guthaben', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    wallet.when(
                      data: (w) => Text('${w?.balanceCoins ?? 0} Coins', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
                      loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      error: (_, __) => const Text('—', style: TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
                Text(user?.email ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _stakes.length,
              itemBuilder: (context, index) {
                final stake = _stakes[index];
                final selected = stake == _selectedStake;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$stake C'),
                    selected: selected,
                    onSelected: (_) {
                      setState(() { _selectedStake = stake; _loading = true; });
                      _loadMatches();
                    },
                    selectedColor: Colors.amber,
                    labelStyle: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Fehler: $_error', style: const TextStyle(color: Colors.redAccent)))
                    : _matches.isEmpty
                        ? const Center(child: Text('Keine offenen Matches', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _matches.length,
                            itemBuilder: (context, index) {
                              final match = _matches[index];
                              return _MatchCard(
                                match: match,
                                onJoin: () => _joinMatch(match),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinMatch(dynamic match) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.joinMatch(match['matchId'], user.userId);
      final attemptId = response.data['attemptId'];
      final seed = response.data['gameConfig']['seed'];
      final gameId = response.data['gameConfig']['gameId'];
      final gameName = match['gameName'] ?? 'Reaction Tap';

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameRouter.route(
              matchId: match['matchId'],
              attemptId: attemptId,
              seed: seed,
              gameId: gameId,
              gameName: gameName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Beitritt fehlgeschlagen: $e')),
        );
      }
    }
  }
}

class _MatchCard extends StatelessWidget {
  final dynamic match;
  final VoidCallback onJoin;

  const _MatchCard({required this.match, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final pot = match['potTotalCoins'] ?? 0;
    final status = match['status'] ?? 'OPEN';
    final closesAt = DateTime.parse(match['closesAt']);
    final remaining = closesAt.difference(DateTime.now());
    final participants = match['participantCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: const Color(0xFF1A1A2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match['matchId'] ?? 'Match', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Pot: $pot Coins', style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$participants Spieler', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    remaining.isNegative ? 'Geschlossen' : 'Noch ${remaining.inMinutes}m ${remaining.inSeconds % 60}s',
                    style: TextStyle(color: remaining.inSeconds < 60 ? Colors.redAccent : Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: status == 'OPEN' ? onJoin : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: const Text('Beitreten'),
            ),
          ],
        ),
      ),
    );
  }
}
