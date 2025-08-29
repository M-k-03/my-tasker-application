import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:my_tasker/models/purchase_entry_item.dart';
import 'package:my_tasker/views/screens/edit_purchase_entry_form_screen.dart'; // Added import

class EditDeletePurchaseEntryScreen extends StatefulWidget {
  final String shopId; // Added shopId
  const EditDeletePurchaseEntryScreen({super.key, required this.shopId}); // Modified constructor

  @override
  State<EditDeletePurchaseEntryScreen> createState() =>
      _EditDeletePurchaseEntryScreenState();
}

class _EditDeletePurchaseEntryScreenState
    extends State<EditDeletePurchaseEntryScreen> {
  late Stream<List<PurchaseEntryItem>> _purchaseEntriesStream;

  @override
  void initState() {
    super.initState();
    print("EditDeletePurchaseEntryScreen initialized for shop: ${widget.shopId}"); // Debug log
    _purchaseEntriesStream = FirebaseFirestore.instance
        .collection('purchase_entries')
        .where('shopId', isEqualTo: widget.shopId) // Added shopId filter
        .orderBy('purchaseDate', descending: true) // CHANGED: Order by purchaseDate
        .snapshots()
        .map((snapshot) {
      print("Purchase entries snapshot received for shop ${widget.shopId}, docs: ${snapshot.docs.length}"); // Debug log
      return snapshot.docs
          .map((doc) => PurchaseEntryItem.fromSnapshot(doc))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit / Delete Purchase Entry'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<List<PurchaseEntryItem>>(
        stream: _purchaseEntriesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print("Error in EditDeletePurchaseEntryScreen stream for shop ${widget.shopId}: ${snapshot.error}"); // Debug log
            return Center(
                child: Text('Error loading entries: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No purchase entries found for this shop.'));
          }

          List<PurchaseEntryItem> entries = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              PurchaseEntryItem entry = entries[index];
              String formattedDate = DateFormat('dd MMM yyyy, hh:mm a')
                  .format(entry.purchaseDate.toDate()); // CHANGED: Use purchaseDate for formatting

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  title: Text(
                    '${entry.productName} (${entry.sku})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qty: ${entry.quantityPurchased} ${entry.unit}'), // Changed from quantity
                      if (entry.supplierName != null &&
                          entry.supplierName!.isNotEmpty)
                        Text('Supplier: ${entry.supplierName}'),
                      Text('Date: $formattedDate'),
                    ],
                  ),
                  trailing: Text(
                    '₹${entry.totalPurchasePrice.toStringAsFixed(2)}', // Rupee symbol
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditPurchaseEntryFormScreen(
                          purchaseEntry: entry,
                          shopId: widget.shopId, // Pass shopId
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
