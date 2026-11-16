import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom Cache Manager untuk GeoTrace dengan strategi batas disk (LRU):
/// - Menampung maksimal ~250 foto (estimasi 50 - 150 MB).
/// - Cache tersimpan selama 14 hari, otomatis purge objek terlama saat limit tercapai.
class GeoTraceCacheManager {
  static const String key = 'geotrace_image_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 250,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  /// Method utilitas untuk menghapus seluruh cache lokal jika pengguna ingin membersihkan memori HP
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }
}
