class Shift {
  final int id;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? note;

  Shift({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.note,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      note: json['note'] as String?,
    );
  }
}
