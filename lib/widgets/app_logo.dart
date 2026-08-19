import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Job Finder logo.
///
/// The asset is a stacked lockup — the arrow mark above the "JOB FINDER"
/// wordmark. [AppLogo.mark] crops to just the arrow, which is what stays
/// legible at header sizes; [AppLogo.full] shows the whole lockup.
class AppLogo extends StatelessWidget {
  const AppLogo.mark({super.key, this.size = 40, this.boxed = false})
    : _full = false,
      width = size;

  const AppLogo.full({super.key, this.width = 220, this.boxed = false})
    : _full = true,
      size = 0;

  static const String asset = 'assets/images/job_finder_logo.png';

  final double size;
  final double width;

  /// Draws the logo on a white rounded tile.
  ///
  /// Off by default: the artwork is transparent, so on the app's light
  /// surfaces the arrow sits directly on the background. Only needed over a
  /// dark panel, where the black wordmark would otherwise disappear.
  final bool boxed;

  final bool _full;

  /// The arrow occupies roughly the top 55% of the artwork; the rest is the
  /// wordmark, which is unreadable at small sizes.
  static const double _markHeightFactor = 0.55;

  @override
  Widget build(BuildContext context) {
    if (_full) {
      final lockup = Image.asset(
        asset,
        width: width,
        fit: BoxFit.contain,
        semanticLabel: 'Job Finder',
      );

      if (!boxed) return lockup;

      // The wordmark is black, so on a dark background the lockup needs its
      // own light tile to stay readable.
      return Container(
        padding: EdgeInsets.all(width * 0.06),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppColors.level1,
        ),
        child: lockup,
      );
    }

    final mark = ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: _markHeightFactor,
        child: Image.asset(
          asset,
          width: size,
          fit: BoxFit.contain,
          semanticLabel: 'Job Finder',
        ),
      ),
    );

    if (!boxed) return SizedBox(width: size, child: mark);

    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppColors.level1,
      ),
      child: mark,
    );
  }
}
