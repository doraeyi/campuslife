import 'job.dart';

class Income {
  final int id;
  final int? jobId;
  final Job? job;
  final String month;
  final double grossAmount;
  final double deductionAmount;
  final double netAmount;
  final String? note;

  Income({
    required this.id,
    required this.jobId,
    required this.job,
    required this.month,
    required this.grossAmount,
    required this.deductionAmount,
    required this.netAmount,
    this.note,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      id: json['id'] as int,
      jobId: json['job_id'] as int?,
      job: json['job'] != null ? Job.fromJson(json['job'] as Map<String, dynamic>) : null,
      month: json['month'] as String,
      grossAmount: (json['gross_amount'] as num).toDouble(),
      deductionAmount: (json['deduction_amount'] as num).toDouble(),
      netAmount: (json['net_amount'] as num).toDouble(),
      note: json['note'] as String?,
    );
  }
}
