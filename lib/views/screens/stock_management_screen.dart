import 'package:flutter/material.dart';
import 'package:my_tasker/views/screens/purchase_entry_screen.dart'; // Import the PurchaseEntryScreen

class StockManagementScreen extends StatelessWidget {
  const StockManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add Purchase Entry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              )
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PurchaseEntryScreen()),
              );
            },
          ),
        ),
      ),
    );
  }
}
