import 'job.dart';
import 'user.dart';

class GroupShift {
  final int id;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? shiftType;
  final String? note;
  final Job? job;
  final AppUser owner;

  GroupShift({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.shiftType,
    this.note,
    this.job,
    required this.owner,
  });

  factory GroupShift.fromJson(Map<String, dynamic> json) {
    return GroupShift(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      startTime: (json['start_time'] as String).substring(0, 5),
      endTime: (json['end_time'] as String).substring(0, 5),
      shiftType: json['shift_type'] as String?,
      note: json['note'] as String?,
      job: json['job'] != null ? Job.fromJson(json['job'] as Map<String, dynamic>) : null,
      owner: AppUser.fromJson(json['owner'] as Map<String, dynamic>),
    );
  }
}

class JobShareInfo {
  final int id;
  final AppUser sharedWith;

  JobShareInfo({required this.id, required this.sharedWith});

  factory JobShareInfo.fromJson(Map<String, dynamic> json) {
    return JobShareInfo(
      id: json['id'] as int,
      sharedWith: AppUser.fromJson(json['shared_with'] as Map<String, dynamic>),
    );
  }
}
