import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../storage/custom_cache_manager.dart';
import 'skeleton_loading.dart';

/// Widget gambar jaringan yang otomatis menggunakan GeoTraceCacheManager (LRU 150 MB limit)
/// Dilengkapi animasi fade-in lembut dan opsi Hero tag untuk transisi layar penuh yang mulus.
class GeoTraceCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? heroTag;

  const GeoTraceCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      fadeOutDuration: const Duration(milliseconds: 150),
      fadeInCurve: Curves.easeOut,
      cacheManager: GeoTraceCacheManager.instance,
      placeholder: (context, url) => ShimmerLoading(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: borderRadius,
          ),
          child: Center(
            child: Icon(
              Icons.image_outlined,
              color: Colors.grey.shade400,
              size: 28,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: image,
      );
    }

    return image;
  }
}
