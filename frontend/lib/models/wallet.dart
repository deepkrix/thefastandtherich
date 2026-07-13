class Wallet {
  final String walletId;
  final int balanceCoins;
  final int reservedCoins;
  final double currencyRate;
  final String status;

  Wallet({
    required this.walletId,
    required this.balanceCoins,
    required this.reservedCoins,
    required this.currencyRate,
    required this.status,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      walletId: json['walletId'],
      balanceCoins: json['balanceCoins'],
      reservedCoins: json['reservedCoins'],
      currencyRate: (json['currencyRate'] as num).toDouble(),
      status: json['status'],
    );
  }

  double get balanceEuro => balanceCoins * currencyRate;
  double get reservedEuro => reservedCoins * currencyRate;
}

class Transaction {
  final String transactionId;
  final String type;
  final int amountCoins;
  final int balanceAfter;
  final String? referenceId;
  final DateTime createdAt;

  Transaction({
    required this.transactionId,
    required this.type,
    required this.amountCoins,
    required this.balanceAfter,
    this.referenceId,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      transactionId: json['transactionId'],
      type: json['type'],
      amountCoins: json['amountCoins'],
      balanceAfter: json['balanceAfter'],
      referenceId: json['referenceId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  bool get isPositive => amountCoins > 0;
  String get formattedAmount => '${isPositive ? "+" : ""}${amountCoins} Coins';
}

class TransactionList {
  final List<Transaction> items;
  final String? nextCursor;

  TransactionList({required this.items, this.nextCursor});

  factory TransactionList.fromJson(Map<String, dynamic> json) {
    return TransactionList(
      items: (json['items'] as List)
          .map((e) => Transaction.fromJson(e))
          .toList(),
      nextCursor: json['nextCursor'],
    );
  }
}
