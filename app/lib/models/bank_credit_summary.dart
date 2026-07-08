class BankCreditSetting {
  final String bankName;
  final int? billingDay;
  final double? manualPeriodAmount;
  final DateTime? manualPeriodSetDate;

  const BankCreditSetting({
    required this.bankName,
    this.billingDay,
    this.manualPeriodAmount,
    this.manualPeriodSetDate,
  });

  factory BankCreditSetting.fromJson(Map<String, dynamic> json) => BankCreditSetting(
        bankName: json['bank_name'] as String,
        billingDay: json['billing_day'] as int?,
        manualPeriodAmount: (json['manual_period_amount'] as num?)?.toDouble(),
        manualPeriodSetDate: json['manual_period_set_date'] != null
            ? DateTime.parse(json['manual_period_set_date'] as String)
            : null,
      );
}

class BankBill {
  final DateTime closingDate;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double amount;
  final bool paid;

  const BankBill({
    required this.closingDate,
    required this.periodStart,
    required this.periodEnd,
    required this.amount,
    required this.paid,
  });

  factory BankBill.fromJson(Map<String, dynamic> json) => BankBill(
        closingDate: DateTime.parse(json['closing_date'] as String),
        periodStart: DateTime.parse(json['period_start'] as String),
        periodEnd: DateTime.parse(json['period_end'] as String),
        amount: (json['amount'] as num).toDouble(),
        paid: json['paid'] as bool,
      );
}

class BankCreditSummary {
  final String bankName;
  final double creditLimit;
  final int? billingDay;
  final DateTime? lastClosingDate;
  final double currentPeriodSpend;
  final double availableCredit;
  final List<BankBill> unpaidBills;

  const BankCreditSummary({
    required this.bankName,
    required this.creditLimit,
    this.billingDay,
    this.lastClosingDate,
    required this.currentPeriodSpend,
    required this.availableCredit,
    required this.unpaidBills,
  });

  factory BankCreditSummary.fromJson(Map<String, dynamic> json) => BankCreditSummary(
        bankName: json['bank_name'] as String,
        creditLimit: (json['credit_limit'] as num).toDouble(),
        billingDay: json['billing_day'] as int?,
        lastClosingDate: json['last_closing_date'] != null
            ? DateTime.parse(json['last_closing_date'] as String)
            : null,
        currentPeriodSpend: (json['current_period_spend'] as num).toDouble(),
        availableCredit: (json['available_credit'] as num).toDouble(),
        unpaidBills: (json['unpaid_bills'] as List<dynamic>? ?? [])
            .map((b) => BankBill.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
}
