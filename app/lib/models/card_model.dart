class AppCard {
  final int id;
  final String name;
  final String type; // 'debit' | 'credit' | 'easycard'
  final String color;
  final String? lastFour;
  final String? bank;
  final double? balance;
  final double? dueAmount;
  final double? creditLimit;
  final String? passExpiryDate;
  final String? paymentDueDate;
  final int? reminderDay;
  final String? creditGroupKey;

  const AppCard({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    this.lastFour,
    this.bank,
    this.balance,
    this.dueAmount,
    this.creditLimit,
    this.passExpiryDate,
    this.paymentDueDate,
    this.reminderDay,
    this.creditGroupKey,
  });

  // 沒設定 credit_group_key 的舊卡片，退回用銀行名稱當分組鍵（等同預設共用）
  String? get effectiveGroupKey => creditGroupKey ?? bank;

  factory AppCard.fromJson(Map<String, dynamic> json) => AppCard(
        id: json['id'] as int,
        name: json['name'] as String,
        type: json['type'] as String,
        color: json['color'] as String,
        lastFour: json['last_four'] as String?,
        bank: json['bank'] as String?,
        balance: (json['balance'] as num?)?.toDouble(),
        dueAmount: (json['due_amount'] as num?)?.toDouble(),
        creditLimit: (json['credit_limit'] as num?)?.toDouble(),
        passExpiryDate: json['pass_expiry_date'] as String?,
        paymentDueDate: json['payment_due_date'] as String?,
        reminderDay: json['reminder_day'] as int?,
        creditGroupKey: json['credit_group_key'] as String?,
      );
}
