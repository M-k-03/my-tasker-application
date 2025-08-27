import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

class DefineProductForm extends StatefulWidget {
  final String shopId; // Added

  const DefineProductForm({super.key, required this.shopId}); // Modified

  @override
  State<DefineProductForm> createState() => _DefineProductFormState();
}

class _DefineProductFormState extends State<DefineProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _skuController = TextEditingController(); // SKU is also barcode

  String? _selectedUnit;
  final List<String> _unitOptions = ['pcs', 'kg', 'gm', 'ltr', 'ml', 'box', 'dozen', 'set', 'roll', 'meter', 'feet', 'units', 'packet'];
  var uuid = const Uuid();

  bool _isSkuEditable = true;
  bool _isScanningBarcode = false;
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isLoading = false;

  @override
  void dispose() {
    _productNameController.dispose();
    _priceController.dispose();
    _skuController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _generateSkuManually() {
    if (_isSkuEditable) {
      setState(() {
        _skuController.text = uuid.v4();
        _isSkuEditable = false;
      });
    }
  }

  void _startBarcodeScan() {
    if (_isSkuEditable) {
      setState(() {
        _isScanningBarcode = true;
      });
    }
  }

  void _handleBarcodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String scannedSku = barcodes.first.rawValue!;
      if (scannedSku.isNotEmpty) {
        setState(() {
          _skuController.text = scannedSku;
          _isSkuEditable = false;
          _isScanningBarcode = false;
        });
        Fluttertoast.showToast(msg: "Barcode Scanned: $scannedSku");
      } else {
        Fluttertoast.showToast(msg: "Scanned barcode is empty.");
      }
    } else {
      Fluttertoast.showToast(msg: "Could not read barcode reliably.");
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_skuController.text.isEmpty) {
        Fluttertoast.showToast(msg: "SKU/Barcode cannot be empty. Please generate or scan one.");
        return;
      }

      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        Fluttertoast.showToast(msg: "Error: User not logged in. Cannot save product.", toastLength: Toast.LENGTH_LONG);
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final sku = _skuController.text.trim();
        final productName = _productNameController.text.trim();

        if (productName.isEmpty) {
          Fluttertoast.showToast(msg: "Product name cannot be empty after trimming spaces.");
          setState(() { _isLoading = false; });
          return;
        }

        final String productNameLowercase = productName.toLowerCase();

        // Check for existing SKU within the same shopId to prevent duplicates within a shop
        // Note: Global SKU uniqueness check (across all shops) has been removed as per new requirements
        // If global SKU uniqueness is still desired, it would need a more complex query or a different data structure.
        final querySnapshot = await FirebaseFirestore.instance
            .collection('master_products')
            .where('shopId', isEqualTo: widget.shopId) // Filter by shopId
            .where('sku', isEqualTo: sku)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          Fluttertoast.showToast(msg: "Error: SKU '$sku' already exists in your shop. Please use a unique SKU within your shop.", toastLength: Toast.LENGTH_LONG);
          setState(() { _isLoading = false; });
          return;
        }

        await FirebaseFirestore.instance.collection('master_products').add({
          'shopId': widget.shopId, // Added
          'userId': userId, // Added
          'productName': productName,
          'productName_lowercase': productNameLowercase,
          'units': _selectedUnit,
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'sku': sku,
          'barcode': sku, 
          'isManuallyAddedSku': !_isSkuEditable,
          'createdAt': FieldValue.serverTimestamp(),
        });

        Fluttertoast.showToast(msg: "Product added successfully!");
        _formKey.currentState!.reset();
        _productNameController.clear();
        _priceController.clear();
        _skuController.clear();
        setState(() {
          _selectedUnit = null;
          _isSkuEditable = true;
          _isLoading = false;
        });
      } catch (e) {
        Fluttertoast.showToast(msg: "Error adding product: ${e.toString()}", toastLength: Toast.LENGTH_LONG);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _productNameController,
              decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter a product name';
                if (value.trim().isEmpty) return 'Product name cannot be only spaces';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedUnit,
              decoration: const InputDecoration(labelText: 'Units', border: OutlineInputBorder()),
              items: _unitOptions.map((String unit) {
                return DropdownMenuItem<String>(value: unit, child: Text(unit));
              }).toList(),
              onChanged: (String? newValue) => setState(() => _selectedUnit = newValue),
              validator: (value) => (value == null) ? 'Please select a unit' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price (INR)', border: OutlineInputBorder(), prefixText: '₹ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter a price';
                if (double.tryParse(value) == null) return 'Please enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _skuController,
              decoration: const InputDecoration(labelText: 'SKU / Barcode', border: OutlineInputBorder()),
              readOnly: !_isSkuEditable,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Barcode'),
                    onPressed: _isSkuEditable ? _startBarcodeScan : null,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Manual SKU'),
                    onPressed: _isSkuEditable ? _generateSkuManually : null,
                     style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Product'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeScannerView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("Scan Barcode", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _handleBarcodeDetected,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => setState(() => _isScanningBarcode = false),
          child: const Text('Cancel Scan'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isScanningBarcode) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildBarcodeScannerView(),
        ),
      );
    }
    return _buildForm();
  }
}
