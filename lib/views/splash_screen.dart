import 'dart:async';
import 'package:flutter/material.dart';
import 'add_details_screen.dart'; // Changed import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print("DEBUG: SplashScreen initState CALLED");
    // Timer(const Duration(seconds: 3), () {
    //   Navigator.of(context).pushReplacement(MaterialPageRoute(
    //     builder: (_) => const AddProductDetailsScreen(), // Navigate to AddProductDetailsScreen
    //   ));
    // });
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG: SplashScreen build CALLED"); // For logging
    return const Scaffold(
      backgroundColor: Colors.redAccent, // VERY OBVIOUS BACKGROUND
      body: Center(
        child: Text(
          'SPLASH SCREEN IS HERE!',
          style: TextStyle(
            fontSize: 30,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

}
