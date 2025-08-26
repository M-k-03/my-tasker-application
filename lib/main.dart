import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // MODIFIED: Import Firebase Auth
import 'package:my_tasker/views/screens/menu_screen.dart';
import 'package:my_tasker/views/screens/login_screen.dart'; // MODIFIED: Import LoginScreen
import 'package:my_tasker/views/splash_screen.dart'; // IMPORT SplashScreen

Future<void> main() async { // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure widgets are initialized
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Tasker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.white,
      ),
      // MODIFIED: Use StreamBuilder to handle auth state
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen(); // Show splash screen while checking auth state
          } else if (snapshot.hasData) {
            return const MenuScreen(); // User is logged in, go to MenuScreen
          } else {
            return const LoginScreen(); // No user logged in, go to LoginScreen
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
