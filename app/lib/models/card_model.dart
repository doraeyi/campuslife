class AppCard {
  final int id;
  final String name;
  final String type; // 'debit' | 'credit' | 'easycard'
  final String color;
  final String? lastFour;
  final String? bank;
  final double? balance;
  final String? passExpiryDate;
  final String? paymentDueDate;

  const AppCard({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    this.lastFour,
    this.bank,
    this.balance,
    this.passExpiryDate,
    this.paymentDueDate,
  });

  factory AppCard.fromJson(Map<String, dynamic> json) => AppCard(
        id: json['id'] as int,
        name: json['name'] as String,
        type: json['type'] as String,
        color: json['color'] as String,
        lastFour: json['last_four'] as String?,
        bank: json['bank'] as String?,
        balance: (json['balance'] as num?)?.toDouble(),
        passExpiryDate: json['pass_expiry_date'] as String?,
        paymentDueDate: json['payment_due_date'] as String?,
      );
}
