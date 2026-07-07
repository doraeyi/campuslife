class Statement {
  final int id;
  final int creditAccountId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime statementDate;
  final DateTime dueDate;
  final double statementAmount;
  final double? minimumDue;
  final double paidAmount;
  final String status;

  const Statement({
    required this.id,
    required this.creditAccountId,
    required this.periodStart,
    required this.periodEnd,
    required this.statementDate,
    required this.dueDate,
    required this.statementAmount,
    this.minimumDue,
    required this.paidAmount,
    required this.status,
  });

  bool get isPaid => status == '已繳清';
  bool get isOverdue => status == '逾期';

  factory Statement.fromJson(Map<String, dynamic> json) => Statement(
        id: json['id'] as int,
        creditAccountId: json['credit_account_id'] as int,
        periodStart: DateTime.parse(json['period_start'] as String),
        periodEnd: DateTime.parse(json['period_end'] as String),
        statementDate: DateTime.parse(json['statement_date'] as String),
        dueDate: DateTime.parse(json['due_date'] as String),
        statementAmount: (json['statement_amount'] as num).toDouble(),
        minimumDue: (json['minimum_due'] as num?)?.toDouble(),
        paidAmount: (json['paid_amount'] as num).toDouble(),
        status: json['status'] as String,
      );
}
