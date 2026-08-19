/// Form validators shared by the auth screens.
class Validators {
  const Validators._();

  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? name(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Please enter your full name';
    if (input.length < 2) return 'That name looks too short';
    return null;
  }

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Please enter your email';
    if (!_emailPattern.hasMatch(input)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return 'Please enter a password';
    if (input.length < 8) return 'Use at least 8 characters';
    if (!input.contains(RegExp(r'[A-Za-z]'))) {
      return 'Include at least one letter';
    }
    if (!input.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? signInPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    return null;
  }
}
