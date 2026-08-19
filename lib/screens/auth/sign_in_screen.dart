import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/google_sign_in_button.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// Email/password sign-in screen, and the entry point for new users on their
/// way to [SignUpScreen].
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.initialEmail = ''});

  /// Pre-filled after sign-up, so the new account does not retype it.
  final String initialEmail;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _googleSubmitting = false;
  String? _errorMessage;

  bool get _busy => _submitting || _googleSubmitting;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final authService = context.read<AuthService>();

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      // This screen was pushed on top of the auth gate, so the gate swapping
      // in the signed-in view happens *underneath* it. Pop back to reveal it.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_submitting) return;

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

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to pick up your job search where you left off.',
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
                hint: 'Enter your password',
                prefixIcon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !_submitting,
                validator: Validators.signInPassword,
                onSubmitted: (_) => _submit(),
                verticalPadding: d.fieldPadding,
                labelGap: d.labelGap,
              ),
              SizedBox(height: d.compact ? 2 : 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => _open(
                          ForgotPasswordScreen(
                            initialEmail: _emailController.text,
                          ),
                        ),
                  style: TextButton.styleFrom(
                    minimumSize: Size(0, d.rowHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
              SizedBox(height: d.blockGap),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: d.filledButtonStyle,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Sign in'),
              ),
              SizedBox(height: d.sectionGap),
              const OrDivider(),
              SizedBox(height: d.sectionGap),
              GoogleSignInButton(
                busy: _googleSubmitting,
                height: d.controlHeight,
                onPressed: _busy ? null : _signInWithGoogle,
              ),
              SizedBox(height: d.sectionGap),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'New to Career Connect?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              SizedBox(height: d.blockGap),
              OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => _open(const SignUpScreen()),
                style: d.outlinedButtonStyle,
                child: const Text('Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
