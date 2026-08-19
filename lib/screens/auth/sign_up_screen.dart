import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/google_sign_in_button.dart';
import 'sign_in_screen.dart';

/// Account creation screen: full name, email and password, backed by
/// Firebase email/password auth.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _acceptedTerms = false;
  bool _submitting = false;
  bool _googleSubmitting = false;
  String? _errorMessage;

  bool get _busy => _submitting || _googleSubmitting;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (!_acceptedTerms) {
      setState(() {
        _errorMessage = 'Please accept the Terms and Privacy Policy first.';
      });
      return;
    }

    final authService = context.read<AuthService>();

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await authService.signUp(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created. Check your email to verify it, then sign in.',
          ),
        ),
      );
      // Replace this screen with sign-in, email pre-filled, so the new user
      // logs in deliberately instead of being dropped into the app.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SignInScreen(initialEmail: _emailController.text),
        ),
      );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Google accounts skip the form entirely — Google supplies the name and a
  /// verified email, so there is nothing left to collect.
  Future<void> _signUpWithGoogle() async {
    if (_busy) return;

    final authService = context.read<AuthService>();

    setState(() {
      _googleSubmitting = true;
      _errorMessage = null;
    });

    try {
      final signedIn = await authService.signInWithGoogle();
      if (!mounted || !signedIn) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _googleSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScaffold(
      title: 'Create your account',
      subtitle:
          'Set up a profile to apply for jobs and track every '
          'application in one place.',
      showBackButton: Navigator.of(context).canPop(),
      builder: (context, d) => Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                SizedBox(height: d.sectionGap),
              ],
              AppTextField(
                controller: _nameController,
                label: 'Full name',
                hint: 'Ada Lovelace',
                prefixIcon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                enabled: !_submitting,
                validator: Validators.name,
                verticalPadding: d.fieldPadding,
                labelGap: d.labelGap,
              ),
              SizedBox(height: d.fieldGap),
              AppTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'you@example.com',
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: !_submitting,
                validator: Validators.email,
                verticalPadding: d.fieldPadding,
                labelGap: d.labelGap,
              ),
              SizedBox(height: d.fieldGap),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'At least 8 characters',
                prefixIcon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                enabled: !_submitting,
                validator: Validators.password,
                verticalPadding: d.fieldPadding,
                labelGap: d.labelGap,
              ),
              SizedBox(height: d.fieldGap),
              AppTextField(
                controller: _confirmController,
                label: 'Confirm password',
                hint: 'Re-enter your password',
                prefixIcon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                enabled: !_submitting,
                validator: (value) =>
                    Validators.confirmPassword(value, _passwordController.text),
                onSubmitted: (_) => _submit(),
                verticalPadding: d.fieldPadding,
                labelGap: d.labelGap,
              ),
              SizedBox(height: d.fieldGap),
              _TermsCheckbox(
                value: _acceptedTerms,
                enabled: !_submitting,
                compact: d.compact,
                onChanged: (value) =>
                    setState(() => _acceptedTerms = value ?? false),
              ),
              SizedBox(height: d.sectionGap),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: d.filledButtonStyle,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Create account'),
              ),
              SizedBox(height: d.sectionGap),
              const OrDivider(),
              SizedBox(height: d.sectionGap),
              GoogleSignInButton(
                label: 'Sign up with Google',
                busy: _googleSubmitting,
                height: d.controlHeight,
                onPressed: _busy ? null : _signUpWithGoogle,
              ),
              SizedBox(height: d.compact ? d.blockGap : d.sectionGap),
              // On a short screen the prompt and the link cannot share a line
              // on narrow phones, and a wrapped footer costs a whole row, so
              // it collapses to the link alone.
              if (d.compact)
                Center(
                  child: TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      minimumSize: Size(0, d.rowHeight),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Sign in instead'),
                  ),
                )
              else
                // Wrap rather than Row: on narrow phones the label and the
                // button do not fit on one line.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      style: TextButton.styleFrom(
                        minimumSize: Size(0, d.rowHeight),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.enabled,
    required this.compact,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final bool compact;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: value,
          onChanged: enabled ? onChanged : null,
          // The default 48px tap target is the tallest thing in this row.
          visualDensity: compact ? VisualDensity.compact : null,
          materialTapTargetSize: compact
              ? MaterialTapTargetSize.shrinkWrap
              : null,
        ),
        if (compact) const SizedBox(width: AppSpacing.base),
        Expanded(
          child: GestureDetector(
            onTap: enabled ? () => onChanged(!value) : null,
            child: Text(
              'I agree to the Terms of Service and Privacy Policy.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
