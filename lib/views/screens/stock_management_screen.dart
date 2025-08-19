import 'package:flutter/material.dart';
import 'package:my_tasker/views/screens/purchase_entry_screen.dart'; // Import the PurchaseEntryScreen
import 'package:my_tasker/views/screens/purchase_history_screen.dart'; // Import PurchaseHistoryScreen
import 'package:my_tasker/views/screens/edit_delete_purchase_entry_screen.dart'; // Import the new placeholder screen

class StockManagementScreen extends StatelessWidget {
  const StockManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Common style for all buttons
    final ButtonStyle commonButtonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 60.0), // Full width, height 60
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        backgroundColor: Theme.of(context).colorScheme.primary, // Use theme color
      ),
      body: Stack(
        children: <Widget>[
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/menu-bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24.0), // Increased padding a bit for better spacing with bg
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add Purchase Entry'),
                    style: commonButtonStyle.copyWith(
                      backgroundColor: MaterialStateProperty.all(Colors.teal),
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PurchaseEntryScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 25), // Adjusted spacing
                  ElevatedButton.icon(
                    icon: const Icon(Icons.history),
                    label: const Text('View Purchase History'),
                    style: commonButtonStyle.copyWith(
                      backgroundColor: MaterialStateProperty.all(Colors.orangeAccent),
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PurchaseHistoryScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 25), // Adjusted spacing
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_document), // Icon for the new button
                    label: const Text('Edit / Delete Purchase Entry'),
                    style: commonButtonStyle.copyWith(
                      backgroundColor: MaterialStateProperty.all(Colors.blueGrey),
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditDeletePurchaseEntryScreen()), // Navigate to placeholder
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
