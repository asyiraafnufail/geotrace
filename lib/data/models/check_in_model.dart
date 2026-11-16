import 'profile_model.dart';
import 'check_in_photo_model.dart';
import 'interaction_model.dart';

class CheckInModel {
  final String id;
  final String? tripId;
  final String userId;
  final String title;
  final String? note;
  final double latitude;
  final double longitude;
  final String? locationName;
  final DateTime checkedInAt;
  final DateTime createdAt;
  final ProfileModel? profile;
  final List<CheckInPhotoModel> photos;
  final List<InteractionModel> interactions;

  CheckInModel({
    required this.id,
    this.tripId,
    required this.userId,
    required this.title,
    this.note,
    required this.latitude,
    required this.longitude,
    this.locationName,
    required this.checkedInAt,
    required this.createdAt,
    this.profile,
    this.photos = const [],
    this.interactions = const [],
  });

  factory CheckInModel.fromJson(Map<String, dynamic> json) {
    var rawPhotos = json['check_in_photos'] as List<dynamic>? ?? [];
    var photosList = rawPhotos.map((e) => CheckInPhotoModel.fromJson(e as Map<String, dynamic>)).toList();

    var rawInteractions = json['interactions'] as List<dynamic>? ?? [];
    var interactionsList = rawInteractions.map((e) => InteractionModel.fromJson(e as Map<String, dynamic>)).toList();

    return CheckInModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String?,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? 'Check-in',
      note: json['note'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      locationName: json['location_name'] as String?,
      checkedInAt: DateTime.tryParse(json['checked_in_at']?.toString() ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      profile: json['profiles'] != null ? ProfileModel.fromJson(json['profiles'] as Map<String, dynamic>) : null,
      photos: photosList,
      interactions: interactionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      'user_id': userId,
      'title': title,
      'note': note,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'checked_in_at': checkedInAt.toIso8601String(),
    };
  }
}
