import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/storage/image_compression_service.dart';
import '../models/check_in_model.dart';
import '../models/trip_model.dart';
import '../models/profile_model.dart';
import '../models/interaction_model.dart';

class GeoTraceRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  /// Fetch profil pengguna saat ini
  Future<ProfileModel?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return ProfileModel.fromJson(response);
  }

  /// Update profil pengguna (nama display, bio, avatar)
  Future<void> updateProfile({required String displayName, String? bio}) async {
    final user = currentUser;
    if (user == null) throw Exception('User not logged in');

    await _supabase.from('profiles').update({
      'display_name': displayName,
      'bio': bio,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  /// Fetch Timeline dengan efisiensi Egress (Pagination 15 item per request)
  Future<List<CheckInModel>> fetchTimeline({int page = 0, int pageSize = SupabaseConstants.timelinePageSize}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final response = await _supabase
        .from('check_ins')
        .select('''
          *,
          profiles:user_id (id, username, display_name, avatar_url, bio, created_at),
          check_in_photos (*),
          interactions (*, profiles:user_id (id, username, display_name, avatar_url))
        ''')
        .order('checked_in_at', ascending: false)
        .range(from, to);

    final list = response as List<dynamic>;
    return list.map((json) => CheckInModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Simpan Check-in baru beserta upload foto terkompresi
  Future<CheckInModel> createCheckIn({
    String? tripId,
    required String title,
    String? note,
    required double latitude,
    required double longitude,
    String? locationName,
    DateTime? checkedInAt,
    required List<File> rawPhotoFiles,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User not logged in to Supabase');

    // 1. Kompresi gambar client-side (maksimal 5 foto sesuai spesifikasi)
    final compressedImages = await ImageCompressionService.compressMultiple(
      rawPhotoFiles.take(SupabaseConstants.maxPhotosPerCheckIn).toList(),
    );

    // 2. Insert check_in record
    final checkInInsert = await _supabase
        .from('check_ins')
        .insert({
          if (tripId != null) 'trip_id': tripId,
          'user_id': user.id,
          'title': title,
          'note': note,
          'latitude': latitude,
          'longitude': longitude,
          'location_name': locationName,
          'checked_in_at': (checkedInAt ?? DateTime.now()).toIso8601String(),
        })
        .select()
        .single();

    final checkInId = checkInInsert['id'] as String;

    // 3. Upload tiap foto terkompresi ke Storage dan catat di tabel check_in_photos
    final photosToInsert = <Map<String, dynamic>>[];
    for (int i = 0; i < compressedImages.length; i++) {
      final img = compressedImages[i];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_$i.jpg';
      final storagePath = '${user.id}/$fileName';

      // Upload file ke bucket 'checkin-photos'
      await _supabase.storage.from(SupabaseConstants.photoBucket).upload(
            storagePath,
            img.file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Dapatkan Public URL
      final publicUrl = _supabase.storage
          .from(SupabaseConstants.photoBucket)
          .getPublicUrl(storagePath);

      photosToInsert.add({
        'check_in_id': checkInId,
        'user_id': user.id,
        'storage_path': storagePath,
        'photo_url': publicUrl,
        'width': img.width,
        'height': img.height,
        'file_size_kb': img.compressedSizeKb,
      });
    }

    if (photosToInsert.isNotEmpty) {
      await _supabase.from('check_in_photos').insert(photosToInsert);
    }

    // Return hasil check-in lengkap
    final result = await _supabase
        .from('check_ins')
        .select('''
          *,
          profiles:user_id (id, username, display_name, avatar_url, bio, created_at),
          check_in_photos (*),
          interactions (*)
        ''')
        .eq('id', checkInId)
        .single();

    return CheckInModel.fromJson(result);
  }

  /// Hapus Check-in beserta file fotonya dari Supabase Storage (mencegah penumpukan kuota 1 GB)
  Future<void> deleteCheckIn(String checkInId) async {
    final user = currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1. Ambil storage path foto terkait sebelum data terhapus
    final photosResponse = await _supabase
        .from('check_in_photos')
        .select('storage_path')
        .eq('check_in_id', checkInId);

    final paths = (photosResponse as List<dynamic>)
        .map((p) => p['storage_path'] as String)
        .where((p) => p.isNotEmpty)
        .toList();

    // 2. Hapus file gambar dari Supabase Storage bucket
    if (paths.isNotEmpty) {
      try {
        await _supabase.storage.from(SupabaseConstants.photoBucket).remove(paths);
      } catch (e) {
        // Lewati jika file di storage sudah tidak ada
      }
    }

    // 3. Hapus check-in dari tabel database (akan cascade ke check_in_photos & interactions)
    await _supabase
        .from('check_ins')
        .delete()
        .eq('id', checkInId)
        .eq('user_id', user.id);
  }

  /// Tambah interaksi / reaksi (like, love, comment)
  Future<void> addInteraction({
    required String checkInId,
    required String reactionType,
    String? content,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User not logged in');

    await _supabase.from('interactions').insert({
      'check_in_id': checkInId,
      'user_id': user.id,
      'reaction_type': reactionType,
      'content': content,
    });
  }

  /// Fetch interaksi terbaru (suka, cinta, api, komentar) untuk halaman Activity History
  Future<List<InteractionModel>> fetchRecentInteractions({int limit = 60}) async {
    final response = await _supabase
        .from('interactions')
        .select('''
          *,
          profiles:user_id (id, username, display_name, avatar_url),
          check_ins:check_in_id (
            id,
            title,
            user_id,
            location_name,
            profiles:user_id (id, username, display_name)
          )
        ''')
        .order('created_at', ascending: false)
        .limit(limit);

    final list = response as List<dynamic>;
    return list.map((json) => InteractionModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Fetch daftar Trip pengguna atau grup
  Future<List<TripModel>> fetchTrips() async {
    final response = await _supabase
        .from('trips')
        .select()
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list.map((json) => TripModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Buat Trip baru
  Future<TripModel> createTrip({
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User not logged in');

    final response = await _supabase
        .from('trips')
        .insert({
          'user_id': user.id,
          'title': title,
          'description': description,
          'start_date': startDate?.toIso8601String().split('T').first,
          'end_date': endDate?.toIso8601String().split('T').first,
        })
        .select()
        .single();

    return TripModel.fromJson(response);
  }
}
