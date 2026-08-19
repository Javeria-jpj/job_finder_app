import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/applications_controller.dart';
import '../../data/resume_controller.dart';
import '../../data/saved_jobs_controller.dart';
import '../../data/user_profile_controller.dart';
import '../../models/job_application.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/set_password_dialog.dart';
import '../jobs/saved_jobs_screen.dart';
import 'account_settings_screen.dart';
import 'job_preferences_screen.dart';
import 'resume_screen.dart';

/// Account screen: identity, activity stats, availability, settings list.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthService _authService = context.read<AuthService>();

  bool _openToWork = false;

  /// Google-only accounts have no password, so email sign-in would fail for
  /// them. This links one to the same account.
  Future<void> _setPassword() async {
    final email = _authService.currentUser?.email ?? '';

    final added = await showDialog<bool>(
      context: context,
      builder: (_) => SetPasswordDialog(
        email: email,
        onSubmit: (password) => _authService.linkEmailPassword(password),
      ),
    );

    if (!mounted || added != true) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password set. You can now sign in with email too.'),
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to apply.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _authService.currentUser;
    final applications = context.watch<ApplicationsController>();
    final savedCount = context.watch<SavedJobsController>().count;
    final profile = context.watch<UserProfileController>().profile;
    final resume = context.watch<ResumeController>().resume;

    final name = user?.displayName?.trim();
    final displayName = (name == null || name.isEmpty) ? 'Your profile' : name;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BrandHeader(),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.gutter,
                      AppSpacing.gutter,
                      AppSpacing.md,
                    ),
                    children: [
                      AppCard(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.primaryFixed,
                              child: Text(
                                _initials(displayName),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              displayName,
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              user?.email ?? '',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      AppCard(
                        child: Row(
                          children: [
                            _Stat(
                              value: '${applications.count}',
                              label: 'APPLICATIONS',
                            ),
                            const _StatDivider(),
                            _Stat(
                              value:
                                  '${applications.stageCount(ApplicationStage.interviewing)}',
                              label: 'INTERVIEWS',
                            ),
                            const _StatDivider(),
                            _Stat(value: '$savedCount', label: 'SAVED'),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ready for a new challenge?',
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Update your status to let recruiters '
                                    'know.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _OpenToWorkButton(
                              active: _openToWork,
                              onPressed: () =>
                                  setState(() => _openToWork = !_openToWork),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      AppCard(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.base,
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.base,
                                AppSpacing.md,
                                AppSpacing.sm,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Profile Details',
                                  style: theme.textTheme.headlineSmall,
                                ),
                              ),
                            ),
                            const Divider(),
                            _DetailRow(
                              icon: Icons.description_outlined,
                              title: 'My Resume',
                              subtitle: resume == null
                                  ? 'Upload a PDF or Word document.'
                                  : resume.name,
                              onTap: () => _open(const ResumeScreen()),
                            ),
                            const Divider(indent: AppSpacing.md),
                            _DetailRow(
                              icon: Icons.tune,
                              title: 'Job Preferences',
                              subtitle: profile.hasPreferences
                                  ? _preferencesSummary(profile)
                                  : 'Set location, industry and salary '
                                        'expectations.',
                              onTap: () => _open(const JobPreferencesScreen()),
                            ),
                            const Divider(indent: AppSpacing.md),
                            _DetailRow(
                              icon: Icons.bookmark_border,
                              title: 'Saved Jobs',
                              subtitle:
                                  'Review opportunities you have bookmarked.',
                              trailingLabel: '$savedCount',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SavedJobsScreen(),
                                ),
                              ),
                            ),
                            const Divider(indent: AppSpacing.md),
                            if (!_authService.hasPasswordProvider)
                              _DetailRow(
                                icon: Icons.password,
                                title: 'Set a password',
                                subtitle:
                                    'You signed in with Google. Add a '
                                    'password to also sign in by email.',
                                onTap: _setPassword,
                              )
                            else
                              _DetailRow(
                                icon: Icons.settings_outlined,
                                title: 'Account Settings',
                                subtitle:
                                    'Manage password, notifications and '
                                    'privacy.',
                                onTap: () =>
                                    _open(const AccountSettingsScreen()),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Sign Out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            minimumSize: const Size(200, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One line describing what the user has already set, so the row is not
  /// still inviting them to do something they have done.
  static String _preferencesSummary(UserProfile profile) {
    final parts = [
      if (profile.desiredRole.isNotEmpty) profile.desiredRole,
      if (profile.remoteOnly)
        'Remote'
      else if (profile.location.isNotEmpty)
        profile.location,
      if (profile.industry.isNotEmpty) profile.industry,
    ];
    return parts.isEmpty ? 'Tap to review.' : parts.join(' · ');
  }

  static String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 40, width: 1, color: AppColors.outlineVariant);
  }
}

class _OpenToWorkButton extends StatelessWidget {
  const _OpenToWorkButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: active ? AppColors.secondary : AppColors.primary,
        minimumSize: const Size(120, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
      child: Text(active ? 'Open to Work' : 'Set Status'),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.gutter,
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.secondary),
            ),
            const SizedBox(width: AppSpacing.gutter),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            if (trailingLabel != null) ...[
              Text(trailingLabel!, style: theme.textTheme.labelLarge),
              const SizedBox(width: AppSpacing.base),
            ],
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
