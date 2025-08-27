import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_tasker/utils/app_colors.dart'; // Import AppColors
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withOpacity(0.8),
            AppColors.borderColor.withOpacity(0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Scaffold(
        backgroundColor: Colors.transparent, // Make Scaffold background transparent
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}
