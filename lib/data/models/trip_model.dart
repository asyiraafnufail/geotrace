class TripModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? coverImageUrl;
  final bool isActive;
  final DateTime createdAt;

  TripModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    this.coverImageUrl,
    this.isActive = true,
    required this.createdAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? 'Perjalanan Tanpa Judul',
      description: json['description'] as String?,
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString()) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'].toString()) : null,
      coverImageUrl: json['cover_image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'cover_image_url': coverImageUrl,
      'is_active': isActive,
    };
  }
}
