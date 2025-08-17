import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:fluttertoast/fluttertoast.dart'; // Import Fluttertoast
import 'view_entries_screen.dart'; // For navigating to ViewEntriesScreen
// import 'package:flutter/services.dart'; // For SystemNavigator - No longer needed
import 'package:flutter_exit_app/flutter_exit_app.dart'; // Import flutter_exit_app

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
  final TextEditingController _totalAmountController = TextEditingController(); // Added
  String? _dateErrorText;

  final List<String> _productNameOptions = ['Pen', 'Book', 'Eraser', 'Sharpener', 'water can'];
  final List<int> _nosOptions = List.generate(5, (index) => index + 1);

  bool get _isSubmitButtonEnabled {
    return _selectedDate != null &&
        _selectedProductName != null &&
        _selectedNos != null &&
        _priceController.text.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null && widget.productId != null) {
      // We are in edit mode
      final data = widget.initialData!;
      final Timestamp? dateTimestamp = data['date'] as Timestamp?;
      if (dateTimestamp != null) {
        _selectedDate = dateTimestamp.toDate();
      }
      _selectedProductName = data['productName'] as String?;
      _selectedNos = data['nos'] as int?;
      _priceController.text = (data['price'] as num?)?.toString() ?? '';
      // If totalAmount is stored, load it, otherwise calculate
      if (data.containsKey('totalAmount')) {
         _totalAmountController.text = (data['totalAmount'] as num?)?.toStringAsFixed(2) ?? '0.00';
      } else {
        _updateTotalAmount(); // Calculate for older entries
      }
    } else {
      // Adding new entry, default the date
      _selectedDate = DateTime.now();
      _updateTotalAmount(); // Initialize total amount
    }
    // Add listener to price controller to update total amount
    _priceController.addListener(_updateTotalAmount);
  }

  void _updateTotalAmount() {
    final double price = double.tryParse(_priceController.text) ?? 0.0;
    final int nos = _selectedNos ?? 0;
    final double totalAmount = price * nos;
    // Check if the controller's text needs updating to avoid infinite loops if setState was used here
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
      if (pickedDate == null) {
        return;
      }
      setState(() {
        _selectedDate = pickedDate;
        _dateErrorText = null;
      });
    });
  }

  Future<void> _submitForm() async {
    setState(() {
      _dateErrorText = null;
    });

    bool isDateValid = true;
    if (_selectedDate == null) {
      setState(() {
        _dateErrorText = 'Please choose a date.';
      });
      isDateValid = false;
    }

    final isFormValid = _formKey.currentState!.validate();

    if (isDateValid && isFormValid) {
      _formKey.currentState!.save();

      try {
        FirebaseFirestore firestore = FirebaseFirestore.instance;
        Map<String, dynamic> dataToSave = {
          'date': Timestamp.fromDate(_selectedDate!),
          'productName': _selectedProductName,
          'nos': _selectedNos,
          'price': double.tryParse(_priceController.text),
          'totalAmount': double.tryParse(_totalAmountController.text) ?? 0.0, // Added
        };

        if (widget.productId != null) {
          await firestore.collection('products').doc(widget.productId).update(dataToSave);
          Fluttertoast.showToast(msg: "Entry updated successfully", toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM, backgroundColor: Colors.green, textColor: Colors.white, fontSize: 16.0);
        } else {
          dataToSave['submittedAt'] = FieldValue.serverTimestamp();
          await firestore.collection('products').add(dataToSave);
          Fluttertoast.showToast(msg: "Product details added successfully", toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, backgroundColor: Colors.green, textColor: Colors.white, fontSize: 16.0);
        }

        _formKey.currentState!.reset();
        setState(() {
          _selectedDate = (widget.productId != null) ? null : DateTime.now();
          _selectedProductName = null;
          _selectedNos = null;
          _priceController.clear();
          _totalAmountController.clear(); // Added
           _updateTotalAmount(); // Recalculate for blank form
          _dateErrorText = null;
        });

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.productId != null ? 'Error updating entry: $e' : 'Error saving to Firebase: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _priceController.removeListener(_updateTotalAmount); // Remove listener
    _priceController.dispose();
    _totalAmountController.dispose(); // Added
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
            padding: const EdgeInsets.only(top: 8.0, left: 0.0),
            child: Text(_dateErrorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ),
      ],
    );
  }
  
  Widget _buildProductNameDropdown() {
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
    );
  }

  Widget _buildNosDropdown() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(labelText: 'Nos', border: OutlineInputBorder()),
      value: _selectedNos,
      items: _nosOptions.map((int value) {
        return DropdownMenuItem<int>(value: value, child: Text(value.toString()));
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedNos = newValue;
          _updateTotalAmount(); // Added
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
        setState(() {
           // _updateTotalAmount(); // Listener handles this, but setState needed for submit button
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter a price.';
        if (double.tryParse(value) == null) return 'Please enter a valid number.';
        return null;
      },
    );
  }

  Widget _buildTotalAmountField() { // Added
    return TextFormField(
      controller: _totalAmountController,
      decoration: const InputDecoration(labelText: 'Total Amount', border: OutlineInputBorder(), prefixText: '\$ '),
      readOnly: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitButtonEnabled ? _submitForm : null,
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16.0), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
      child: Text(widget.productId != null ? 'Update' : 'Submit'),
    );
  }

  Widget _buildViewEntriesButton() {
    return OutlinedButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ViewEntriesScreen())),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16.0), side: BorderSide(color: Theme.of(context).colorScheme.primary)),
      child: Text('View Entries', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId != null ? 'Edit Entry' : 'Add Product Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.exit_to_app), tooltip: 'Exit App', 
            onPressed: () {
              FlutterExitApp.exitApp(iosForceExit: true);
            }
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildDatePickerRow(),
                const SizedBox(height: 12),
                _buildProductNameDropdown(),
                const SizedBox(height: 12),
                _buildNosDropdown(),
                const SizedBox(height: 12), // Adjusted spacing
                _buildPriceField(),
                const SizedBox(height: 12), // Adjusted spacing
                _buildTotalAmountField(), // Added
                const SizedBox(height: 30),
                _buildSubmitButton(),
                const SizedBox(height: 16), 
                _buildViewEntriesButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
