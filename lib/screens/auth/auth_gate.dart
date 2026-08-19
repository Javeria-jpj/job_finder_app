import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/applications_controller.dart';
import '../../data/resume_controller.dart';
import '../../data/saved_jobs_controller.dart';
import '../../data/user_profile_controller.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';
import '../onboarding/onboarding_screen.dart';

/// Decides what the user sees based on the Firebase auth state: onboarding
/// when signed out, the app when signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.read<AuthService>().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // Load this account's data after the current build completes, since
        // both controllers notify their listeners.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.read<SavedJobsController>().loadFor(user?.uid);
          context.read<ApplicationsController>().loadFor(user?.uid);
          context.read<UserProfileController>().loadFor(user?.uid);
          context.read<ResumeController>().loadFor(user?.uid);
        });

        if (user == null) return const OnboardingScreen();
        return const HomeScreen();
      },
    );
  }
}
