import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../data/repositories/geotrace_repository.dart';

class OfflineDraft {
  final String id;
  final String? tripId;
  final String title;
  final String? note;
  final double latitude;
  final double longitude;
  final String? locationName;
  final DateTime checkedInAt;
  final List<String> photoPaths;

  OfflineDraft({
    required this.id,
    this.tripId,
    required this.title,
    this.note,
    required this.latitude,
    required this.longitude,
    this.locationName,
    required this.checkedInAt,
    required this.photoPaths,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'trip_id': tripId,
        'title': title,
        'note': note,
        'latitude': latitude,
        'longitude': longitude,
        'location_name': locationName,
        'checked_in_at': checkedInAt.toIso8601String(),
        'photo_paths': photoPaths,
      };

  factory OfflineDraft.fromJson(Map<String, dynamic> json) => OfflineDraft(
        id: json['id'] as String,
        tripId: json['trip_id'] as String?,
        title: json['title'] as String,
        note: json['note'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        locationName: json['location_name'] as String?,
        checkedInAt: DateTime.tryParse(json['checked_in_at']?.toString() ?? '') ?? DateTime.now(),
        photoPaths: List<String>.from(json['photo_paths'] ?? []),
      );
}

/// Service antrean offline berbasis JSON lokal ringan (0 dependensi baru)
/// Menyimpan draft check-in saat pengguna traveling di area tanpa sinyal.
class OfflineQueueService {
  static const String _fileName = 'geotrace_offline_drafts.json';

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Ambil seluruh antrean draft offline
  static Future<List<OfflineDraft>> getDrafts() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => OfflineDraft.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Simpan draft check-in baru ke penyimpanan lokal HP
  static Future<void> saveDraft(OfflineDraft draft) async {
    final drafts = await getDrafts();
    drafts.add(draft);
    await _saveAll(drafts);
  }

  /// Hapus draft setelah berhasil disinkronkan ke Supabase
  static Future<void> removeDraft(String id) async {
    final drafts = await getDrafts();
    drafts.removeWhere((d) => d.id == id);
    await _saveAll(drafts);
  }

  static Future<void> _saveAll(List<OfflineDraft> drafts) async {
    final file = await _getFile();
    final jsonString = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await file.writeAsString(jsonString);
  }

  /// Sinkronkan seluruh draft offline ke server saat koneksi internet kembali aktif
  static Future<int> syncAll(GeoTraceRepository repo) async {
    final drafts = await getDrafts();
    if (drafts.isEmpty) return 0;

    int successCount = 0;
    for (final draft in List<OfflineDraft>.from(drafts)) {
      try {
        final photoFiles = draft.photoPaths
            .map((path) => File(path))
            .where((f) => f.existsSync())
            .toList();

        await repo.createCheckIn(
          tripId: draft.tripId,
          title: draft.title,
          note: draft.note,
          latitude: draft.latitude,
          longitude: draft.longitude,
          locationName: draft.locationName,
          checkedInAt: draft.checkedInAt,
          rawPhotoFiles: photoFiles,
        );

        await removeDraft(draft.id);
        successCount++;
      } catch (e) {
        // Berhenti jika masih offline / gagal jaringan
        break;
      }
    }

    return successCount;
  }
}
