class CheckInPhotoModel {
  final String id;
  final String checkInId;
  final String userId;
  final String storagePath;
  final String photoUrl;
  final int? width;
  final int? height;
  final int? fileSizeKb;
  final DateTime createdAt;

  CheckInPhotoModel({
    required this.id,
    required this.checkInId,
    required this.userId,
    required this.storagePath,
    required this.photoUrl,
    this.width,
    this.height,
    this.fileSizeKb,
    required this.createdAt,
  });

  factory CheckInPhotoModel.fromJson(Map<String, dynamic> json) {
    return CheckInPhotoModel(
      id: json['id'] as String,
      checkInId: json['check_in_id'] as String,
      userId: json['user_id'] as String,
      storagePath: json['storage_path'] as String,
      photoUrl: json['photo_url'] as String,
      width: json['width'] as int?,
      height: json['height'] as int?,
      fileSizeKb: json['file_size_kb'] as int?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'check_in_id': checkInId,
      'user_id': userId,
      'storage_path': storagePath,
      'photo_url': photoUrl,
      'width': width,
      'height': height,
      'file_size_kb': fileSizeKb,
    };
  }
}
