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
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => const AddProductDetailsScreen(), // Navigate to AddProductDetailsScreen
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // To match native splash background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/images/app_logo.jpg',
              width: 130, // Adjust as needed
              height: 130, // Adjust as needed
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              'MyTasker',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme
                    .of(context)
                    .primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your Personal Task Manager',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
