import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'add_details_screen.dart'; // Import for navigation
// import 'package:flutter/services.dart'; // For SystemNavigator - No longer needed
import 'package:flutter_exit_app/flutter_exit_app.dart'; // Import flutter_exit_app

class ViewEntriesScreen extends StatefulWidget {
  const ViewEntriesScreen({super.key});

  @override
  State<ViewEntriesScreen> createState() => _ViewEntriesScreenState();
}

class _ViewEntriesScreenState extends State<ViewEntriesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper function to check if a date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _showDeleteConfirmationDialog(String productId, String displayInfo) async {
    if (!mounted) return; // Check if the widget is still in the tree

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete $displayInfo?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red[700])),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close the dialog
                try {
                  await _firestore.collection('products').doc(productId).delete();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entry deleted successfully')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting entry: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showActionsDialog(BuildContext context, String productId, Map<String, dynamic> productData, String displayDate) async {
    final String productName = productData['productName'] as String? ?? 'Entry';
    final String dialogDisplayInfo = '$productName on $displayDate';

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Actions for $dialogDisplayInfo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                title: const Text('Edit Entry'),
                onTap: () {
                  Navigator.of(dialogContext).pop(); // Close the dialog
                  Navigator.push(
                    context, // Use the main context for navigation
                    MaterialPageRoute(
                      builder: (context) => AddProductDetailsScreen(
                        productId: productId,
                        initialData: productData,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red[700]),
                title: const Text('Delete Entry'),
                onTap: () {
                  Navigator.of(dialogContext).pop(); // Close the dialog
                  // Construct the display info for the delete confirmation dialog
                  final String nameForDelete = productData['productName'] as String? ?? 'the entry';
                  final String deleteConfirmationDisplayInfo = '$nameForDelete recorded on $displayDate';
                  _showDeleteConfirmationDialog(productId, deleteConfirmationDisplayInfo);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Entries'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Exit App',
            onPressed: () {
              // SystemNavigator.pop(); // Replaced
              FlutterExitApp.exitApp(iosForceExit: true);
            },
          ),
        ],
      ),
      body: Container( // MODIFICATION STARTS HERE: Container for background
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/products-bg.jpg'), // Path to your new background image
            fit: BoxFit.cover, // Cover the entire body area
          ),
        ),
        child: StreamBuilder<QuerySnapshot>( // Original StreamBuilder is now the child
          stream: _firestore
              .collection('products')
              .orderBy('submittedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              // To make text readable on a potentially busy background, consider adding a background to the Text itself.
              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  color: Colors.black.withOpacity(0.5), // Semi-transparent background for text
                  child: const Text('No entries found.', style: TextStyle(color: Colors.white)),
                ),
              );
            }
            if (snapshot.hasError) {
              // Similarly for error text
              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  color: Colors.black.withOpacity(0.5),
                  child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                ),
              );
            }

            final products = snapshot.data!.docs;

            // This container provides a semi-transparent layer for readability over the background image.
            return Container(
              color: Colors.white.withOpacity(0.85), // Adjust opacity as needed
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Material( // ADDED: Wrap DataTable in Material for transparency
                  type: MaterialType.transparency, // Make the Material surface transparent
                  child: DataTable(
                    columnSpacing: 20.0,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Nos'), numeric: true),
                      DataColumn(label: Text('Amount'), numeric: true),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: products.map((product) {
                      final data = product.data() as Map<String, dynamic>;

                      final Timestamp? dateTimestamp = data['date'] as Timestamp?;
                      DateTime? productDate;
                      String displayDate = 'No date';
                      if (dateTimestamp != null) {
                        productDate = dateTimestamp.toDate();
                        displayDate = DateFormat('dd/MMM/yyyy').format(productDate);
                      }

                      final String? productName = data['productName'] as String?;
                      final int? nos = data['nos'] as int?;
                      final double? totalAmount = (data['totalAmount'] as num?)?.toDouble();

                      final bool isTodayEntry = productDate != null ? _isToday(productDate) : false;

                      return DataRow(
                        color: MaterialStateProperty.resolveWith<Color?>(
                                (Set<MaterialState> states) {
                              if (isTodayEntry) {
                                return Colors.amber.withOpacity(0.3);
                              }
                              return Colors.transparent; // CHANGED: Default row color to transparent
                            }),
                        cells: <DataCell>[
                          DataCell(Text(displayDate)),
                          DataCell(Text(productName ?? "N/A")),
                          DataCell(Text(nos != null ? nos.toString() : "N/A")),
                          DataCell(Text(totalAmount != null ? totalAmount.toStringAsFixed(2) : "N/A")),
                          DataCell(
                            IconButton(
                              icon: Icon(Icons.more_vert, color: Theme.of(context).primaryColorDark),
                              onPressed: () {
                                _showActionsDialog(context, product.id, data, displayDate);
                              },
                              tooltip: 'More actions',
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ), // MODIFICATION ENDS HERE
    );
  }
}

