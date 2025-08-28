import 'package:cloud_firestore/cloud_firestore.dart'; // Added for Firestore
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:my_tasker/utils/app_colors.dart';
import 'package:my_tasker/utils/validators.dart';
import 'package:my_tasker/views/screens/registration_screen.dart';
import 'package:my_tasker/views/screens/menu_screen.dart';
import 'package:my_tasker/views/widgets/custom_button.dart';
import 'package:my_tasker/views/widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _loginUser() async {
    if (_formKey.currentState?.validate() == false) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        // Check Firestore for shopId
        try {
          DocumentSnapshot shopkeeperDoc = await FirebaseFirestore.instance
              .collection('shopkeepers')
              .doc(user.uid)
              .get();

          if (shopkeeperDoc.exists) {
            // Safely access shopId
            Map<String, dynamic>? data = shopkeeperDoc.data() as Map<String, dynamic>?;
            String? shopId = data?['shopId'];

            if (shopId == null || shopId.isEmpty) {
              print("DEBUG_LOGIN: shopkeeperDoc exists, but shopId is missing or empty. UID: ${user.uid}"); // ADDED
              Fluttertoast.showToast(
                msg: "Please wait until the central admin assigns your shop ID.",
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.BOTTOM,
                backgroundColor: Colors.orange,
                textColor: Colors.white,
              );
              // Optional: Sign out if user shouldn't remain logged in without shopId
              // await FirebaseAuth.instance.signOut();
            } else {
              print("DEBUG_LOGIN: shopkeeperDoc exists, shopId found: $shopId. UID: ${user.uid}"); // ADDED
              // shopId is present, proceed to MenuScreen
              Fluttertoast.showToast(
                msg: "Login successful!",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                backgroundColor: Colors.green,
                textColor: Colors.white,
              );
              if (mounted) { // Inside the _loginUser method, within the 'if (shopId != null && shopId.isNotEmpty)' block
                print("DEBUG_LOGIN: Navigating to MenuScreen with shopId: $shopId. UID: ${user.uid}"); // REFINED
                Navigator
                    .of(context)
                    .pushReplacement( // or Navigator.pushReplacement if you prefer
                  MaterialPageRoute(
                      builder: (context) => MenuScreen(shopId: shopId)),
                );
              }
            }
          } else {
            print("DEBUG_LOGIN: shopkeeperDoc does NOT exist. UID: ${user.uid}"); // ADDED
            // Shopkeeper document doesn't exist
            Fluttertoast.showToast(
              msg: "User profile not found. Please contact support.",
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
             // Optional: Sign out user as their profile is incomplete/missing
            // await FirebaseAuth.instance.signOut();
          }
        } catch (e) { // Catch Firestore errors
          Fluttertoast.showToast(
            msg: "Error fetching user details: ${e.toString()}",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } else {
         Fluttertoast.showToast(
          msg: "Login failed: User authentication failed.", // More specific message
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else if (e.code == 'network-request-failed') {
        message = 'No internet connection. Please try again.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many login attempts. Please try again later.';
      } else {
        message = 'An error occurred: ${e.message}';
      }
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "An unexpected error occurred: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryColor.withOpacity(0.8), AppColors.borderColor.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Login',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  CustomTextField(
                    controller: _emailController,
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validateEmail, // Assuming Validators.validateEmail handles empty and format
                    prefixIcon: Icons.email,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordController,
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    obscureText: true,
                    validator: Validators.validatePassword, // Assuming Validators.validatePassword handles empty and strength
                    prefixIcon: Icons.lock,
                  ),
                  const SizedBox(height: 30),
                  CustomButton(
                    text: 'Login',
                    onPressed: _isLoading ? null : _loginUser,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                      );
                    },
                    child: Text(
                      'Don\'t have an account? Go to Register',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
