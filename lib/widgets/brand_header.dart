import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_logo.dart';

/// App header used on the main tabs: the brand mark, "Career Connect" and a
/// notifications bell.
///
/// The mark appears only on narrow layouts. Above [AppBreakpoints.wide] the
/// navigation rail already shows the logo, and two marks side by side read as
/// a mistake.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.showBell = true});

  final bool showBell;

  @override
  Widget build(BuildContext context) {
    // The window width, not this header's width: it decides which navigation
    // the shell is showing, which is what the logo depends on.
    final showLogo = MediaQuery.sizeOf(context).width < AppBreakpoints.wide;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          if (showLogo) ...[
            const AppLogo.mark(size: 44),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              'Career Connect',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (showBell)
            IconButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications.')),
              ),
              icon: const Icon(Icons.notifications_none),
              tooltip: 'Notifications',
            ),
        ],
      ),
    );
  }
}
