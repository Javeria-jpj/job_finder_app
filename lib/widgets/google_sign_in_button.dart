import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "Continue with Google" button, styled as a secondary action so it does not
/// compete with the primary email button.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.label = 'Continue with Google',
    this.height,
  });

  final VoidCallback? onPressed;
  final bool busy;
  final String label;

  /// Overrides the themed 52px height on short screens.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surfaceContainerLowest,
        side: const BorderSide(color: AppColors.outlineVariant),
        minimumSize: height == null ? null : Size.fromHeight(height!),
      ),
      child: busy
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GoogleMark(),
                const SizedBox(width: AppSpacing.sm),
                // Flexible so a long label shrinks instead of overflowing the
                // button on a narrow phone.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

/// The four-colour Google "G".
///
/// Drawn rather than shipped as an image: it stays sharp at any size and on
/// any background, and the app carries no bitmap of someone else's mark.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  // Google's brand palette.
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  /// Ring thickness as a fraction of the mark's width.
  static const _strokeRatio = 0.24;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * _strokeRatio;
    // Inset by half the stroke so the ring's outer edge is the full square.
    final ring = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;

    // Angles run clockwise from 3 o'clock. The gap between blue and red at
    // about 1 o'clock is what makes it a G rather than an O.
    void arc(Color color, double startDegrees, double sweepDegrees) {
      canvas.drawArc(
        ring,
        startDegrees * math.pi / 180,
        sweepDegrees * math.pi / 180,
        false,
        paint..color = color,
      );
    }

    // Segments butt exactly against each other so no seam shows through.
    arc(_blue, -12, 76); // 1:45 → 5 o'clock
    arc(_green, 64, 86); // 5 → 8 o'clock
    arc(_yellow, 150, 85); // 8 → 11 o'clock
    arc(_red, 235, 95); // 11 → 1 o'clock

    // The crossbar, which runs from the centre out to meet the blue arc.
    final centreY = size.height / 2;
    canvas.drawRect(
      Rect.fromLTRB(
        size.width * 0.48,
        centreY - stroke / 2,
        size.width,
        centreY + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGPainter oldDelegate) => false;
}

/// "or" rule between the email form and the Google button.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, this.label = 'or'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
