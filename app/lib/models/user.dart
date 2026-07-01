class AppUser {
  final int id;
  final String email;
  final String displayName;

  AppUser({required this.id, required this.email, required this.displayName});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
    );
  }
}

class Friendship {
  final int id;
  final String status;
  final AppUser friend;
  final bool incoming;

  Friendship({required this.id, required this.status, required this.friend, required this.incoming});

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] as int,
      status: json['status'] as String,
      friend: AppUser.fromJson(json['friend'] as Map<String, dynamic>),
      incoming: json['incoming'] as bool,
    );
  }
}
