class Validators {
  // Prevent instantiation
  Validators._();

  /// Validate mobile number (basic check for 10 digits, with optional '+')
  static String? validateMobile(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mobile number cannot be empty.';
    }

    if (value.length != 10) {
      return 'Mobile number must be 10 digits.';
    }

    // Allow optional '+' prefix
    if (int.tryParse(value.startsWith('+') ? value.substring(1) : value) ==
        null) {
      return 'Mobile number must contain only digits (optionally led by a +).';
    }

    return null; // Valid
  }

  /// Validate non-empty field
  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName cannot be empty.';
    }
    return null; // Valid
  }

  /// Validate email address (basic regex)
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email cannot be empty.';
    }

    const pattern =
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    final regex = RegExp(pattern);

    if (!regex.hasMatch(value)) {
      return 'Enter a valid email address.';
    }

    return null; // Valid
  }

  /// Validate password (minimum 6 chars, can extend rules)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password cannot be empty.';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters long.';
    }

    // Optional additional checks:
    // if (!value.contains(RegExp(r'[A-Z]'))) {
    //   return 'Password must contain an uppercase letter.';
    // }
    // if (!value.contains(RegExp(r'[a-z]'))) {
    //   return 'Password must contain a lowercase letter.';
    // }
    // if (!value.contains(RegExp(r'[0-9]'))) {
    //   return 'Password must contain a digit.';
    // }
    // if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
    //   return 'Password must contain a special character.';
    // }

    return null; // Valid
  }
}
