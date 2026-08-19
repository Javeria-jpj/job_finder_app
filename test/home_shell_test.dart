import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/data/applications_controller.dart';
import 'package:job_finder_app/data/job_repository.dart';
import 'package:job_finder_app/data/sample_job_repository.dart';
import 'package:job_finder_app/data/resume_controller.dart';
import 'package:job_finder_app/models/resume_file.dart';
import 'package:job_finder_app/services/resume_picker.dart';
import 'package:job_finder_app/data/saved_jobs_controller.dart';
import 'package:job_finder_app/data/user_profile_controller.dart';
import 'package:job_finder_app/screens/home_screen.dart';
import 'package:job_finder_app/services/auth_service.dart';
import 'package:job_finder_app/theme/app_theme.dart';
import 'package:job_finder_app/widgets/app_logo.dart';
import 'package:job_finder_app/widgets/brand_header.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signed-out stand-in: the real getters reach for FirebaseAuth.instance,
/// which does not exist in a test.
class _OfflineAuthService extends AuthService {
  @override
  User? get currentUser => null;

  @override
  Set<String> get providerIds => const {};
}

void main() {
  late SavedJobsController saved;
  late ApplicationsController applications;
  late UserProfileController profiles;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    saved = SavedJobsController(prefs)..loadFor('user-1');
    applications = ApplicationsController(prefs)..loadFor('user-1');
    profiles = UserProfileController(prefs)..loadFor('user-1');
  });

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthService>(create: (_) => _OfflineAuthService()),
          Provider<JobRepository>(create: (_) => SampleJobRepository()),
          ChangeNotifierProvider<SavedJobsController>.value(value: saved),
          ChangeNotifierProvider<ApplicationsController>.value(
            value: applications,
          ),
          ChangeNotifierProvider<UserProfileController>.value(value: profiles),
          ChangeNotifierProvider<ResumeController>(
            create: (_) => ResumeController(picker: _NoPicker()),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('wide layout uses a narrow rail with the full logo', (
    tester,
  ) async {
    await pumpShell(tester, const Size(1280, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // The rail sizes itself to its widest label unless it is constrained, and
    // "Applications" made it nearly twice this wide.
    expect(tester.getSize(find.byType(NavigationRail)).width, 112.0);

    // The wordmark shows here, so the header does not repeat the logo.
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Applications'), findsOneWidget);
  });

  testWidgets('narrow layout uses the bottom bar', (tester) async {
    await pumpShell(tester, const Size(420, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('narrow layout shows the mark in the header instead', (
    tester,
  ) async {
    await pumpShell(tester, const Size(420, 800));

    // There is no rail to carry the logo here, so the header does — but only
    // once. IndexedStack keeps every tab alive, so several headers exist;
    // only the visible one is checked.
    final header = find.descendant(
      of: find.byType(BrandHeader).first,
      matching: find.byType(AppLogo),
    );
    expect(header, findsOneWidget);
    expect(find.text('Career Connect'), findsWidgets);
  });

  testWidgets('wide layout keeps the logo out of the header', (tester) async {
    await pumpShell(tester, const Size(1280, 800));

    expect(
      find.descendant(
        of: find.byType(BrandHeader).first,
        matching: find.byType(AppLogo),
      ),
      findsNothing,
      reason: 'the rail already shows it',
    );
  });
}

/// The profile tab builds inside HomeScreen, so a controller is needed even
/// though nothing in these tests opens the resume screen.
class _NoPicker implements ResumePicker {
  @override
  Future<ResumeFile?> pick() async => null;

  @override
  Future<bool> save(ResumeFile file) async => false;
}
