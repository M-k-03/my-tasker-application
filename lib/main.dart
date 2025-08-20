import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:my_tasker/views/screens/menu_screen.dart';
// import 'views/screens/menu_screen.dart'; // No longer the first screen
import 'views/splash_screen.dart'; // IMPORT SplashScreen

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
      home: const MenuScreen(), // Replace with your first screen
      debugShowCheckedModeBanner: false,
    );
  }
}
