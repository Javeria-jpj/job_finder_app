import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/screens/auth/sign_up_screen.dart';
import 'package:job_finder_app/services/auth_service.dart';
import 'package:job_finder_app/utils/validators.dart';
import 'package:provider/provider.dart';

void main() {
  group('Validators', () {
    test('rejects malformed emails', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('ada@example.com'), isNull);
    });

    test('requires a password with letters, digits and 8+ characters', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('alllettershere'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('analytical7'), isNull);
    });

    test('confirmation must match the original password', () {
      expect(Validators.confirmPassword('abc', 'abd'), isNotNull);
      expect(Validators.confirmPassword('abc', 'abc'), isNull);
    });
  });

  testWidgets('sign up form reports empty fields instead of submitting', (
    tester,
  ) async {
    await tester.pumpWidget(
      Provider<AuthService>(
        create: (_) => AuthService(),
        child: const MaterialApp(home: SignUpScreen()),
      ),
    );

    expect(find.text('Create your account'), findsOneWidget);

    final submitButton = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text('Please enter your full name'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter a password'), findsOneWidget);
  });
}
