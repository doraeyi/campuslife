import 'card_model.dart';

class Transaction {
  final int id;
  final int? cardId;
  final double amount; // 正數=收入, 負數=支出
  final String description;
  final String transactionType; // "expense" | "income"
  final String? category;
  final String? note;
  final DateTime createdAt;
  final AppCard? card;

  const Transaction({
    required this.id,
    this.cardId,
    required this.amount,
    required this.description,
    required this.transactionType,
    this.category,
    this.note,
    required this.createdAt,
    this.card,
  });

  bool get isExpense => transactionType == 'expense';

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as int,
        cardId: json['card_id'] as int?,
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String,
        transactionType: json['transaction_type'] as String,
        category: json['category'] as String?,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        card: json['card'] != null
            ? AppCard.fromJson(json['card'] as Map<String, dynamic>)
            : null,
      );
}
