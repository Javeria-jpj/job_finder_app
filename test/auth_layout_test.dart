import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/screens/auth/forgot_password_screen.dart';
import 'package:job_finder_app/screens/auth/sign_in_screen.dart';
import 'package:job_finder_app/screens/auth/sign_up_screen.dart';
import 'package:job_finder_app/services/auth_service.dart';
import 'package:job_finder_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Sizes the auth screens have to fit into without scrolling: phones, a short
/// browser window, a windowed desktop browser and full screen.
///
/// These also cover the brand panel, which has no scroll view of its own: an
/// overflow there surfaces as a render error and fails the test.
const _viewports = [
  Size(360, 640),
  Size(390, 844),
  Size(430, 932),
  Size(800, 600),
  Size(1024, 700),
  Size(1280, 720),
  Size(1512, 790),
  Size(1920, 1080),
];

/// Pushes [screen] on top of a placeholder route, so `canPop` is true and the
/// back button is measured too.
Future<void> pumpPushed(WidgetTester tester, Size size, Widget screen) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Provider<AuthService>.value(
      value: AuthService(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => screen)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Fails when the form panel can be scrolled at all.
void expectNoScroll(WidgetTester tester, Size size) {
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;

  expect(
    position.maxScrollExtent,
    0.0,
    reason: 'form must fit at ${size.width}x${size.height}',
  );
}

void main() {
  for (final size in _viewports) {
    testWidgets('sign-up fits at ${size.width}x${size.height}', (tester) async {
      await pumpPushed(tester, size, const SignUpScreen());

      expectNoScroll(tester, size);
      // The whole form has to be reachable, not just the top of it.
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Sign up with Google'), findsOneWidget);
      // The footer collapses to the link alone on short screens.
      expect(
        find.text('Sign in').evaluate().length +
            find.text('Sign in instead').evaluate().length,
        1,
      );
    });

    testWidgets('sign-in fits at ${size.width}x${size.height}', (tester) async {
      await pumpPushed(tester, size, const SignInScreen());

      expectNoScroll(tester, size);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });

    testWidgets('reset password fits at ${size.width}x${size.height}', (
      tester,
    ) async {
      await pumpPushed(tester, size, const ForgotPasswordScreen());

      expectNoScroll(tester, size);
      expect(find.text('Send reset link'), findsOneWidget);
    });
  }
}
