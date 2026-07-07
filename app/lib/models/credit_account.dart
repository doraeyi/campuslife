import 'bank.dart';

class CreditAccount {
  final int id;
  final int bankId;
  final String name;
  final double creditLimit;
  final int? billingDay;
  final int? dueDay;
  final Bank? bank;

  const CreditAccount({
    required this.id,
    required this.bankId,
    required this.name,
    required this.creditLimit,
    this.billingDay,
    this.dueDay,
    this.bank,
  });

  factory CreditAccount.fromJson(Map<String, dynamic> json) => CreditAccount(
        id: json['id'] as int,
        bankId: json['bank_id'] as int,
        name: json['name'] as String,
        creditLimit: (json['credit_limit'] as num).toDouble(),
        billingDay: json['billing_day'] as int?,
        dueDay: json['due_day'] as int?,
        bank: json['bank'] != null
            ? Bank.fromJson(json['bank'] as Map<String, dynamic>)
            : null,
      );
}

class CreditAccountAvailable {
  final int creditAccountId;
  final double creditLimit;
  final double outstandingBalance;
  final double availableCredit;

  const CreditAccountAvailable({
    required this.creditAccountId,
    required this.creditLimit,
    required this.outstandingBalance,
    required this.availableCredit,
  });

  factory CreditAccountAvailable.fromJson(Map<String, dynamic> json) => CreditAccountAvailable(
        creditAccountId: json['credit_account_id'] as int,
        creditLimit: (json['credit_limit'] as num).toDouble(),
        outstandingBalance: (json['outstanding_balance'] as num).toDouble(),
        availableCredit: (json['available_credit'] as num).toDouble(),
      );
}
