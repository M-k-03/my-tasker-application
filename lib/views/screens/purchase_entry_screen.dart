import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:my_tasker/models/purchase_entry_item.dart'; // Import PurchaseEntryItem
import 'package:my_tasker/services/stock_service.dart'; // Import StockService
import 'package:my_tasker/views/screens/lookup_scanner_screen.dart'; // Make sure this path is correct

// Placeholder for MasterProduct model - adjust if you have a separate model file
class MasterProduct {
  final String id;
  final String productName;
  final String sku;
  final String units;
  // final String shopId; // Products are now shop-specific

  MasterProduct({
    required this.id,
    required this.productName,
    required this.sku,
    required this.units,
    // required this.shopId,
  });

  factory MasterProduct.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MasterProduct(
      id: doc.id,
      productName: data['productName'] ?? 'N/A',
      sku: data['sku'] ?? 'N/A',
      units: data['units'] ?? 'units', // Default to 'units' if not specified
      // shopId: data['shopId'] ?? '', // Assuming shopId is stored with product
    );
  }
}

class PurchaseEntryScreen extends StatefulWidget {
  final String shopId; // Added
  const PurchaseEntryScreen({super.key, required this.shopId}); // Modified

  @override
  State<PurchaseEntryScreen> createState() => _PurchaseEntryScreenState();
}

class _PurchaseEntryScreenState extends State<PurchaseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final StockService _stockService = StockService(); // Instantiate StockService

  MasterProduct? _selectedProduct;
  String? _selectedProductUnit;

  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _purchasePriceController = TextEditingController();
  final TextEditingController _totalPurchasePriceController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  DateTime? _expiryDate;

  bool _isLoadingProduct = false;
  bool _isSubmitting = false; // For loading indicator on submit button

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_calculateTotal);
    _purchasePriceController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    double quantity = double.tryParse(_quantityController.text) ?? 0;
    double price = double.tryParse(_purchasePriceController.text) ?? 0;
    _totalPurchasePriceController.text = (quantity * price).toStringAsFixed(2);
  }

  Future<void> _selectDate(BuildContext context, bool isPurchaseDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPurchaseDate ? _purchaseDate : (_expiryDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isPurchaseDate) {
          _purchaseDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  Future<void> _scanProduct() async {
    if (_isLoadingProduct || _isSubmitting) return;
    setState(() => _isLoadingProduct = true);
    try {
      final scannedSku = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const LookupScannerScreen()),
      );

      if (scannedSku != null && scannedSku.isNotEmpty) {
        await _fetchProductDetails(scannedSku);
      } else if (scannedSku == null) {
        Fluttertoast.showToast(msg: "Scanning cancelled");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error during scanning: ${e.toString()}");
    } finally {
      setState(() => _isLoadingProduct = false);
    }
  }

  Future<void> _showSearchDialog() async {
    if (_isLoadingProduct || _isSubmitting) return;

    String searchQuery = '';
    List<MasterProduct> searchResults = [];
    bool isSearchingDialog = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Search Product by SKU or Name'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      onChanged: (value) {
                        searchQuery = value;
                      },
                      decoration: const InputDecoration(
                        hintText: 'Enter SKU or Product Name',
                        suffixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (value) async {
                         if (searchQuery.trim().isEmpty) {
                            Fluttertoast.showToast(msg: "Please enter a search term");
                            return;
                          }
                          setDialogState(() => isSearchingDialog = true);
                          searchResults.clear();
                          try {
                            // Search by SKU within the shop
                            final skuQuery = await FirebaseFirestore.instance
                                .collection('master_products')
                                .where('sku', isEqualTo: searchQuery.trim())
                                .where('shopId', isEqualTo: widget.shopId) // Added shopId filter
                                .limit(1)
                                .get();
                            if (skuQuery.docs.isNotEmpty) {
                              searchResults.add(MasterProduct.fromFirestore(skuQuery.docs.first));
                            }

                            // Search by Name within the shop
                            final nameQuerySnapshot = await FirebaseFirestore.instance
                                .collection('master_products')
                                .where('productName', isGreaterThanOrEqualTo: searchQuery.trim())
                                .where('productName', isLessThanOrEqualTo: '${searchQuery.trim()}\uf8ff')
                                .where('shopId', isEqualTo: widget.shopId) // Added shopId filter
                                .limit(10)
                                .get();
                            for (var doc in nameQuerySnapshot.docs) {
                              final product = MasterProduct.fromFirestore(doc);
                              // Ensure no duplicates if SKU and Name search overlap
                              if (!searchResults.any((p) => p.id == product.id)) {
                                searchResults.add(product);
                              }
                            }
                          } catch (e) {
                             Fluttertoast.showToast(msg: "Error searching: ${e.toString()}");
                          }
                          setDialogState(() => isSearchingDialog = false);
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        if (searchQuery.trim().isEmpty) {
                          Fluttertoast.showToast(msg: "Please enter a search term");
                          return;
                        }
                        setDialogState(() => isSearchingDialog = true);
                        searchResults.clear();
                        try {
                           // Search by SKU within the shop
                           final skuQuery = await FirebaseFirestore.instance
                              .collection('master_products')
                              .where('sku', isEqualTo: searchQuery.trim())
                              .where('shopId', isEqualTo: widget.shopId) // Added shopId filter
                              .limit(1)
                              .get();
                          if (skuQuery.docs.isNotEmpty) {
                            searchResults.add(MasterProduct.fromFirestore(skuQuery.docs.first));
                          }

                          // Search by Name within the shop
                          final nameQuerySnapshot = await FirebaseFirestore.instance
                              .collection('master_products')
                              .where('productName', isGreaterThanOrEqualTo: searchQuery.trim())
                              .where('productName', isLessThanOrEqualTo: '${searchQuery.trim()}\uf8ff')
                              .where('shopId', isEqualTo: widget.shopId) // Added shopId filter
                              .limit(10)
                              .get();
                          for (var doc in nameQuerySnapshot.docs) {
                            final product = MasterProduct.fromFirestore(doc);
                             if (!searchResults.any((p) => p.id == product.id)) {
                              searchResults.add(product);
                            }
                          }
                        } catch (e) {
                          Fluttertoast.showToast(msg: "Error searching products: ${e.toString()}");
                        }
                        setDialogState(() => isSearchingDialog = false);
                      },
                      child: const Text('Search'),
                    ),
                    const SizedBox(height: 15),
                    if (isSearchingDialog)
                      const CircularProgressIndicator()
                    else if (searchResults.isEmpty)
                      const Text('No products found for this shop.') // Updated message
                    else
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final product = searchResults[index];
                            return ListTile(
                              title: Text(product.productName),
                              subtitle: Text('SKU: ${product.sku} - Unit: ${product.units}'),
                              onTap: () {
                                Navigator.pop(context);
                                _fetchProductDetails(product.sku);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchProductDetails(String sku) async {
    if (sku.isEmpty) {
      Fluttertoast.showToast(msg: "SKU cannot be empty");
      return;
    }
    setState(() => _isLoadingProduct = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('master_products')
          .where('sku', isEqualTo: sku)
          .where('shopId', isEqualTo: widget.shopId) // Added shopId filter
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final product = MasterProduct.fromFirestore(querySnapshot.docs.first);
        setState(() {
          _selectedProduct = product;
          _selectedProductUnit = product.units;
          _quantityController.clear();
          _purchasePriceController.clear();
          _totalPurchasePriceController.clear();
        });
        Fluttertoast.showToast(msg: "Product loaded: ${product.productName}");
      } else {
        Fluttertoast.showToast(msg: "Product not found for SKU: $sku in this shop"); // Updated message
        _clearSelectedProduct();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error fetching product: ${e.toString()}");
      _clearSelectedProduct();
    } finally {
      setState(() => _isLoadingProduct = false);
    }
  }

  void _clearSelectedProduct() {
    setState(() {
      _selectedProduct = null;
      _selectedProductUnit = null;
      _quantityController.clear();
      _purchasePriceController.clear();
      _totalPurchasePriceController.clear();
    });
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedProduct == null) {
      Fluttertoast.showToast(msg: "Please select a product");
      return;
    }

    final String? userId = FirebaseAuth.instance.currentUser?.uid; // Added
    if (userId == null) { // Added
      Fluttertoast.showToast(msg: "Error: User not logged in. Cannot save entry.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      Map<String, dynamic> purchaseData = {
        'productId': _selectedProduct!.id,
        'productName': _selectedProduct!.productName,
        'sku': _selectedProduct!.sku,
        'quantity': double.tryParse(_quantityController.text) ?? 0.0,
        'unit': _selectedProductUnit,
        'purchasePricePerUnit': double.tryParse(_purchasePriceController.text) ?? 0.0,
        'totalPurchasePrice': double.tryParse(_totalPurchasePriceController.text) ?? 0.0,
        'supplierName': _supplierController.text.trim(),
        'invoiceNumber': _invoiceController.text.trim(),
        'purchaseDate': Timestamp.fromDate(_purchaseDate),
        'expiryDate': _expiryDate != null ? Timestamp.fromDate(_expiryDate!) : null,
        'notes': _notesController.text.trim(),
        'shopId': widget.shopId, // Added
        'userId': userId, // Added
        'entryTimestamp': FieldValue.serverTimestamp(),
      };

      // Add purchase entry to Firestore
      DocumentReference docRef = await FirebaseFirestore.instance.collection('purchase_entries').add(purchaseData);

      // Prepare PurchaseEntryItem for stock update
      // This now matches the actual PurchaseEntryItem model definition
      final purchaseEntryForStock = PurchaseEntryItem(
        id: docRef.id,
        productId: _selectedProduct!.id,
        shopId: purchaseData['shopId'] as String,
        productName: _selectedProduct!.productName,
        sku: _selectedProduct!.sku,
        quantityPurchased: (purchaseData['quantity'] as double).toInt(), // Convert double to int
        unit: (purchaseData['unit'] as String?) ?? 'units', // This is String? in model, so direct cast is fine
        purchaseDate: purchaseData['purchaseDate'] as Timestamp,
        purchasePricePerUnit: purchaseData['purchasePricePerUnit'] as double,
        totalPurchasePrice: purchaseData['totalPurchasePrice'] as double,
        userId: purchaseData['userId'] as String,
        createdAt: Timestamp.now(), // Required by PurchaseEntryItem constructor
        // Fields like invoiceNumber, purchaseDate (from purchaseData), expiryDate, notes
        // are part of the 'purchase_entries' Firestore document but not part of PurchaseEntryItem model.
        // PurchaseEntryItem is streamlined for what StockService needs and what's core to the item.
        supplierName: purchaseData['supplierName'] as String?, // This is String? in model
      );

      // Update stock summary
      try {
        await _stockService.updateStockOnPurchase(purchaseEntryForStock);
        Fluttertoast.showToast(
          msg: "Purchase entry saved and stock updated!",
          toastLength: Toast.LENGTH_LONG,
        );
      } catch (stockError) {
        Fluttertoast.showToast(
          msg: "Purchase entry saved, but failed to update stock: ${stockError.toString()}",
          toastLength: Toast.LENGTH_LONG,
        );
      }
      // Clear form and reset state
      _formKey.currentState?.reset(); // Resets form fields
      _clearSelectedProduct(); // Clears product specific fields and controllers related to product
      // Other fields not part of product or form reset
      _supplierController.clear();
      _invoiceController.clear();
      _notesController.clear();
      setState(() { _purchaseDate = DateTime.now(); _expiryDate = null; });
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to save purchase entry: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _quantityController.removeListener(_calculateTotal);
    _purchasePriceController.removeListener(_calculateTotal);
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _totalPurchasePriceController.dispose();
    _supplierController.dispose();
    _invoiceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Purchase Entry'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Product:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_isLoadingProduct)
                  const Center(child: CircularProgressIndicator())
                else if (_selectedProduct != null)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedProduct!.productName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('SKU: ${_selectedProduct!.sku}'),
                          Text('Unit: ${_selectedProduct!.units}'),
                          // Consider displaying shopId if relevant: Text('Shop ID: ${_selectedProduct!.shopId}'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear Product'),
                            onPressed: _isSubmitting ? null : _clearSelectedProduct,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          )
                        ],
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan Product'),
                        onPressed: _isSubmitting ? null : _scanProduct,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Search Product'),
                        onPressed: _isSubmitting ? null : _showSearchDialog,
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _quantityController, // Rest of the file unchanged
                  decoration: InputDecoration(
                    labelText: 'Quantity Purchased *',
                    hintText: 'Enter quantity',
                    suffixText: _selectedProductUnit ?? 'units',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter quantity';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Please enter a valid quantity greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purchasePriceController,
                  decoration: const InputDecoration(labelText: 'Purchase Price per Unit *', hintText: 'Enter price per unit'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter purchase price';
                    }
                    if (double.tryParse(value) == null || double.parse(value) < 0) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _totalPurchasePriceController,
                  decoration: const InputDecoration(labelText: 'Total Purchase Price', hintText: 'Auto-calculated'),
                  keyboardType: TextInputType.number,
                  readOnly: true,
                ),
                const SizedBox(height: 20),
                const Text('Supplier & Invoice (Optional):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _supplierController,
                  decoration: const InputDecoration(labelText: 'Supplier Name', hintText: 'Enter supplier name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _invoiceController,
                  decoration: const InputDecoration(labelText: 'Invoice Number', hintText: 'Enter invoice number'),
                ),
                const SizedBox(height: 20),
                const Text('Dates:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  title: Text('Purchase Date: ${DateFormat('yyyy-MM-dd').format(_purchaseDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context, true),
                ),
                ListTile(
                  title: Text('Expiry Date: ${_expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : 'Not Set (Optional)'}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context, false),
                  subtitle: _expiryDate == null ? const Text('Tap to set expiry date for perishable goods') : null,
                ),
                const SizedBox(height: 20),
                const Text('Notes (Optional):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes', hintText: 'Any additional notes for this purchase'),
                  maxLines: 3,
                ),
                const SizedBox(height: 30),
                Center(
                  child: ElevatedButton.icon(
                    icon: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)) : const Icon(Icons.save),
                    label: Text(_isSubmitting ? 'Saving...' : 'Save Purchase Entry'),
                    onPressed: _isSubmitting ? null : _submitForm, // Disable button when submitting
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
