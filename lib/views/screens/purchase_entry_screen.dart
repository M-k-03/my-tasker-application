import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:my_tasker/views/screens/lookup_scanner_screen.dart'; // Make sure this path is correct

// Placeholder for MasterProduct model - adjust if you have a separate model file
class MasterProduct {
  final String id;
  final String productName;
  final String sku;
  final String units;
  // Add other fields like category, description, etc., if they exist in your Firestore documents
  // and you need them in the purchase entry context.

  MasterProduct({
    required this.id,
    required this.productName,
    required this.sku,
    required this.units,
  });

  factory MasterProduct.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MasterProduct(
      id: doc.id,
      productName: data['productName'] ?? 'N/A',
      sku: data['sku'] ?? 'N/A',
      units: data['units'] ?? 'units', // Default to 'units' if not specified
    );
  }
}

class PurchaseEntryScreen extends StatefulWidget {
  const PurchaseEntryScreen({super.key});

  @override
  State<PurchaseEntryScreen> createState() => _PurchaseEntryScreenState();
}

class _PurchaseEntryScreenState extends State<PurchaseEntryScreen> {
  final _formKey = GlobalKey<FormState>();

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
    bool isSearchingDialog = false; // Renamed to avoid conflict

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
                            final skuQuery = await FirebaseFirestore.instance
                                .collection('master_products')
                                .where('sku', isEqualTo: searchQuery.trim())
                                .limit(1)
                                .get();
                            if (skuQuery.docs.isNotEmpty) {
                              searchResults.add(MasterProduct.fromFirestore(skuQuery.docs.first));
                            }
                            final nameQuerySnapshot = await FirebaseFirestore.instance
                                .collection('master_products')
                                .where('productName', isGreaterThanOrEqualTo: searchQuery.trim())
                                .where('productName', isLessThanOrEqualTo: '${searchQuery.trim()}\uf8ff')
                                .limit(10) 
                                .get();
                            for (var doc in nameQuerySnapshot.docs) {
                              final product = MasterProduct.fromFirestore(doc);
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
                           final skuQuery = await FirebaseFirestore.instance
                              .collection('master_products')
                              .where('sku', isEqualTo: searchQuery.trim())
                              .limit(1)
                              .get();
                          if (skuQuery.docs.isNotEmpty) {
                            searchResults.add(MasterProduct.fromFirestore(skuQuery.docs.first));
                          }
                          final nameQuerySnapshot = await FirebaseFirestore.instance
                              .collection('master_products')
                              .where('productName', isGreaterThanOrEqualTo: searchQuery.trim())
                              .where('productName', isLessThanOrEqualTo: '${searchQuery.trim()}\uf8ff')
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
                      const Text('No products found.')
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
        Fluttertoast.showToast(msg: "Product not found for SKU: $sku");
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
    if (_isSubmitting) return; // Prevent multiple submissions

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedProduct == null) {
      Fluttertoast.showToast(msg: "Please select a product");
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
        'entryTimestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('purchase_entries').add(purchaseData);

      Fluttertoast.showToast(
        msg: "Purchase entry saved successfully!",
        toastLength: Toast.LENGTH_LONG,
      );

      // Clear form after successful submission
      _clearSelectedProduct();
      _supplierController.clear();
      _invoiceController.clear();
      _notesController.clear();
      setState(() {
        _purchaseDate = DateTime.now();
        _expiryDate = null;
         // _formKey.currentState?.reset(); // This might be too aggressive, manual clear is fine
      });

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
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear Product'),
                            onPressed: _isSubmitting ? null : _clearSelectedProduct, // Disable if submitting
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
                        onPressed: _isSubmitting ? null : _scanProduct, // Disable if submitting
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Search Product'),
                        onPressed: _isSubmitting ? null : _showSearchDialog, // Disable if submitting
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(labelText: 'Quantity Purchased (${_selectedProductUnit ?? 'units'})'),
                  keyboardType: TextInputType.number,
                  enabled: !_isSubmitting, // Disable if submitting
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter quantity';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Please enter a valid quantity';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _purchasePriceController,
                  decoration: const InputDecoration(labelText: 'Purchase Price per Unit'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  enabled: !_isSubmitting, // Disable if submitting
                   validator: (value) {
                    if (value != null && value.isNotEmpty && (double.tryParse(value) == null || double.parse(value) < 0)) {
                      return 'Please enter a valid price or leave empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _totalPurchasePriceController,
                  decoration: const InputDecoration(labelText: 'Total Purchase Price'),
                  readOnly: true,
                  // No need to disable readOnly, but good for consistency if it were editable
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _supplierController,
                  decoration: const InputDecoration(labelText: 'Supplier/Dealer Name'),
                  enabled: !_isSubmitting, // Disable if submitting
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _invoiceController,
                  decoration: const InputDecoration(labelText: 'Invoice/Bill No. (Optional)'),
                  enabled: !_isSubmitting, // Disable if submitting
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Text('Purchase Date: ${DateFormat('EEE, MMM d, yyyy').format(_purchaseDate)}'),
                    ),
                    TextButton(
                      onPressed: _isSubmitting ? null : () => _selectDate(context, true), // Disable if submitting
                      child: const Text('Change Date'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Text('Expiry Date: ${_expiryDate == null ? 'N/A' : DateFormat('EEE, MMM d, yyyy').format(_expiryDate!)}'),
                    ),
                    TextButton(
                      onPressed: _isSubmitting ? null : () => _selectDate(context, false), // Disable if submitting
                      child: const Text('Set/Change Date'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes/Remarks (Optional)'),
                  maxLines: 3,
                  enabled: !_isSubmitting, // Disable if submitting
                ),
                const SizedBox(height: 24),

                Center(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        backgroundColor: _isSubmitting ? Colors.grey : null,
                    ),
                    child: _isSubmitting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) 
                        : const Text('Submit Purchase Entry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
