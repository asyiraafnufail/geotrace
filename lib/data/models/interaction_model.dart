import 'profile_model.dart';

class InteractionModel {
  final String id;
  final String checkInId;
  final String userId;
  final String reactionType; // 'like', 'love', 'fire', 'comment'
  final String? content;
  final DateTime createdAt;
  final ProfileModel? profile;
  final String? checkInTitle;
  final String? checkInUserId;
  final String? checkInOwnerName;

  InteractionModel({
    required this.id,
    required this.checkInId,
    required this.userId,
    required this.reactionType,
    this.content,
    required this.createdAt,
    this.profile,
    this.checkInTitle,
    this.checkInUserId,
    this.checkInOwnerName,
  });

  factory InteractionModel.fromJson(Map<String, dynamic> json) {
    final checkInJson = json['check_ins'] as Map<String, dynamic>?;

    Map<String, dynamic>? checkInProfile;
    if (checkInJson?['profiles'] is Map<String, dynamic>) {
      checkInProfile = checkInJson!['profiles'] as Map<String, dynamic>;
    } else if (checkInJson?['profiles'] is List && (checkInJson!['profiles'] as List).isNotEmpty) {
      final first = (checkInJson['profiles'] as List).first;
      if (first is Map<String, dynamic>) checkInProfile = first;
    }

    Map<String, dynamic>? actorProfile;
    if (json['profiles'] is Map<String, dynamic>) {
      actorProfile = json['profiles'] as Map<String, dynamic>;
    } else if (json['profiles'] is List && (json['profiles'] as List).isNotEmpty) {
      final first = (json['profiles'] as List).first;
      if (first is Map<String, dynamic>) actorProfile = first;
    }

    return InteractionModel(
      id: json['id'] as String,
      checkInId: json['check_in_id'] as String,
      userId: json['user_id'] as String,
      reactionType: json['reaction_type'] as String? ?? 'like',
      content: json['content'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      profile: actorProfile != null ? ProfileModel.fromJson(actorProfile) : null,
      checkInTitle: checkInJson?['title'] as String?,
      checkInUserId: checkInJson?['user_id'] as String?,
      checkInOwnerName: checkInProfile?['display_name'] as String? ?? checkInProfile?['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'check_in_id': checkInId,
      'user_id': userId,
      'reaction_type': reactionType,
      'content': content,
      if (checkInTitle != null) 'check_in_title': checkInTitle,
      if (checkInUserId != null) 'check_in_user_id': checkInUserId,
      if (checkInOwnerName != null) 'check_in_owner_name': checkInOwnerName,
    };
  }
}
