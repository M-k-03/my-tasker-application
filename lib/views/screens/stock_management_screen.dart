import 'package:flutter/material.dart';
import 'package:my_tasker/views/screens/purchase_entry_screen.dart'; // Import the PurchaseEntryScreen
import 'package:my_tasker/views/screens/purchase_history_screen.dart'; // Import PurchaseHistoryScreen
import 'package:my_tasker/views/screens/edit_delete_purchase_entry_screen.dart'; // Import the new placeholder screen
import 'package:my_tasker/views/screens/view_stock_screen.dart'; // Import the new ViewStockScreen

class StockManagementScreen extends StatelessWidget {
  final String shopId; // Added shopId

  const StockManagementScreen({super.key, required this.shopId}); // Modified constructor

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
                  // New "View Current Stock" button added here
                  ElevatedButton.icon(
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('View Current Stock'),
                    style: commonButtonStyle.copyWith(
                      // Using a distinct color, e.g., Green, or choose another like Colors.purple
                      backgroundColor: MaterialStateProperty.all(Colors.green),
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    ),
                    onPressed: () {
                      // Navigate to ViewStockScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ViewStockScreen(shopId: shopId)),
                      );
                    },
                  ),
                  const SizedBox(height: 25), // Adjusted spacing, consistent with others

                  // Existing buttons - their code remains untouched
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
                        MaterialPageRoute(builder: (context) => PurchaseEntryScreen(shopId: shopId)),
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
                        MaterialPageRoute(builder: (context) => PurchaseHistoryScreen(shopId: shopId)),
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
                        MaterialPageRoute(builder: (context) => EditDeletePurchaseEntryScreen(shopId: shopId)), // Navigate to placeholder
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
