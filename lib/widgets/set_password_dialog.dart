import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'app_text_field.dart';
import 'error_banner.dart';

/// Collects a new password and hands it to [onSubmit].
///
/// Deliberately free of Firebase: the caller supplies the action, which keeps
/// the dialog testable and reusable for "set" and "change" alike.
class SetPasswordDialog extends StatefulWidget {
  const SetPasswordDialog({
    super.key,
    required this.email,
    required this.onSubmit,
    this.title = 'Set a password',
    this.description =
        'Add a password so you can sign in with your email as well as '
        'Google.',
  });

  final String email;

  /// Throws with a user-facing message when it fails.
  final Future<void> Function(String password) onSubmit;

  final String title;
  final String description;

  @override
  State<SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<SetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(_passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.email,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.gutter),
                if (_errorMessage != null) ...[
                  ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.gutter),
                ],
                AppTextField(
                  controller: _passwordController,
                  label: 'New password',
                  hint: 'At least 8 characters',
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.next,
                  validator: Validators.password,
                ),
                const SizedBox(height: AppSpacing.gutter),
                AppTextField(
                  controller: _confirmController,
                  label: 'Confirm password',
                  hint: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.done,
                  validator: (value) => Validators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
