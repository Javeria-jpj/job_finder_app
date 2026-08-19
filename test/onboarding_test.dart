import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/screens/onboarding/onboarding_screen.dart';
import 'package:job_finder_app/theme/app_theme.dart';

/// Renders the screen at a given logical size.
Future<void> pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: const OnboardingScreen()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders without layout errors', (tester) async {
    await pumpAt(tester, const Size(430, 932));

    expect(find.text('Find Your Dream Career'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  // Heights that matter: a small phone, a common phone, the iPhone 14 Pro Max
  // used in the browser preview, and a short desktop browser window.
  for (final size in const [
    Size(360, 640),
    Size(390, 844),
    Size(430, 932),
    Size(1280, 610),
    Size(1920, 1080),
    // Windowed desktop Chrome, where the viewport lands mid-range.
    Size(1512, 790),
    Size(1024, 700),
    Size(800, 600),
  ]) {
    testWidgets('fits without scrolling at ${size.width}x${size.height}', (
      tester,
    ) async {
      await pumpAt(tester, size);

      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
      expect(
        scrollable.controller?.position.maxScrollExtent ??
            tester
                .state<ScrollableState>(find.byType(Scrollable))
                .position
                .maxScrollExtent,
        0.0,
        reason: 'content must fit on screen at ${size.width}x${size.height}',
      );

      // Both actions must be reachable without scrolling.
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });
  }
}
