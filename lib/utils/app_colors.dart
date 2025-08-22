import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation
  AppColors._();

  // Define your primary color
  // Using a common shade of blue as an example.
  // You can change this to any color you prefer.
  static const Color primaryColor = Colors.blue;
  static const Color textColor = Colors.black; // Added textColor

  // Added based on new errors from custom_text_field.dart
  static const Color borderColor = Colors.grey; // Placeholder, adjust as needed
  static const Color textFieldFillColor = Color(0xFFF0F0F0); // Placeholder light grey, adjust as needed
  static const Color primaryTextColor = Colors.black; // Placeholder, adjust as needed

  // You can add other theme colors here if needed
  // static const Color accentColor = Colors.amber;
  // static const Color backgroundColor = Colors.white;
}
