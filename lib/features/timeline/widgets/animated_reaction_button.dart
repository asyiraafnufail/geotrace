import 'package:flutter/material.dart';

/// Tombol reaksi ringan dengan efek animasi membal (bounce micro-interaction)
/// Berjalan pada 60-120 FPS tanpa menambah ukuran aplikasi.
class AnimatedReactionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onPressed;

  const AnimatedReactionButton({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    required this.onPressed,
  });

  @override
  State<AnimatedReactionButton> createState() => _AnimatedReactionButtonState();
}

class _AnimatedReactionButtonState extends State<AnimatedReactionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _handleTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.icon,
                size: 18,
                color: widget.color ?? Colors.blueGrey,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: widget.color ?? Colors.blueGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
