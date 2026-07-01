class UserProfile {
  final int id;
  final String? email;
  final String? name;
  final String? picture;

  const UserProfile({
    required this.id,
    this.email,
    this.name,
    this.picture,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as int,
        email: json['email'] as String?,
        name: json['name'] as String?,
        picture: json['picture'] as String?,
      );

  UserProfile copyWith({String? name, String? picture}) => UserProfile(
        id: id,
        email: email,
        name: name ?? this.name,
        picture: picture ?? this.picture,
      );
}

class GoogleLinkStatus {
  final bool linked;
  final String? name;
  final String? picture;

  const GoogleLinkStatus({required this.linked, this.name, this.picture});

  factory GoogleLinkStatus.fromJson(Map<String, dynamic> json) => GoogleLinkStatus(
        linked: json['linked'] as bool,
        name: json['name'] as String?,
        picture: json['picture'] as String?,
      );
}

class LineLinkStatus {
  final bool linked;

  const LineLinkStatus({required this.linked});

  factory LineLinkStatus.fromJson(Map<String, dynamic> json) =>
      LineLinkStatus(linked: json['linked'] as bool);
}
