import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/user_profile_controller.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/set_password_dialog.dart';

/// Sign-in methods and notification choices.
///
/// Sign-in lives in Firebase Auth; the switches live with the rest of the
/// profile. Nothing here needs a backend the app does not already have.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late final AuthService _authService = context.read<AuthService>();

  Future<void> _changePassword() async {
    final hasPassword = _authService.hasPasswordProvider;
    final email = _authService.currentUser?.email ?? '';

    final done = await showDialog<bool>(
      context: context,
      builder: (_) => SetPasswordDialog(
        email: email,
        title: hasPassword ? 'Change password' : 'Set a password',
        description: hasPassword
            ? 'Choose a new password for this account.'
            : 'Add a password so you can sign in with your email as well as '
                  'Google.',
        // Linking adds a password to a Google-only account; updating replaces
        // an existing one. Same dialog, different call.
        onSubmit: hasPassword
            ? _authService.updatePassword
            : _authService.linkEmailPassword,
      ),
    );

    if (!mounted || done != true) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hasPassword ? 'Password changed.' : 'Password set.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<UserProfileController>();
    final profile = controller.profile;

    final user = _authService.currentUser;
    final providers = _authService.providerIds;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sign-in', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        user?.email ?? 'No email on this account',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.base,
                        children: [
                          if (providers.contains('password'))
                            const _MethodChip(
                              icon: Icons.password,
                              label: 'Email and password',
                            ),
                          if (providers.contains('google.com'))
                            const _MethodChip(
                              icon: Icons.account_circle_outlined,
                              label: 'Google',
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      OutlinedButton(
                        onPressed: _changePassword,
                        child: Text(
                          _authService.hasPasswordProvider
                              ? 'Change password'
                              : 'Set a password',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.gutter),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.base,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.base,
                        ),
                        child: Text(
                          'Notifications',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      SwitchListTile(
                        value: profile.jobAlerts,
                        onChanged: (value) =>
                            controller.save(profile.copyWith(jobAlerts: value)),
                        title: const Text('Job alerts'),
                        subtitle: const Text(
                          'New roles that match your preferences.',
                        ),
                      ),
                      SwitchListTile(
                        value: profile.applicationUpdates,
                        onChanged: (value) => controller.save(
                          profile.copyWith(applicationUpdates: value),
                        ),
                        title: const Text('Application updates'),
                        subtitle: const Text(
                          'Progress on roles you have applied to.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.gutter),
                AppCard(
                  color: AppColors.surfaceContainerHigh,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'These preferences are stored on your account. '
                          'Actually delivering notifications would need '
                          'Firebase Cloud Messaging.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: AppColors.secondary),
      label: Text(label),
      backgroundColor: AppColors.primaryFixed,
      side: BorderSide.none,
    );
  }
}
