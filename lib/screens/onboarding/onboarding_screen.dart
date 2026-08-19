import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../auth/sign_in_screen.dart';
import '../auth/sign_up_screen.dart';

/// First screen for signed-out users: brand mark, hero, value proposition,
/// then Get Started / Log In.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Everything is sized off the available height so the screen fits
            // without scrolling, from a short browser window up to a tall
            // phone. The scroll view stays as a safety net for extremes.
            final height = constraints.maxHeight;
            final short = height < 720;
            final tight = height < 600;
            // Only the tallest screens have room for generous spacing; the
            // logo keeps its size, so everything else gives way instead.
            final roomy = height >= 900;

            final vPad = tight ? AppSpacing.gutter : AppSpacing.md;
            final gap = tight
                ? AppSpacing.base
                : (roomy ? AppSpacing.md : AppSpacing.sm);
            final heroHeight = (height * 0.18).clamp(
              96.0,
              roomy ? 150.0 : 130.0,
            );
            // The lockup is square, so this is its height too. Scaling it with
            // the viewport keeps it recognisable at every window size.
            final logoWidth = (height * 0.22).clamp(120.0, 240.0);

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: vPad,
              ),
              // Center horizontally: the column is capped at 480 wide, so on a
              // desktop window it would otherwise sit against the left edge.
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    minHeight: height - (vPad * 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        // Always the full lockup, scaled with the viewport.
                        // Swapping to the bare mark on shorter screens made
                        // the brand look broken rather than compact.
                        child: AppLogo.full(width: logoWidth),
                      ),
                      SizedBox(height: gap),
                      _HeroPanel(height: heroHeight),
                      SizedBox(height: gap),
                      Text(
                        'Find Your Dream Career',
                        textAlign: TextAlign.center,
                        style: short
                            ? theme.textTheme.headlineMedium
                            : theme.textTheme.headlineLarge,
                      ),
                      SizedBox(height: AppSpacing.base),
                      Text(
                        short
                            ? 'Personalized job matching that fits your skills '
                                  'and ambitions.'
                            : 'Personalized job matching powered by intelligent '
                                  'insights. Discover opportunities that align '
                                  'with your unique skills and ambitions.',
                        textAlign: TextAlign.center,
                        style: short
                            ? theme.textTheme.bodyMedium
                            : theme.textTheme.bodyLarge,
                      ),
                      SizedBox(height: gap + AppSpacing.base),
                      FilledButton(
                        onPressed: () => _open(context, const SignUpScreen()),
                        style: tight
                            ? FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                              )
                            : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Get Started'),
                            SizedBox(width: AppSpacing.base),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSpacing.base),
                      OutlinedButton(
                        onPressed: () => _open(context, const SignInScreen()),
                        style: tight
                            ? OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                              )
                            : null,
                        child: const Text('Log In'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Stand-in for the illustration in the design: a career-growth chart drawn
/// with widgets, so the app ships no unlicensed artwork.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = height < 140;

    return Container(
      height: height,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.gutter),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryFixed, AppColors.surfaceContainerLow],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MAXIMIZE YOUR POTENTIAL',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? theme.textTheme.labelSmall
                        : theme.textTheme.labelLarge)
                    ?.copyWith(color: AppColors.secondary),
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.base),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (weight, label) in const [
                  (35, 'Skills'),
                  (55, 'Training'),
                  (75, 'Mentorship'),
                  (100, 'Promotion'),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          // Flex ratios rather than FractionallySizedBox: a
                          // Column gives its children unbounded height, which
                          // that widget cannot resolve.
                          if (weight < 100) Spacer(flex: 100 - weight),
                          Expanded(
                            flex: weight,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.25 + (weight / 100 * 0.6),
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.base),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
