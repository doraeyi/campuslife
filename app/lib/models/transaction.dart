import 'package:flutter/material.dart';

import 'card_model.dart';

class Transaction {
  final int id;
  final int? cardId;
  final double amount; // 正數=收入, 負數=支出
  final String description;
  final String transactionType; // "expense" | "income"
  final String? category;
  final String? note;
  final bool isCod;
  final bool codPaid;
  final bool isLoan;
  final String? loanPerson;
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
    this.isCod = false,
    this.codPaid = true,
    this.isLoan = false,
    this.loanPerson,
    required this.createdAt,
    this.card,
  });

  bool get isExpense => transactionType == 'expense';
  bool get isCodUnpaid => isCod && !codPaid;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as int,
        cardId: json['card_id'] as int?,
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String,
        transactionType: json['transaction_type'] as String,
        category: json['category'] as String?,
        note: json['note'] as String?,
        isCod: json['is_cod'] as bool? ?? false,
        codPaid: json['cod_paid'] as bool? ?? true,
        isLoan: json['is_loan'] as bool? ?? false,
        loanPerson: json['loan_person'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        card: json['card'] != null
            ? AppCard.fromJson(json['card'] as Map<String, dynamic>)
            : null,
      );
}

// 借出但尚未還清的名單：姓名 -> 目前還欠多少錢
Map<String, double> outstandingLoans(List<Transaction> transactions) {
  final result = <String, double>{};
  for (final t in transactions) {
    if (!t.isLoan || t.loanPerson == null || t.loanPerson!.isEmpty) continue;
    final person = t.loanPerson!;
    if (t.transactionType == 'expense') {
      result[person] = (result[person] ?? 0) + t.amount.abs();
    } else if (t.transactionType == 'income') {
      result[person] = (result[person] ?? 0) - t.amount;
    }
  }
  result.removeWhere((_, v) => v <= 0.01);
  return result;
}

// 依姓名產生穩定的顏色，用來在列表上區分不同的人
const _kPersonPalette = [
  Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFF10B981),
  Color(0xFFF59E0B), Color(0xFF0EA5E9), Color(0xFF8B5CF6),
  Color(0xFFEF4444), Color(0xFF14B8A6),
];

Color personColor(String name) {
  final hash = name.codeUnits.fold<int>(0, (h, c) => h * 31 + c);
  return _kPersonPalette[hash.abs() % _kPersonPalette.length];
}
