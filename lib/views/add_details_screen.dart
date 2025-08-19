import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'view_entries_screen.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AddProductDetailsScreen extends StatefulWidget {
  final String? productId;
  final Map<String, dynamic>? initialData;

  const AddProductDetailsScreen({super.key, this.productId, this.initialData});

  @override
  State<AddProductDetailsScreen> createState() => _AddProductDetailsScreenState();
}

class _AddProductDetailsScreenState extends State<AddProductDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  String? _selectedProductName;
  int? _selectedNos;
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _manualProductNameController = TextEditingController(); // For manual product name input
  String? _dateErrorText;
  String _scannedBarcode = '';

  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController();

  List<String> _productNameOptions = []; // Will be fetched from Firebase
  bool _isLoadingProductNames = true;
  bool _showProductNameAsTextField = false; // Toggle for product name input type
  bool _isVerifyingBarcode = false;

  // This is the line that was missing
  final List<int> _nosOptions = List.generate(5, (index) => index + 1);


  bool get _isSubmitButtonEnabled {
    // Adjusted for manual product name input
    final bool productNameValid = _showProductNameAsTextField
        ? _manualProductNameController.text.isNotEmpty
        : _selectedProductName != null;

    return _selectedDate != null &&
        productNameValid &&
        _selectedNos != null &&
        _priceController.text.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _fetchProductNames(); // Fetch product names from Firebase

    if (widget.initialData != null && widget.productId != null) {
      final data = widget.initialData!;
      final Timestamp? dateTimestamp = data['date'] as Timestamp?;
      if (dateTimestamp != null) {
        _selectedDate = dateTimestamp.toDate();
      }
      _selectedProductName = data['productName'] as String?;
      // If initial product name exists, ensure it's an option (might be added by _fetchProductNames anyway)
      if (_selectedProductName != null && !_productNameOptions.contains(_selectedProductName!)) {
        // This scenario is less likely if _fetchProductNames gets all unique names
      }
      _selectedNos = data['nos'] as int?;
      _priceController.text = (data['price'] as num?)?.toString() ?? '';
      if (data.containsKey('totalAmount')) {
        _totalAmountController.text = (data['totalAmount'] as num?)?.toStringAsFixed(2) ?? '0.00';
      } else {
        _updateTotalAmount();
      }
      _scannedBarcode = data['barcode'] as String? ?? '';
      if (_scannedBarcode.isNotEmpty) {
        // If initial data has a barcode, verify it.
        // Needs _productNameOptions to be loaded, so consider sequence or call after _fetchProductNames
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _verifyBarcodeAndSetProduct(_scannedBarcode, isInitialLoad: true);
        });
      }
    } else {
      _selectedDate = DateTime.now();
      _updateTotalAmount();
    }
    _priceController.addListener(_updateTotalAmount);
  }

  Future<void> _fetchProductNames() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProductNames = true;
    });
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('products').get();
      final Set<String> uniqueNames = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('productName') && data['productName'] is String) {
          uniqueNames.add(data['productName']);
        }
      }
      if (!mounted) return;
      setState(() {
        _productNameOptions = uniqueNames.toList()..sort();
        _isLoadingProductNames = false;
        // If an initial product name was set and it's in the fetched options, ensure dropdown reflects it
        if (widget.initialData != null && widget.initialData!['productName'] != null) {
          _selectedProductName = widget.initialData!['productName'];
        }

      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProductNames = false;
      });
      Fluttertoast.showToast(msg: "Error fetching product names: $e");
    }
  }

  Future<void> _verifyBarcodeAndSetProduct(String barcode, {bool isInitialLoad = false}) async {
    if (barcode.isEmpty) {
      // If barcode is cleared or empty
      if (!mounted) return;
      setState(() {
        if(!isInitialLoad) _selectedProductName = null; // Don't clear if it's initial load with existing product
        _manualProductNameController.clear();
        _showProductNameAsTextField = false;
        _isVerifyingBarcode = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isVerifyingBarcode = true;
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .limit(1) // We only need one match to get the product name
          .get();

      if (!mounted) return;

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>?;
        final String? existingProductName = data?['productName'] as String?;
        setState(() {
          _selectedProductName = existingProductName;
          _manualProductNameController.clear(); // Clear manual input
          _showProductNameAsTextField = false; // Show dropdown
          // Ensure the fetched product name is in options (it should be if _fetchProductNames is comprehensive)
          if (existingProductName != null && !_productNameOptions.contains(existingProductName)) {
            _productNameOptions.add(existingProductName);
            _productNameOptions.sort();
          }
        });
      } else {
        // No product found for this barcode
        setState(() {
          if(!isInitialLoad) _selectedProductName = null; // Clear selection only if not initial load
          _manualProductNameController.clear();
          _showProductNameAsTextField = true; // Switch to TextField for new product name
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error verifying barcode: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingBarcode = false;
        });
      }
    }
  }


  void _handleBarcodeDetection(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcodeValue = barcodes.first.rawValue;
      if (barcodeValue != null && barcodeValue.isNotEmpty) {
        setState(() {
          _scannedBarcode = barcodeValue;
          _isScanning = false; // Stop scanning view
        });
        Fluttertoast.showToast(msg: "Barcode found: $_scannedBarcode");
        _verifyBarcodeAndSetProduct(_scannedBarcode);
      } else {
        Fluttertoast.showToast(msg: "Scanned barcode is empty.");
      }
    }
  }


  void _updateTotalAmount() {
    final double price = double.tryParse(_priceController.text) ?? 0.0;
    final int nos = _selectedNos ?? 0;
    final double totalAmount = price * nos;
    if (_totalAmountController.text != totalAmount.toStringAsFixed(2)) {
      _totalAmountController.text = totalAmount.toStringAsFixed(2);
    }
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    ).then((pickedDate) {
      if (pickedDate == null) return;
      setState(() => _selectedDate = pickedDate);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      setState(() => _dateErrorText = 'Please choose a date.');
      return;
    }
    _formKey.currentState!.save();

    String finalProductName;
    if (_showProductNameAsTextField) {
      finalProductName = _manualProductNameController.text;
    } else if (_selectedProductName != null) {
      finalProductName = _selectedProductName!;
    } else {
      // This case should ideally be prevented by form validation
      Fluttertoast.showToast(msg: "Please select or enter a product name.");
      return;
    }


    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      Map<String, dynamic> dataToSave = {
        'date': Timestamp.fromDate(_selectedDate!),
        'productName': finalProductName,
        'nos': _selectedNos,
        'price': double.tryParse(_priceController.text),
        'totalAmount': double.tryParse(_totalAmountController.text) ?? 0.0,
        'barcode': _scannedBarcode,
      };

      if (widget.productId != null) {
        await firestore.collection('products').doc(widget.productId).update(dataToSave);
        Fluttertoast.showToast(msg: "Entry updated successfully");
      } else {
        dataToSave['submittedAt'] = FieldValue.serverTimestamp();
        await firestore.collection('products').add(dataToSave);
        Fluttertoast.showToast(msg: "Product details added successfully");
      }

      _formKey.currentState!.reset();
      _manualProductNameController.clear();
      setState(() {
        _selectedDate = (widget.productId != null) ? null : DateTime.now();
        _selectedProductName = null;
        _selectedNos = null;
        _priceController.clear();
        _totalAmountController.text = '0.00'; // Reset total amount display
        _scannedBarcode = '';
        _showProductNameAsTextField = false; // Revert to dropdown
        _dateErrorText = null;
        _fetchProductNames(); // Refresh product names in case a new one was added
      });
    } catch (e) {
      Fluttertoast.showToast(msg: widget.productId != null ? 'Error updating entry: $e' : 'Error saving: $e');
    }
  }

  @override
  void dispose() {
    _priceController.removeListener(_updateTotalAmount);
    _priceController.dispose();
    _totalAmountController.dispose();
    _manualProductNameController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Widget _buildDatePickerRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _selectedDate == null
                    ? 'No date chosen'
                    : 'Picked Date: ${DateFormat('dd/MMM/yyyy').format(_selectedDate!)}',
              ),
            ),
            TextButton(
              onPressed: _presentDatePicker,
              child: const Text('Choose Date', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (_dateErrorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(_dateErrorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildProductNameInput() {
    if (_isLoadingProductNames || _isVerifyingBarcode) {
      return Row(
        children: [
          Expanded(child: Text(_isVerifyingBarcode && _selectedProductName != null ? _selectedProductName! : 'Loading products...')),
          const SizedBox(width: 8),
          const CircularProgressIndicator(strokeWidth: 2.0),
        ],
      );
    }
    if (_showProductNameAsTextField) {
      return TextFormField(
        controller: _manualProductNameController,
        decoration: const InputDecoration(labelText: 'Product Name (New)', border: OutlineInputBorder()),
        validator: (value) => (value == null || value.isEmpty) ? 'Please enter a product name.' : null,
        onChanged: (_) => setState(() {}), // To re-evaluate _isSubmitButtonEnabled
      );
    } else {
      return DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
        value: _selectedProductName,
        items: _productNameOptions.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (newValue) {
          setState(() {
            _selectedProductName = newValue;
          });
        },
        validator: (value) => (value == null || value.isEmpty) ? 'Please select a product name.' : null,
        isExpanded: true,
      );
    }
  }

  Widget _buildNosDropdown() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(labelText: 'Nos', border: OutlineInputBorder()),
      value: _selectedNos,
      items: _nosOptions.map((int value) { // _nosOptions is used here
        return DropdownMenuItem<int>(value: value, child: Text(value.toString()));
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedNos = newValue;
          _updateTotalAmount();
        });
      },
      validator: (value) => (value == null) ? 'Please select a number.' : null,
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder(), prefixText: '\$ '),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) {
        _updateTotalAmount(); // Update total amount when price changes
        setState(() {}); // To re-evaluate _isSubmitButtonEnabled
      },
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter a price.';
        if (double.tryParse(value) == null) return 'Please enter a valid number.';
        return null;
      },
    );
  }

  Widget _buildTotalAmountField() {
    return TextFormField(
      controller: _totalAmountController,
      decoration: const InputDecoration(labelText: 'Total Amount', border: OutlineInputBorder(), prefixText: '\$ '),
      readOnly: true,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitButtonEnabled ? _submitForm : null,
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16.0), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
      child: Text(widget.productId != null ? 'Update' : 'Submit'),
    );
  }

  Widget _buildScanBarcodeButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text('Scan Barcode'),
      onPressed: () {
        setState(() {
          _isScanning = true;
        });
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }
  Widget _buildClearBarcodeButton() {
    return TextButton(
      onPressed: _scannedBarcode.isNotEmpty ? () {
        setState(() {
          _scannedBarcode = '';
          // Reset product name fields when barcode is cleared
          _selectedProductName = null;
          _manualProductNameController.clear();
          _showProductNameAsTextField = false;
        });
      } : null,
      child: const Text('Clear Barcode'),
    );
  }


  Widget _buildViewEntriesButton() {
    return OutlinedButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ViewEntriesScreen())),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16.0), side: BorderSide(color: Theme.of(context).colorScheme.primary)),
      child: Text('View Entries', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildScannerView() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4),) ]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Scan Barcode", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _handleBarcodeDetection,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _isScanning = false),
            child: const Text('Cancel Scan'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4),) ]
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildDatePickerRow(),
              const SizedBox(height: 16),
              if (_scannedBarcode.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(bottom: 0.0), // Reduced bottom padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Barcode: $_scannedBarcode', style: const TextStyle(fontWeight: FontWeight.bold)),
                        _buildClearBarcodeButton(), // Button to clear barcode
                      ],
                    )
                ),
              const SizedBox(height: 4), // Reduced space after barcode
              _buildProductNameInput(),
              const SizedBox(height: 16),
              _buildNosDropdown(),
              const SizedBox(height: 16),
              _buildPriceField(),
              const SizedBox(height: 16),
              _buildTotalAmountField(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 12),
              _buildScanBarcodeButton(),
              const SizedBox(height: 12),
              _buildViewEntriesButton(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isScanning ? 'Scanning Barcode' : (widget.productId != null ? 'Edit Entry' : 'Add Product Details')),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!_isScanning)
            IconButton(icon: const Icon(Icons.exit_to_app), tooltip: 'Exit App',
              onPressed: () => FlutterExitApp.exitApp(iosForceExit: true),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/products-bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: _isScanning ? _buildScannerView() : _buildFormView(),
          ),
        ),
      ),
    );
  }
}

