import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/applications_controller.dart';
import 'data/job_repository.dart';
import 'data/saved_jobs_controller.dart';
import 'data/resume_controller.dart';
import 'data/resume_storage.dart';
import 'data/saved_jobs_sync.dart';
import 'data/user_profile_controller.dart';
import 'data/user_profile_sync.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    // Without this the app would show a blank screen with the reason buried
    // in the console.
    startupError = error;
  }

  // Local storage has to be ready before the first frame, since the saved
  // jobs controller reads from it synchronously.
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (error) {
    startupError ??= error;
  }

  runApp(JobFinderApp(prefs: prefs, startupError: startupError));
}

class JobFinderApp extends StatelessWidget {
  const JobFinderApp({super.key, this.prefs, this.startupError});

  final SharedPreferences? prefs;
  final Object? startupError;

  @override
  Widget build(BuildContext context) {
    final storage = prefs;

    // Startup failed, so the providers below have nothing to build on; show
    // the reason instead of a blank page.
    if (startupError != null || storage == null) {
      return MaterialApp(
        title: 'Career Connect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: _StartupErrorScreen(
          error: startupError ?? 'Local storage is unavailable.',
        ),
      );
    }

    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<JobRepository>(create: (_) => JobRepository.create()),
        ChangeNotifierProvider<SavedJobsController>(
          create: (_) => SavedJobsController(
            storage,
            // Firebase failed to start, so there is nothing to sync with.
            sync: startupError == null ? FirestoreSavedJobsSync() : null,
          ),
        ),
        ChangeNotifierProvider<ApplicationsController>(
          create: (_) => ApplicationsController(storage),
        ),
        ChangeNotifierProvider<UserProfileController>(
          create: (_) => UserProfileController(
            storage,
            sync: startupError == null ? FirestoreUserProfileSync() : null,
          ),
        ),
        ChangeNotifierProvider<ResumeController>(
          create: (_) => ResumeController(
            storage: startupError == null ? FirestoreResumeStorage() : null,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Career Connect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AuthGate(),
      ),
    );
  }
}


class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 40, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Career Connect could not start',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
