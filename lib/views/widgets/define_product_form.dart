import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

class DefineProductForm extends StatefulWidget {
  const DefineProductForm({super.key});

  @override
  State<DefineProductForm> createState() => _DefineProductFormState();
}

class _DefineProductFormState extends State<DefineProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _skuController = TextEditingController(); // SKU is also barcode

  String? _selectedUnit;
  final List<String> _unitOptions = ['pcs', 'kg', 'gm', 'ltr', 'ml', 'box', 'dozen', 'set', 'roll', 'meter', 'feet', 'units', 'packet']; // MODIFIED
  var uuid = const Uuid();

  bool _isSkuEditable = true;
  bool _isScanningBarcode = false;
  final MobileScannerController _scannerController = MobileScannerController(
    // Optional: Configure scanner settings here if needed
    // detectionSpeed: DetectionSpeed.normal,
    // facing: CameraFacing.back,
  );
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

      setState(() {
        _isLoading = true;
      });

      try {
        // Check for duplicate SKU
        final sku = _skuController.text.trim(); // Also trim SKU just in case
        final productName = _productNameController.text.trim(); // TRIM HERE

        // Validate trimmed product name is not empty if it wasn't already caught by validator
        if (productName.isEmpty) {
          Fluttertoast.showToast(msg: "Product name cannot be empty after trimming spaces.");
          setState(() { _isLoading = false; });
          return;
        }

        final querySnapshot = await FirebaseFirestore.instance
            .collection('master_products')
            .where('sku', isEqualTo: sku)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          Fluttertoast.showToast(msg: "Error: SKU '$sku' already exists. Please use a unique SKU.", toastLength: Toast.LENGTH_LONG);
          setState(() { _isLoading = false; });
          return; // Stop submission if duplicate
        }

        // No duplicate, proceed to add
        await FirebaseFirestore.instance.collection('master_products').add({
          'productName': productName, // Use trimmed productName
          'units': _selectedUnit,
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'sku': sku, // Use trimmed sku
          'barcode': sku, // Explicitly store barcode if needed for other queries
          'isManuallyAddedSku': !_isSkuEditable, // A way to track if SKU was from scan/manual
          'createdAt': FieldValue.serverTimestamp(),
        });

        Fluttertoast.showToast(msg: "Product added successfully!");
        // Reset form
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
                if (value.trim().isEmpty) return 'Product name cannot be only spaces'; // Added validator for spaces
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
              // It's also good practice to trim SKU if manually entered, handled in _submitForm
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
    // This view will be centered by the modification in the main build method
    return Column(
      mainAxisAlignment: MainAxisAlignment.center, // Center Column content vertically
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("Scan Barcode", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          // Constrain the size of the scanner view
          width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
          height: MediaQuery.of(context).size.height * 0.4, // 40% of screen height
          child: ClipRRect( // Apply rounded corners to the scanner preview
            borderRadius: BorderRadius.circular(12.0),
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _handleBarcodeDetected,
              // You might want to add error builder:
              // errorBuilder: (context, error, child) {
              //   return Center(child: Text('Error starting camera: ${error.toString()}'));
              // },
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
      // MODIFICATION: Wrap the scanner view in a Center widget
      return Center(
        child: Padding( // Add padding around the scanner view for better aesthetics
          padding: const EdgeInsets.all(16.0),
          child: _buildBarcodeScannerView(),
        ),
      );
    }
    return _buildForm();
  }
}
