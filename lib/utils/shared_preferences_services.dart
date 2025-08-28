import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static const String _kUserEmailKey = 'user_email';

  // Saves the user's email
  Future<void> saveUserEmail(String email) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserEmailKey, email);
  }

  // Retrieves the user's email
  Future<String?> getUserEmail() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserEmailKey);
  }

  // Clears the stored login details (currently just email)
  Future<void> clearLoginDetails() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserEmailKey);
    // You can add more keys to remove if you store other details
  }
}