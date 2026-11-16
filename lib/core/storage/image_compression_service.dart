import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CompressedImageResult {
  final File file;
  final int originalSizeKb;
  final int compressedSizeKb;
  final int width;
  final int height;

  CompressedImageResult({
    required this.file,
    required this.originalSizeKb,
    required this.compressedSizeKb,
    required this.width,
    required this.height,
  });

  double get compressionRatioPercent =>
      originalSizeKb > 0 ? ((1 - (compressedSizeKb / originalSizeKb)) * 100) : 0;
}

class ImageCompressionService {
  /// Kompresi gambar client-side sebelum upload ke Supabase:
  /// - Max width: 1080px (proporsional)
  /// - Format: JPEG / WebP kualitas 78%
  /// - Menghasilkan ukuran file rata-rata ~100-250 KB dari foto asli 3-6 MB
  static Future<CompressedImageResult?> compressImage(File file) async {
    try {
      final originalBytes = await file.readAsBytes();
      final originalSizeKb = (originalBytes.lengthInBytes / 1024).round();

      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(file.path)}.jpg',
      );

      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: 1080,
        minHeight: 1080,
        quality: 78,
        format: CompressFormat.jpeg,
        keepExif: false, // hapus metadata EXIF berlebih untuk memangkas ukuran
      );

      if (compressedXFile == null) return null;

      final compressedFile = File(compressedXFile.path);
      final compressedBytes = await compressedFile.readAsBytes();
      final compressedSizeKb = (compressedBytes.lengthInBytes / 1024).round();

      return CompressedImageResult(
        file: compressedFile,
        originalSizeKb: originalSizeKb,
        compressedSizeKb: compressedSizeKb,
        width: 1080,
        height: 1080,
      );
    } catch (e) {
      // Jika kompresi gagal, fallback dengan file asli
      final bytes = await file.readAsBytes();
      return CompressedImageResult(
        file: file,
        originalSizeKb: (bytes.lengthInBytes / 1024).round(),
        compressedSizeKb: (bytes.lengthInBytes / 1024).round(),
        width: 0,
        height: 0,
      );
    }
  }

  /// Batch kompresi untuk banyak foto sekaligus (maksimal 5 foto sesuai spesifikasi)
  static Future<List<CompressedImageResult>> compressMultiple(List<File> files) async {
    final results = <CompressedImageResult>[];
    for (final file in files.take(5)) {
      final result = await compressImage(file);
      if (result != null) {
        results.add(result);
      }
    }
    return results;
  }
}
