class SupabaseConstants {
  // Ganti dengan URL dan Anon Key dari dashboard Supabase Anda:
  // Dashboard -> Project Settings -> API
  static const String supabaseUrl = 'https://qpsprxfjfaqnnfgcecfd.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_EEDO0-XjtpJjVuE5IIHe4Q_svV2j5-J';

  // Nama Storage Bucket untuk foto check-in
  static const String photoBucket = 'checkin-photos';

  // Limit aplikasi sesuai spesifikasi arsitektur
  static const int maxPhotosPerCheckIn = 5;
  static const int timelinePageSize = 15;
}
