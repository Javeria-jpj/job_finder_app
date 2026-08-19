import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/user_profile_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/error_banner.dart';

/// What the user is looking for. Stored on the account, so it follows them.
class JobPreferencesScreen extends StatefulWidget {
  const JobPreferencesScreen({super.key});

  @override
  State<JobPreferencesScreen> createState() => _JobPreferencesScreenState();
}

class _JobPreferencesScreenState extends State<JobPreferencesScreen> {
  final _formKey = GlobalKey<FormState>();

  late final UserProfileController _controller = context
      .read<UserProfileController>();

  late final _roleController = TextEditingController(
    text: _controller.profile.desiredRole,
  );
  late final _locationController = TextEditingController(
    text: _controller.profile.location,
  );
  late final _salaryController = TextEditingController(
    text: _controller.profile.minSalary?.toString() ?? '',
  );

  late String? _industry = _industryOrNull(_controller.profile.industry);
  late bool _remoteOnly = _controller.profile.remoteOnly;

  bool _saving = false;

  static const List<String> _industries = [
    'Engineering',
    'Design',
    'Marketing',
    'Finance',
    'Sales',
    'Healthcare',
    'Education',
    'Other',
  ];

  /// A value stored by an older build might not be in the list any more, and
  /// DropdownButton throws if its value is not among its items.
  static String? _industryOrNull(String value) =>
      _industries.contains(value) ? value : null;

  @override
  void dispose() {
    _roleController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final salary = _salaryController.text.trim();
    await _controller.save(
      _controller.profile.copyWith(
        desiredRole: _roleController.text.trim(),
        location: _locationController.text.trim(),
        industry: _industry ?? '',
        minSalary: salary.isEmpty ? null : int.tryParse(salary),
        clearMinSalary: salary.isEmpty,
        remoteOnly: _remoteOnly,
      ),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Preferences saved.')));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncError = context.watch<UserProfileController>().syncError;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Preferences')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: [
                  if (syncError != null) ...[
                    ErrorBanner(message: syncError),
                    const SizedBox(height: AppSpacing.gutter),
                  ],
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'What are you looking for?',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.gutter),
                        AppTextField(
                          controller: _roleController,
                          label: 'Desired role',
                          hint: 'Flutter Developer',
                          prefixIcon: Icons.work_outline,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          enabled: !_saving,
                        ),
                        const SizedBox(height: AppSpacing.gutter),
                        AppTextField(
                          controller: _locationController,
                          label: 'Preferred location',
                          hint: 'Lahore, or anywhere',
                          prefixIcon: Icons.place_outlined,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          enabled: !_saving,
                        ),
                        const SizedBox(height: AppSpacing.gutter),
                        Text(
                          'Industry',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _industry,
                          isExpanded: true,
                          hint: const Text('Pick one'),
                          items: [
                            for (final industry in _industries)
                              DropdownMenuItem(
                                value: industry,
                                child: Text(industry),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _industry = value),
                        ),
                        const SizedBox(height: AppSpacing.gutter),
                        AppTextField(
                          controller: _salaryController,
                          label: 'Minimum salary (optional)',
                          hint: '150000',
                          prefixIcon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          enabled: !_saving,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            return int.tryParse(text) == null
                                ? 'Enter a number, or leave it blank'
                                : null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gutter),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base,
                      vertical: AppSpacing.xs,
                    ),
                    child: SwitchListTile(
                      value: _remoteOnly,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _remoteOnly = value),
                      title: const Text('Remote roles only'),
                      subtitle: const Text(
                        'Hide roles that require being on-site.',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Text('Save preferences'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
