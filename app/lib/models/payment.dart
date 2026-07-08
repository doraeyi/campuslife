class Payment {
  final int id;
  final String? bankName;
  final double amount;
  final DateTime paymentDate;

  const Payment({
    required this.id,
    this.bankName,
    required this.amount,
    required this.paymentDate,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as int,
        bankName: json['bank_name'] as String?,
        amount: (json['amount'] as num).toDouble(),
        paymentDate: DateTime.parse(json['payment_date'] as String),
      );
}
