import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thefastandtherich/models/wallet.dart';
import 'package:thefastandtherich/providers/auth_provider.dart';
import 'package:thefastandtherich/services/api_service.dart';

final walletProvider = StateNotifierProvider<WalletNotifier, AsyncValue<Wallet?>>((ref) {
  return WalletNotifier(ref.read(apiServiceProvider));
});

final transactionsProvider = StateNotifierProvider<TransactionsNotifier, AsyncValue<TransactionList?>>((ref) {
  return TransactionsNotifier(ref.read(apiServiceProvider));
});

class WalletNotifier extends StateNotifier<AsyncValue<Wallet?>> {
  final ApiService _api;

  WalletNotifier(this._api) : super(const AsyncValue.loading()) {
    loadWallet();
  }

  Future<void> loadWallet() async {
    try {
      final response = await _api.getWallet();
      final wallet = Wallet.fromJson(response.data);
      state = AsyncValue.data(wallet);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deposit(int amountCoins, String paymentMethodId) async {
    try {
      await _api.deposit(amountCoins, paymentMethodId);
      await loadWallet();
    } catch (e) {
      rethrow;
    }
  }
}

class TransactionsNotifier extends StateNotifier<AsyncValue<TransactionList?>> {
  final ApiService _api;

  TransactionsNotifier(this._api) : super(const AsyncValue.loading()) {
    loadTransactions();
  }

  Future<void> loadTransactions({String? cursor}) async {
    try {
      final response = await _api.getTransactions(cursor: cursor);
      final list = TransactionList.fromJson(response.data);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
