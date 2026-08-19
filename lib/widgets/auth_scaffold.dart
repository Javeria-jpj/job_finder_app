import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_logo.dart';

/// Vertical sizing for the auth screens, derived from the viewport height.
///
/// Sign-up is the tallest form in the app — four fields, a consent checkbox
/// and three actions — so instead of scrolling it sheds spacing as the window
/// shrinks. The bands below are measured so that form still fits at 600px.
@immutable
class AuthDensity {
  const AuthDensity._({
    required this.pagePadding,
    required this.headerGap,
    required this.blockGap,
    required this.fieldGap,
    required this.sectionGap,
    required this.controlHeight,
    required this.fieldPadding,
    required this.labelGap,
    required this.markSize,
    required this.roomy,
    required this.compact,
    this.tight = false,
  });

  factory AuthDensity.forHeight(double height) {
    if (height >= 900) {
      return const AuthDensity._(
        pagePadding: 24,
        headerGap: 20,
        blockGap: 16,
        fieldGap: 16,
        sectionGap: 18,
        controlHeight: 52,
        fieldPadding: 14,
        labelGap: 6,
        markSize: 40,
        roomy: true,
        compact: false,
      );
    }
    if (height >= 780) {
      return const AuthDensity._(
        pagePadding: 20,
        headerGap: 14,
        blockGap: 10,
        fieldGap: 12,
        sectionGap: 14,
        controlHeight: 48,
        fieldPadding: 11,
        labelGap: 5,
        markSize: 36,
        roomy: false,
        compact: false,
      );
    }
    if (height >= 700) {
      return const AuthDensity._(
        pagePadding: 14,
        headerGap: 12,
        blockGap: 8,
        fieldGap: 10,
        sectionGap: 12,
        controlHeight: 46,
        fieldPadding: 10,
        labelGap: 4,
        markSize: 32,
        roomy: false,
        compact: true,
      );
    }
    return const AuthDensity._(
      pagePadding: 6,
      headerGap: 6,
      blockGap: 4,
      fieldGap: 5,
      sectionGap: 7,
      controlHeight: 40,
      fieldPadding: 6,
      labelGap: 2,
      markSize: 30,
      roomy: false,
      compact: true,
      tight: true,
    );
  }

  /// Padding above and below the whole form.
  final double pagePadding;

  /// Between the header block and the form.
  final double headerGap;

  /// Between stacked lines inside the header.
  final double blockGap;

  /// Between consecutive text fields.
  final double fieldGap;

  /// Around buttons, dividers and the footer.
  final double sectionGap;

  /// Height of the primary and secondary buttons.
  final double controlHeight;

  /// Vertical content padding inside a text field.
  final double fieldPadding;

  /// Between a field's label and the field itself.
  final double labelGap;

  final double markSize;

  /// Tallest band: full type scale and generous spacing.
  final bool roomy;

  /// Short viewport: smaller type, tighter controls, no brand strip.
  final bool compact;

  /// Shortest band: the subtitle is trimmed to a single line as well.
  final bool tight;

  int get subtitleMaxLines => tight ? 1 : 2;

  /// Height of the header's icon button, so it does not blow out the row.
  double get iconButtonSize => compact ? 32 : 40;

  /// Height of a secondary row (terms, footer) that holds a small control.
  double get rowHeight => compact ? 32 : 40;

  TextStyle? titleStyle(TextTheme t) =>
      roomy ? t.headlineLarge : (compact ? t.headlineSmall : t.headlineMedium);

  TextStyle? subtitleStyle(TextTheme t) =>
      roomy ? t.bodyLarge : (compact ? t.bodySmall : t.bodyMedium);

  /// Convenience for the primary/secondary buttons on the auth screens.
  ButtonStyle get filledButtonStyle =>
      FilledButton.styleFrom(minimumSize: Size.fromHeight(controlHeight));

  ButtonStyle get outlinedButtonStyle =>
      OutlinedButton.styleFrom(minimumSize: Size.fromHeight(controlHeight));
}

/// Shared layout for the auth screens.
///
/// On wide screens it shows a deep-navy brand panel beside the form; on
/// phones it falls back to a single column. The form is built through
/// [builder] rather than passed as a widget, because its spacing depends on
/// the height this scaffold measures.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.showBackButton = false,
  });

  final String title;
  final String subtitle;
  final Widget Function(BuildContext context, AuthDensity density) builder;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= AppBreakpoints.wide;
            final density = AuthDensity.forHeight(constraints.maxHeight);

            final form = _FormPanel(
              title: title,
              subtitle: subtitle,
              density: density,
              showBackButton: showBackButton,
              // The brand strip is the first thing to go on a short screen:
              // the form itself has to fit.
              showBrandHeader: !isWide && !density.compact,
              builder: builder,
            );

            if (!isWide) return form;

            return Row(
              children: [
                Expanded(child: _BrandPanel(density: density)),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.title,
    required this.subtitle,
    required this.density,
    required this.showBackButton,
    required this.showBrandHeader,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final AuthDensity density;
  final bool showBackButton;
  final bool showBrandHeader;
  final Widget Function(BuildContext context, AuthDensity density) builder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = density;

    return Center(
      // The scroll view is a safety net for viewports shorter than the
      // tightest band, and for when an error banner appears.
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: d.pagePadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back button and brand share one row so neither costs a
              // separate line of height.
              if (showBackButton || showBrandHeader) ...[
                SizedBox(
                  height: d.iconButtonSize,
                  child: Row(
                    children: [
                      if (showBackButton)
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back),
                          iconSize: d.compact ? 20 : 24,
                          tooltip: 'Back',
                          style: IconButton.styleFrom(
                            minimumSize: Size.square(d.iconButtonSize),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      if (showBrandHeader) ...[
                        SizedBox(width: showBackButton ? AppSpacing.base : 0),
                        AppLogo.mark(size: d.markSize),
                        const SizedBox(width: AppSpacing.base),
                        // Flexible so the row cannot overflow on a narrow
                        // phone: the back button and mark are fixed, so the
                        // name is what has to give.
                        Flexible(
                          child: Text(
                            'Career Connect',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: d.roomy
                                ? theme.textTheme.titleLarge
                                : theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: d.blockGap),
              ],
              // Both header lines are capped: an extra wrapped line is the
              // difference between fitting and not on a short window.
              Text(
                title,
                style: d.titleStyle(theme.textTheme),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: d.compact ? 4 : AppSpacing.base),
              Text(
                subtitle,
                style: d.subtitleStyle(theme.textTheme),
                maxLines: d.subtitleMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: d.headerGap),
              builder(context, d),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deep-navy panel shown next to the form on wide screens.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.density});

  final AuthDensity density;

  static const List<(IconData, String, String)> _highlights = [
    (
      Icons.search,
      'Find roles that fit',
      'Search thousands of openings filtered to your skills.',
    ),
    (
      Icons.assignment_turned_in_outlined,
      'Track every application',
      'Follow each role from applied through to offer.',
    ),
    (
      Icons.bookmark_border,
      'Save what matters',
      'Bookmark opportunities and pick them up on any device.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = density;

    // The panel has no scroll view of its own, so it tracks the same bands as
    // the form rather than overflowing on a short window.
    final headline = d.roomy
        ? theme.textTheme.displaySmall
        : (d.compact
              ? theme.textTheme.headlineMedium
              : theme.textTheme.headlineLarge);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF1A2B3C)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: d.compact ? AppSpacing.md : AppSpacing.lg,
          vertical: d.pagePadding,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The full lockup here, not the cropped mark: this panel has the
            // room, and the wordmark is the point of showing a logo at all.
            AppLogo.full(
              width: d.roomy ? 200 : (d.tight ? 130 : (d.compact ? 150 : 175)),
              boxed: true,
            ),
            SizedBox(height: d.headerGap),
            Text(
              'Your next role\nstarts here.',
              style: headline?.copyWith(color: Colors.white, height: 1.15),
            ),
            SizedBox(height: d.roomy ? AppSpacing.lg : AppSpacing.md),
            for (final (icon, title, body) in _highlights)
              Padding(
                padding: EdgeInsets.only(bottom: d.sectionGap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: Colors.white, size: d.compact ? 18 : 22),
                    const SizedBox(width: AppSpacing.gutter),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style:
                                (d.compact
                                        ? theme.textTheme.titleSmall
                                        : theme.textTheme.titleMedium)
                                    ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            style:
                                (d.compact
                                        ? theme.textTheme.bodySmall
                                        : theme.textTheme.bodyMedium)
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
