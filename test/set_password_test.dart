import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/services/auth_service.dart';
import 'package:job_finder_app/theme/app_theme.dart';
import 'package:job_finder_app/widgets/set_password_dialog.dart';

Future<bool?> showPasswordDialog(
  WidgetTester tester,
  Future<void> Function(String password) onSubmit,
) async {
  bool? result;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => SetPasswordDialog(
                    email: 'ada@example.com',
                    onSubmit: onSubmit,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('shows the account the password will belong to', (tester) async {
    await showPasswordDialog(tester, (_) async {});

    expect(find.text('Set a password'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
  });

  testWidgets('rejects a weak password before calling the action', (
    tester,
  ) async {
    var called = false;
    await showPasswordDialog(tester, (_) async => called = true);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'short');
    await tester.enterText(fields.at(1), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('rejects a mismatched confirmation', (tester) async {
    var called = false;
    await showPasswordDialog(tester, (_) async => called = true);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'analytical7');
    await tester.enterText(fields.at(1), 'analytical8');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('passes a valid password to the action and closes', (
    tester,
  ) async {
    String? received;
    await showPasswordDialog(tester, (password) async => received = password);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'analytical7');
    await tester.enterText(fields.at(1), 'analytical7');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(received, 'analytical7');
    expect(find.text('Set a password'), findsNothing, reason: 'dialog closed');
  });

  testWidgets('keeps the dialog open and shows why linking failed', (
    tester,
  ) async {
    await showPasswordDialog(
      tester,
      (_) async => throw const AuthFailure(
        'This account already has a '
        'password.',
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'analytical7');
    await tester.enterText(fields.at(1), 'analytical7');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('This account already has a password.'), findsOneWidget);
    expect(find.text('Set a password'), findsOneWidget, reason: 'stays open');
  });
}
