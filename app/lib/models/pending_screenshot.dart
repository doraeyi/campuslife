class PendingScreenshot {
  final int id;
  final DateTime createdAt;

  const PendingScreenshot({required this.id, required this.createdAt});

  factory PendingScreenshot.fromJson(Map<String, dynamic> json) => PendingScreenshot(
        id: json['id'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
