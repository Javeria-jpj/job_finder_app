import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/data/user_profile_controller.dart';
import 'package:job_finder_app/models/user_profile.dart';
import 'package:job_finder_app/screens/profile/account_settings_screen.dart';
import 'package:job_finder_app/screens/profile/job_preferences_screen.dart';
import 'package:job_finder_app/services/auth_service.dart';
import 'package:job_finder_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signed-out stand-in: the real getters reach for FirebaseAuth.instance.
class _OfflineAuthService extends AuthService {
  @override
  User? get currentUser => null;

  @override
  Set<String> get providerIds => const {};
}

void main() {
  late UserProfileController profiles;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    profiles = UserProfileController(prefs)..loadFor('user-1');
  });

  Widget wrap(Widget screen) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => _OfflineAuthService()),
        ChangeNotifierProvider<UserProfileController>.value(value: profiles),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: screen),
    );
  }

  /// Role, location and salary, in the order they appear.
  Finder fieldAt(int index) => find.byType(TextFormField).at(index);

  /// Taller than the 800x600 default so the whole form is on screen; the
  /// text fields are scrollables too, so scrollUntilVisible cannot pick one.
  Future<void> pumpTall(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(screen));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
  }

  testWidgets('job preferences saves what was entered', (tester) async {
    await pumpTall(tester, const JobPreferencesScreen());

    await tester.enterText(fieldAt(0), 'Backend Engineer');
    await tester.enterText(fieldAt(1), 'Karachi');
    await tester.enterText(fieldAt(2), '200000');
    await tapSave(tester);

    expect(profiles.profile.desiredRole, 'Backend Engineer');
    expect(profiles.profile.location, 'Karachi');
    expect(profiles.profile.minSalary, 200000);
  });

  testWidgets('the salary field refuses anything but digits', (tester) async {
    await pumpTall(tester, const JobPreferencesScreen());

    await tester.enterText(fieldAt(2), 'a lot');
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(profiles.profile.minSalary, isNull);
  });

  testWidgets('clearing the salary removes it', (tester) async {
    await profiles.save(const UserProfile(minSalary: 90000));

    await pumpTall(tester, const JobPreferencesScreen());

    await tester.enterText(fieldAt(2), '');
    await tapSave(tester);

    expect(profiles.profile.minSalary, isNull);
  });

  testWidgets('an existing profile pre-fills the form', (tester) async {
    await profiles.save(
      const UserProfile(desiredRole: 'Designer', minSalary: 90000),
    );

    await pumpTall(tester, const JobPreferencesScreen());

    expect(find.text('Designer'), findsOneWidget);
    expect(find.text('90000'), findsOneWidget);
  });

  testWidgets('account settings toggles are stored on the profile', (
    tester,
  ) async {
    await pumpTall(tester, const AccountSettingsScreen());

    expect(profiles.profile.jobAlerts, isTrue);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Job alerts'));
    await tester.pumpAndSettle();

    expect(profiles.profile.jobAlerts, isFalse);
  });
}
