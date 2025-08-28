import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:my_tasker/models/purchase_entry_item.dart'; // Import the new model location

class PurchaseHistoryScreen extends StatefulWidget {
  final String shopId; // Added shopId
  const PurchaseHistoryScreen({super.key, required this.shopId}); // Modified constructor

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  late Stream<List<PurchaseEntryItem>> _purchaseEntriesStream;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _supplierFilterController = TextEditingController();
  final TextEditingController _productFilterController = TextEditingController();
  Map<String, dynamic> _activeFilters = {};
  // bool _isFiltersApplied = false; // Can be used for UI cues if needed

  @override
  void initState() {
    super.initState();
    _purchaseEntriesStream = _buildStream(_activeFilters);
  }

  @override
  void dispose() {
    _supplierFilterController.dispose();
    _productFilterController.dispose();
    super.dispose();
  }

  Stream<List<PurchaseEntryItem>> _buildStream(Map<String, dynamic> filters) {
    Query query = FirebaseFirestore.instance
        .collection('purchase_entries')
        .where('shopId', isEqualTo: widget.shopId); // Added shopId filter

    print("Building stream for shop: ${widget.shopId} with filters: $filters"); // DEBUG

    bool hasProductNameFilter = false; // Flag
    bool otherFiltersActive = false;

    if (filters['startDate'] != null) {
      query = query.where('purchaseDate', isGreaterThanOrEqualTo: filters['startDate']);
      otherFiltersActive = true;
    }
    if (filters['endDate'] != null) {
      // To include the whole day, adjust the endDate
      DateTime endDateForQuery = filters['endDate'];
      endDateForQuery = DateTime(endDateForQuery.year, endDateForQuery.month, endDateForQuery.day, 23, 59, 59);
      query = query.where('purchaseDate', isLessThanOrEqualTo: endDateForQuery);
      otherFiltersActive = true;
    }
    if (filters['supplierName'] != null && (filters['supplierName'] as String).isNotEmpty) {
      String supplierNameTerm = filters['supplierName'] as String;
      print("Querying for supplierName: '$supplierNameTerm'");
      query = query.where('supplierName', isEqualTo: supplierNameTerm);
      otherFiltersActive = true;
    }
    if (filters['productSearch'] != null && (filters['productSearch'] as String).isNotEmpty) {
      String productSearchTerm = filters['productSearch'] as String;
      print("Querying for productName: '$productSearchTerm'"); // DEBUG
      query = query.where('productName', isEqualTo: productSearchTerm);
      hasProductNameFilter = true; // Set flag
    }

    // Conditionally apply orderBy
    if (hasProductNameFilter && !otherFiltersActive) {
      // If ONLY product name filter is active, temporarily don't order by purchaseDate for this test.
      print("TEST: Product name filter is active ALONE, not ordering by purchaseDate for this test.");
    } else {
      query = query.orderBy('purchaseDate', descending: true);
    }

    return query.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty && hasProductNameFilter && !otherFiltersActive) {
          print("TEST: Snapshot is empty when ONLY product name filter is active (and no orderBy).");
      }
      return snapshot.docs
          .map((doc) => PurchaseEntryItem.fromSnapshot(doc))
          .toList();
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _applyFilters() {
    _activeFilters = {
      'startDate': _startDate,
      'endDate': _endDate,
      'supplierName': _supplierFilterController.text.trim(),
      'productSearch': _productFilterController.text.trim(),
    };
    print("Applying filters with productSearch: '${_activeFilters['productSearch']}'"); // DEBUG
    // _isFiltersApplied = _activeFilters.values.any((value) => value != null && (value is String ? value.isNotEmpty : true));
    setState(() {
      _purchaseEntriesStream = _buildStream(_activeFilters);
    });
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _supplierFilterController.clear();
      _productFilterController.clear();
      _activeFilters = {};
      // _isFiltersApplied = false;
      _purchaseEntriesStream = _buildStream(_activeFilters);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase History'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Column(
        children: [
          ExpansionTile(
            title: const Text('Filters (Tap to expand)'),
            childrenPadding: const EdgeInsets.all(16.0),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_startDate == null
                        ? 'Start Date: Not set'
                        : 'Start Date: ${DateFormat('dd MMM yyyy').format(_startDate!)}'),
                  ),
                  ElevatedButton(
                    onPressed: () => _selectDate(context, true),
                    child: const Text('Select'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(_endDate == null
                        ? 'End Date: Not set'
                        : 'End Date: ${DateFormat('dd MMM yyyy').format(_endDate!)}'),
                  ),
                  ElevatedButton(
                    onPressed: () => _selectDate(context, false),
                    child: const Text('Select'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _supplierFilterController,
                decoration: const InputDecoration(
                  labelText: 'Filter by Supplier Name',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.business_center_outlined)
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _productFilterController,
                decoration: const InputDecoration(
                  labelText: 'Filter by Product Name/SKU',
                   border: OutlineInputBorder(),
                   suffixIcon: Icon(Icons.inventory_2_outlined)
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Apply Filters'),
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white, // Ensure text is visible on primary color
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Filters'),
                    onPressed: _clearFilters,
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<PurchaseEntryItem>>(
              stream: _purchaseEntriesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  String errorMessage = snapshot.error.toString();
                  // Print the original full error message for complete context
                  print('Full error from StreamBuilder: $errorMessage');

                  // Attempt to extract and print the Firebase index URL
                  String urlPattern = r'https://console.firebase.google.com/project/[^/]+/database/firestore/indexes\?create_index=[^\s\)]+';
                  RegExp regExp = RegExp(urlPattern);
                  Match? match = regExp.firstMatch(errorMessage);

                  if (match != null) {
                    String? indexUrl = match.group(0);
                    if (indexUrl != null) {
                      print('----------------------------------------------------------------------');
                      print(' Firestore Index Creation URL (Please copy the line below):');
                      print(indexUrl);
                      print('----------------------------------------------------------------------');
                    }
                  }
                  return Center(child: Text('Error loading data. Check debug console for details and index creation URL.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No purchase entries found matching your filters.'));
                }

                List<PurchaseEntryItem> entries = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    PurchaseEntryItem entry = entries[index];
                    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a')
                        .format(entry.purchaseDate.toDate());

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
                            Text('Qty: ${entry.quantity} ${entry.unit}'),
                            if (entry.supplierName != null &&
                                entry.supplierName!.isNotEmpty)
                              Text('Supplier: ${entry.supplierName}'),
                            Text('Date: $formattedDate'),
                          ],
                        ),
                        trailing: Text(
                          '\u20B9${entry.totalPurchasePrice.toStringAsFixed(2)}', // Rupee symbol
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
