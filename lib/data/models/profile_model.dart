class ProfileModel {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'User',
      displayName: json['display_name'] as String? ?? 'User',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
