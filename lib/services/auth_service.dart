import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userEmail', userData['email'] ?? '');
    await prefs.setString('userName', userData['name'] ?? '');
    await prefs.setInt('userId', userData['id'] ?? 0);
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) return null;

    return {
      'email': prefs.getString('userEmail') ?? '',
      'name': prefs.getString('userName') ?? '',
      'id': prefs.getInt('userId') ?? 0,
    };
  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
