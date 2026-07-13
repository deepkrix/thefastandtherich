import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thefastandtherich/providers/wallet_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final transactions = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(walletProvider.notifier).loadWallet();
          ref.read(transactionsProvider.notifier).loadTransactions();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BalanceCard(wallet: wallet),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showDepositDialog(context, ref),
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Coins einzahlen (Stripe Test)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Transaktionshistorie', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _TransactionList(transactions: transactions),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDepositDialog(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Einzahlung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Stripe Testmodus — Testkarten:'),
            const SizedBox(height: 8),
            const SelectableText(
              '4242 4242 4242 4242 (Erfolg)\n4000 0000 0000 0002 (Fehler)',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Anzahl Coins',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;
              Navigator.pop(context);

              try {
                await ref.read(walletProvider.notifier).deposit(amount, 'pm_card_visa');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$amount Coins eingezahlt!')),
                  );
                }
              } on DioException catch (e) {
                final msg = e.response?.data?['error']?['message'] ?? 'Einzahlung fehlgeschlagen';
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Einzahlen'),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final AsyncValue<dynamic> wallet;
  const _BalanceCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: wallet.when(
        data: (w) => Column(
          children: [
            const Text('Gesamtguthaben', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 8),
            Text('${w?.balanceCoins ?? 0} Coins', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 4),
            Text('≈ ${(w?.balanceEuro ?? 0).toStringAsFixed(2)} €', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            if ((w?.reservedCoins ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Text('Reserviert: ${w?.reservedCoins ?? 0} Coins', style: const TextStyle(color: Colors.orange, fontSize: 12)),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Fehler: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final AsyncValue<dynamic> transactions;
  const _TransactionList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return transactions.when(
      data: (list) {
        if (list == null || list.items.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Noch keine Transaktionen', style: TextStyle(color: Colors.grey))));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.items.length,
          itemBuilder: (context, index) {
            final tx = list.items[index];
            final isPositive = tx.amountCoins > 0;
            final color = isPositive ? Colors.green : Colors.red;
            IconData icon;
            switch (tx.type) {
              case 'DEPOSIT': icon = Icons.arrow_downward; break;
              case 'ENTRY_FEE': icon = Icons.sports_esports; break;
              case 'PAYOUT': icon = Icons.emoji_events; break;
              case 'REFUND': icon = Icons.replay; break;
              default: icon = Icons.swap_horiz;
            }
            return ListTile(
              leading: Icon(icon, color: color),
              title: Text(tx.type, style: const TextStyle(fontSize: 14)),
              subtitle: Text('${tx.createdAt.day}.${tx.createdAt.month}.${tx.createdAt.year}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: Text('${isPositive ? "+" : ""}${tx.amountCoins}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Fehler: $e', style: const TextStyle(color: Colors.redAccent)),
    );
  }
}
