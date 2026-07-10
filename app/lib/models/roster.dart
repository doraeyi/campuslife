class PendingRosterPhoto {
  final int id;
  final DateTime createdAt;

  const PendingRosterPhoto({required this.id, required this.createdAt});

  factory PendingRosterPhoto.fromJson(Map<String, dynamic> json) => PendingRosterPhoto(
        id: json['id'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class RosterShift {
  final int id;
  final int rosterUploadId;
  final String employeeName;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final String? note;

  const RosterShift({
    required this.id,
    required this.rosterUploadId,
    required this.employeeName,
    required this.date,
    this.startTime,
    this.endTime,
    this.note,
  });

  factory RosterShift.fromJson(Map<String, dynamic> json) => RosterShift(
        id: json['id'] as int,
        rosterUploadId: json['roster_upload_id'] as int,
        employeeName: json['employee_name'] as String,
        date: DateTime.parse(json['date'] as String),
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
        note: json['note'] as String?,
      );
}

class RosterUpload {
  final int id;
  final int? jobId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime createdAt;
  final List<RosterShift> shifts;

  const RosterUpload({
    required this.id,
    this.jobId,
    required this.periodStart,
    required this.periodEnd,
    required this.createdAt,
    this.shifts = const [],
  });

  factory RosterUpload.fromJson(Map<String, dynamic> json) => RosterUpload(
        id: json['id'] as int,
        jobId: json['job_id'] as int?,
        periodStart: DateTime.parse(json['period_start'] as String),
        periodEnd: DateTime.parse(json['period_end'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        shifts: (json['shifts'] as List<dynamic>? ?? [])
            .map((e) => RosterShift.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
