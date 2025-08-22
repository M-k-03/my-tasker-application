class Validators {
  // Prevent instantiation
  Validators._();

  static String? validateMobile(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mobile number cannot be empty.';
    }
    // Basic check for 10 digits - adjust regex or logic for specific country codes/formats
    if (value.length != 10) {
      return 'Mobile number must be 10 digits.';
    }
    if (int.tryParse(value) == null) {
      return 'Mobile number must contain only digits.';
    }
    return null; // Valid
  }

  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName cannot be empty.';
    }
    return null; // Valid
  }

  // You can add other validators here, e.g.:
  // static String? validateEmail(String? value) { ... }
  // static String? validatePassword(String? value) { ... }
}
