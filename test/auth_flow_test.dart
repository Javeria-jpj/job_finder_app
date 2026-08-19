import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/screens/auth/sign_in_screen.dart';
import 'package:job_finder_app/screens/auth/sign_up_screen.dart';
import 'package:job_finder_app/services/auth_service.dart';
import 'package:job_finder_app/theme/app_theme.dart';
import 'package:job_finder_app/widgets/error_banner.dart';
import 'package:provider/provider.dart';

/// Stands in for Firebase so the navigation either side of a successful
/// call can be tested.
class FakeAuthService extends AuthService {
  FakeAuthService({this.failure, this.googleCancelled = false});

  /// When set, calls fail with this message instead of succeeding.
  final String? failure;

  /// Simulates the user closing the Google popup.
  final bool googleCancelled;

  bool signedUp = false;
  bool signedIn = false;
  bool googleAttempted = false;
  String? lastEmail;

  @override
  Future<bool> signInWithGoogle() async {
    googleAttempted = true;
    if (failure != null) throw AuthFailure(failure!);
    if (googleCancelled) return false;
    signedIn = true;
    return true;
  }

  @override
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (failure != null) throw AuthFailure(failure!);
    signedUp = true;
    lastEmail = email;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (failure != null) throw AuthFailure(failure!);
    signedIn = true;
    lastEmail = email;
  }
}

Widget wrap(FakeAuthService auth, Widget screen) {
  return Provider<AuthService>.value(
    value: auth,
    child: MaterialApp(
      theme: AppTheme.light(),
      // A root below the auth screens, standing in for the auth gate.
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
  );
}

Future<void> openScreen(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('successful sign-in leaves the auth screen', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(wrap(auth, const SignInScreen()));
    await openScreen(tester);

    expect(find.text('Welcome back'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ada@example.com');
    await tester.enterText(fields.at(1), 'analytical7');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.signedIn, isTrue);
    // The pushed screen must be popped, or the gate's view stays hidden
    // underneath it.
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('failed sign-in keeps the screen and shows the reason', (
    tester,
  ) async {
    final auth = FakeAuthService(failure: 'Incorrect email or password.');
    await tester.pumpWidget(wrap(auth, const SignInScreen()));
    await openScreen(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ada@example.com');
    await tester.enterText(fields.at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('Google sign-in leaves the auth screen', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(wrap(auth, const SignInScreen()));
    await openScreen(tester);

    final button = find.text('Continue with Google');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(auth.googleAttempted, isTrue);
    expect(auth.signedIn, isTrue);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('cancelling the Google popup is not treated as an error', (
    tester,
  ) async {
    final auth = FakeAuthService(googleCancelled: true);
    await tester.pumpWidget(wrap(auth, const SignInScreen()));
    await openScreen(tester);

    final button = find.text('Continue with Google');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(auth.googleAttempted, isTrue);
    expect(auth.signedIn, isFalse);
    // Still on the form, with no error shown.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(ErrorBanner), findsNothing);
  });

  testWidgets('a Google failure is reported on the form', (tester) async {
    final auth = FakeAuthService(
      failure: 'Your browser blocked the Google sign-in window.',
    );
    await tester.pumpWidget(wrap(auth, const SignInScreen()));
    await openScreen(tester);

    final button = find.text('Continue with Google');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      find.text('Your browser blocked the Google sign-in window.'),
      findsOneWidget,
    );
  });

  testWidgets('sign-up offers Google as an alternative to the form', (
    tester,
  ) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(wrap(auth, const SignUpScreen()));
    await openScreen(tester);

    final button = find.text('Sign up with Google');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(auth.googleAttempted, isTrue);
    // Google accounts go straight in: no form, no separate sign-in step.
    expect(find.text('Create your account'), findsNothing);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('sign-up hands over to sign-in with the email pre-filled', (
    tester,
  ) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(wrap(auth, const SignUpScreen()));
    await openScreen(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ada Lovelace');
    await tester.enterText(fields.at(1), 'ada@example.com');
    await tester.enterText(fields.at(2), 'analytical7');
    await tester.enterText(fields.at(3), 'analytical7');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(auth.signedUp, isTrue);
    // New accounts must land on sign-in, not inside the app.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
  });

  testWidgets('sign-up requires the terms checkbox', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(wrap(auth, const SignUpScreen()));
    await openScreen(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ada Lovelace');
    await tester.enterText(fields.at(1), 'ada@example.com');
    await tester.enterText(fields.at(2), 'analytical7');
    await tester.enterText(fields.at(3), 'analytical7');

    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(auth.signedUp, isFalse);
    expect(
      find.text('Please accept the Terms and Privacy Policy first.'),
      findsOneWidget,
    );
  });
}
