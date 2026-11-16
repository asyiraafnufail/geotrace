import 'package:flutter/material.dart';
import 'geotrace_image.dart';

/// Layar penampil foto layar penuh dengan pinch-to-zoom (InteractiveViewer)
/// Memanfaatkan animasi Hero bawaan Flutter untuk transisi ekspansi yang halus.
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final String? title;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.6),
        foregroundColor: Colors.white,
        elevation: 0,
        title: title != null
            ? Text(
                title!,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              )
            : null,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Hero(
            tag: heroTag,
            child: GeoTraceCachedImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}
