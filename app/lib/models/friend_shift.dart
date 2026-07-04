import 'group_shift.dart' show PublicJob;

/// 好友分享給你看的班次；只帶 PublicJob（id/name/color），沒有薪資欄位。
class FriendShift {
  final int id;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? shiftType;
  final String? note;
  final PublicJob? job;

  FriendShift({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.shiftType,
    this.note,
    this.job,
  });

  factory FriendShift.fromJson(Map<String, dynamic> json) {
    return FriendShift(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      startTime: (json['start_time'] as String).substring(0, 5),
      endTime: (json['end_time'] as String).substring(0, 5),
      shiftType: json['shift_type'] as String?,
      note: json['note'] as String?,
      job: json['job'] != null ? PublicJob.fromJson(json['job'] as Map<String, dynamic>) : null,
    );
  }
}
