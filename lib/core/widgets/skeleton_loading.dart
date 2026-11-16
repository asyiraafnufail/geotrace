import 'package:flutter/material.dart';

/// Matrix transform untuk efek geseran shimmer yang halus dan konsisten
class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Widget Shimmer Loading animatif 60fps tanpa dependency eksternal.
/// Membungkus elemen skeleton dan memancarkan kilau gradien cahaya dari kiri ke kanan.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.1, 0.5, 0.9],
              begin: const Alignment(-1.2, -0.3),
              end: const Alignment(1.2, 0.3),
              transform: _SlidingGradientTransform((_controller.value * 2.5) - 1.25),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Kotak skeleton persegi panjang atau rounded
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Bentuk skeleton lingkaran untuk foto profil / badge avatar
class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const SkeletonCircle({
    super.key,
    required this.size,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton Card untuk Timeline Feed Check-in
class SkeletonTimelineCard extends StatelessWidget {
  const SkeletonTimelineCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar + Nama User + Lokasi
            Row(
              children: [
                SkeletonCircle(size: 44),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140, height: 15, borderRadius: 6),
                      SizedBox(height: 6),
                      SkeletonBox(width: 100, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
                SkeletonBox(width: 24, height: 24, borderRadius: 12),
              ],
            ),
            SizedBox(height: 14),

            // Foto Momen Check-in
            SkeletonBox(
              width: double.infinity,
              height: 230,
              borderRadius: 18,
            ),
            SizedBox(height: 14),

            // Judul & Catatan Perjalanan
            SkeletonBox(width: 200, height: 16, borderRadius: 6),
            SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 12, borderRadius: 4),
            SizedBox(height: 6),
            SkeletonBox(width: 180, height: 12, borderRadius: 4),
            SizedBox(height: 16),

            // Reaction Pill Buttons
            Row(
              children: [
                SkeletonBox(width: 90, height: 34, borderRadius: 18),
                SizedBox(width: 10),
                SkeletonBox(width: 90, height: 34, borderRadius: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Daftar Skeleton Timeline Feed (menampilkan 3 card shimmer)
class SkeletonTimelineList extends StatelessWidget {
  final int count;

  const SkeletonTimelineList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: count,
        itemBuilder: (_, __) => const SkeletonTimelineCard(),
      ),
    );
  }
}

/// Skeleton Card untuk Activity History (Notifikasi & Interaksi Grup)
class SkeletonActivityCard extends StatelessWidget {
  const SkeletonActivityCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonCircle(size: 44),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 14, borderRadius: 6),
                  SizedBox(height: 6),
                  SkeletonBox(width: 180, height: 13, borderRadius: 5),
                  SizedBox(height: 8),
                  SkeletonBox(width: 70, height: 10, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Daftar Skeleton Activity History
class SkeletonActivityList extends StatelessWidget {
  final int count;

  const SkeletonActivityList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: count,
        itemBuilder: (_, __) => const SkeletonActivityCard(),
      ),
    );
  }
}

/// Skeleton View untuk Halaman Profile
class SkeletonProfileView extends StatelessWidget {
  const SkeletonProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 60),
        child: Column(
          children: [
            // Header Card Profil
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    SkeletonCircle(size: 80),
                    SizedBox(height: 16),
                    SkeletonBox(width: 150, height: 18, borderRadius: 6),
                    SizedBox(height: 8),
                    SkeletonBox(width: 180, height: 13, borderRadius: 4),
                    SizedBox(height: 14),
                    SkeletonBox(width: 220, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stat Cards Row
            const Row(
              children: [
                Expanded(
                  child: SkeletonBox(height: 88, borderRadius: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: SkeletonBox(height: 88, borderRadius: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Settings / Storage Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    SkeletonBox(width: double.infinity, height: 16, borderRadius: 6),
                    SizedBox(height: 12),
                    SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
                    SizedBox(height: 16),
                    SkeletonBox(width: double.infinity, height: 44, borderRadius: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
