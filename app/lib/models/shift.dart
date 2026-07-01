import 'job.dart';

class Shift {
  final int id;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int? jobId;
  final Job? job;
  final String? shiftType;
  final String? note;

  Shift({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.jobId,
    this.job,
    this.shiftType,
    this.note,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      jobId: json['job_id'] as int?,
      job: json['job'] != null ? Job.fromJson(json['job'] as Map<String, dynamic>) : null,
      shiftType: json['shift_type'] as String?,
      note: json['note'] as String?,
    );
  }
}
