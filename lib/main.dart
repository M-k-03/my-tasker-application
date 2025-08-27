import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_tasker/views/screens/menu_screen.dart';
import 'package:my_tasker/views/screens/login_screen.dart';
import 'package:my_tasker/views/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          print("Main.dart: Auth state changed. ConnectionState: ${authSnapshot.connectionState}, HasData: ${authSnapshot.hasData}, Error: ${authSnapshot.hasError}");

          if (authSnapshot.connectionState == ConnectionState.waiting) {
            print("Main.dart: Auth state waiting. Showing SplashScreen.");
            return const SplashScreen();
          }

          if (authSnapshot.hasError) {
            print("Main.dart: Auth stream error: ${authSnapshot.error}. Showing LoginScreen.");
            // Optionally, show a generic error screen or just LoginScreen
            return const LoginScreen();
          }

          if (authSnapshot.hasData) {
            final User? user = authSnapshot.data;
            if (user == null || user.email == null) {
              print("Main.dart: User is null or user email is null after authSnapshot.hasData. Showing LoginScreen.");
              return const LoginScreen();
            }
            print("Main.dart: User authenticated: ${user.email} (UID: ${user.uid}). Fetching shopkeeper details.");

            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('shopkeepers')
                  .where('email', isEqualTo: user.email) // Assuming 'email' field in shopkeepers
                  .limit(1)
                  .get(),
              builder: (context, shopkeeperSnapshot) {
                print("Main.dart: Shopkeeper fetch. ConnectionState: ${shopkeeperSnapshot.connectionState}, HasData: ${shopkeeperSnapshot.hasData}, HasError: ${shopkeeperSnapshot.hasError}");

                if (shopkeeperSnapshot.connectionState == ConnectionState.waiting) {
                  print("Main.dart: Shopkeeper fetch waiting. Showing SplashScreen.");
                  return const SplashScreen();
                }

                if (shopkeeperSnapshot.hasError) {
                  print("Main.dart: Error fetching shopkeeper: ${shopkeeperSnapshot.error}. Showing LoginScreen.");
                  // Optionally, show a more specific error message or fallback to LoginScreen
                  return const LoginScreen(); // Fallback for safety
                }

                if (!shopkeeperSnapshot.hasData || shopkeeperSnapshot.data!.docs.isEmpty) {
                  print("Main.dart: No shopkeeper document found for email: ${user.email}. Showing LoginScreen.");
                  // This means the authenticated user isn't in the shopkeepers collection
                  // or doesn't have an email match.
                  return const LoginScreen();
                }

                // Shopkeeper document found
                final shopkeeperDoc = shopkeeperSnapshot.data!.docs.first;
                final String? shopId = shopkeeperDoc.data().toString().contains('shopId') ? shopkeeperDoc.get('shopId') as String? : null;
                // final String? shopId = shopkeeperDoc.get('shopId') as String?; // More direct, if 'shopId' always exists

                print("Main.dart: Shopkeeper doc found. Extracted shopId: $shopId");

                if (shopId != null && shopId.isNotEmpty) {
                  print("Main.dart: Valid shopId '$shopId' found. Navigating to MenuScreen.");
                  return MenuScreen(shopId: shopId);
                } else {
                  print("Main.dart: shopId is null or empty from shopkeeper doc for ${user.email}. Showing LoginScreen.");
                  // Authenticated user is in shopkeepers collection but doesn't have a valid shopId.
                  return const LoginScreen();
                }
              },
            );
          } else {
            print("Main.dart: No authenticated user (authSnapshot.hasData is false). Showing LoginScreen.");
            return const LoginScreen();
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}