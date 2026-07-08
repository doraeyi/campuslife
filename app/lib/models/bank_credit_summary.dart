class BankCreditSetting {
  final String bankName;
  final int? billingDay;
  final double? startingBalance;
  final DateTime? startingBalanceDate;

  const BankCreditSetting({
    required this.bankName,
    this.billingDay,
    this.startingBalance,
    this.startingBalanceDate,
  });

  factory BankCreditSetting.fromJson(Map<String, dynamic> json) => BankCreditSetting(
        bankName: json['bank_name'] as String,
        billingDay: json['billing_day'] as int?,
        startingBalance: (json['starting_balance'] as num?)?.toDouble(),
        startingBalanceDate: json['starting_balance_date'] != null
            ? DateTime.parse(json['starting_balance_date'] as String)
            : null,
      );
}

class BankCreditSummary {
  final String bankName;
  final double creditLimit;
  final int? billingDay;
  final DateTime? lastClosingDate;
  final double periodDueAmount;
  final double outstandingNow;
  final double availableCredit;
  final DateTime? currentWindowStartDate;

  const BankCreditSummary({
    required this.bankName,
    required this.creditLimit,
    this.billingDay,
    this.lastClosingDate,
    required this.periodDueAmount,
    required this.outstandingNow,
    required this.availableCredit,
    this.currentWindowStartDate,
  });

  factory BankCreditSummary.fromJson(Map<String, dynamic> json) => BankCreditSummary(
        bankName: json['bank_name'] as String,
        creditLimit: (json['credit_limit'] as num).toDouble(),
        billingDay: json['billing_day'] as int?,
        lastClosingDate: json['last_closing_date'] != null
            ? DateTime.parse(json['last_closing_date'] as String)
            : null,
        periodDueAmount: (json['period_due_amount'] as num).toDouble(),
        outstandingNow: (json['outstanding_now'] as num).toDouble(),
        availableCredit: (json['available_credit'] as num).toDouble(),
        currentWindowStartDate: json['current_window_start_date'] != null
            ? DateTime.parse(json['current_window_start_date'] as String)
            : null,
      );
}
