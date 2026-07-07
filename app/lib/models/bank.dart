class Bank {
  final int id;
  final String name;

  const Bank({
    required this.id,
    required this.name,
  });

  factory Bank.fromJson(Map<String, dynamic> json) => Bank(
        id: json['id'] as int,
        name: json['name'] as String,
      );
}
