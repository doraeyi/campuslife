import 'package:flutter/material.dart';

import 'user.dart';

// 好友分享的班表只會拿到 JobPublicRead（id/name/color），沒有薪資欄位，
// 所以不能借用 Job.fromJson（它會讀 pay_type 等欄位，遇到 null 會直接丟例外）。
class PublicJob {
  final int id;
  final String name;
  final Color color;

  PublicJob({required this.id, required this.name, required this.color});

  factory PublicJob.fromJson(Map<String, dynamic> json) {
    final hex = (json['color'] as String).replaceFirst('#', '');
    return PublicJob(
      id: json['id'] as int,
      name: json['name'] as String,
      color: Color(int.parse('FF$hex', radix: 16)),
    );
  }
}

class GroupShift {
  final int id;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? shiftType;
  final String? note;
  final PublicJob? job;
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
      job: json['job'] != null ? PublicJob.fromJson(json['job'] as Map<String, dynamic>) : null,
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
