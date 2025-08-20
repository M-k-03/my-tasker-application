import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For number formatting
import 'package:my_tasker/models/purchase_entry_item.dart';

class EditPurchaseEntryFormScreen extends StatefulWidget {
  final PurchaseEntryItem purchaseEntry;

  const EditPurchaseEntryFormScreen({super.key, required this.purchaseEntry});

  @override
  State<EditPurchaseEntryFormScreen> createState() =>
      _EditPurchaseEntryFormScreenState();
}

class _EditPurchaseEntryFormScreenState
    extends State<EditPurchaseEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _productNameController;
  late TextEditingController _skuController;
  late TextEditingController _quantityController;
  late TextEditingController _purchasePricePerUnitController;
  late TextEditingController _totalPurchasePriceController;
  late TextEditingController _supplierNameController;
  late DateTime _selectedDate;
  late String _selectedUnit;

  final List<String> _unitOptions = ['pcs', 'kg', 'gm', 'ltr', 'ml', 'box', 'dozen', 'set', 'roll', 'meter', 'feet', 'units', 'packet'];

  @override
  void initState() {
    super.initState();
    _productNameController =
        TextEditingController(text: widget.purchaseEntry.productName);
    _skuController = TextEditingController(text: widget.purchaseEntry.sku);
    _quantityController =
        TextEditingController(text: widget.purchaseEntry.quantity.toString());
    _totalPurchasePriceController = TextEditingController(
        text: NumberFormat("0.00").format(widget.purchaseEntry.totalPurchasePrice));
    _supplierNameController =
        TextEditingController(text: widget.purchaseEntry.supplierName ?? '');
    _selectedDate = widget.purchaseEntry.purchaseDate.toDate();
    _selectedUnit = widget.purchaseEntry.unit;
    if (!_unitOptions.contains(_selectedUnit)) {
      _unitOptions.add(_selectedUnit);
    }

    double initialPricePerUnit = widget.purchaseEntry.purchasePricePerUnit;
    if ((initialPricePerUnit.abs() < 0.001) && widget.purchaseEntry.quantity > 0 && widget.purchaseEntry.totalPurchasePrice > 0) {
      initialPricePerUnit = widget.purchaseEntry.totalPurchasePrice / widget.purchaseEntry.quantity;
    }
    _purchasePricePerUnitController = TextEditingController(
        text: initialPricePerUnit > 0 ? NumberFormat("0.00").format(initialPricePerUnit) : '');

    _quantityController.addListener(_calculateAndDisplayTotal);
    _purchasePricePerUnitController.addListener(_calculateAndDisplayTotal);

    _calculateAndDisplayTotal();
  }

  void _calculateAndDisplayTotal() {
    final double quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    final double pricePerUnit = double.tryParse(_purchasePricePerUnitController.text.trim()) ?? 0;

    if (quantity > 0 && pricePerUnit > 0) {
      final double total = quantity * pricePerUnit;
      _totalPurchasePriceController.text = NumberFormat("0.00").format(total);
    } else {
      _totalPurchasePriceController.text = NumberFormat("0.00").format(0);
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _skuController.dispose();
    _quantityController.dispose();
    _purchasePricePerUnitController.dispose();
    _totalPurchasePriceController.dispose();
    _supplierNameController.dispose();
    _quantityController.removeListener(_calculateAndDisplayTotal);
    _purchasePricePerUnitController.removeListener(_calculateAndDisplayTotal);
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final String productName = _productNameController.text.trim();
      final String sku = _skuController.text.trim();
      final double? quantity = double.tryParse(_quantityController.text.trim());
      final double? purchasePricePerUnit = double.tryParse(_purchasePricePerUnitController.text.trim());
      final String supplierName = _supplierNameController.text.trim();

      if (quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid quantity.')),
        );
        return;
      }

      if (purchasePricePerUnit == null || purchasePricePerUnit <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid purchase price per unit.')),
        );
        return;
      }

      final double totalPurchasePrice = quantity * purchasePricePerUnit;

      try {
        await FirebaseFirestore.instance
            .collection('purchase_entries')
            .doc(widget.purchaseEntry.id)
            .update({
          'productName': productName,
          'sku': sku,
          'quantity': quantity,
          'unit': _selectedUnit,
          'purchasePricePerUnit': purchasePricePerUnit,
          'totalPurchasePrice': totalPurchasePrice,
          'supplierName': supplierName.isEmpty ? null : supplierName,
          'purchaseDate': Timestamp.fromDate(_selectedDate),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Purchase entry updated successfully!')),
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update purchase entry: $e')),
        );
      }
    }
  }

  Widget _buildReadOnlyTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).disabledColor.withOpacity(0.05),
      ),
    );
  }

  // ============== DELETE FUNCTIONALITY START ==============
  Future<void> _confirmAndDeletePurchaseEntry(BuildContext dialogContext) async {
    // Use widget.purchaseEntry.productName as it's more direct
    final productName = widget.purchaseEntry.productName;

    return showDialog<void>(
      context: dialogContext, // Use the passed context for the dialog
      barrierDismissible: false, // User must tap button to dismiss
      builder: (BuildContext context) { // This is the dialog's own context
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete the purchase entry for "$productName"?'),
                const Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog first
                _deletePurchaseEntry(dialogContext); // Proceed with deletion, passing the original screen context
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePurchaseEntry(BuildContext screenContext) async {
    try {
      await FirebaseFirestore.instance
          .collection('purchase_entries')
          .doc(widget.purchaseEntry.id)
          .delete();

      // Ensure that we are using a context that is still mounted for ScaffoldMessenger and Navigator
      if (!mounted) return;

      ScaffoldMessenger.of(screenContext).showSnackBar( // Use screenContext
        const SnackBar(content: Text('Purchase entry deleted successfully!')),
      );

      // Ensure that we are using a context that is still mounted for Navigator
      if (Navigator.of(screenContext).canPop()) { // Use screenContext
        Navigator.of(screenContext).pop(); // Pop the EditPurchaseEntryFormScreen
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(screenContext).showSnackBar( // Use screenContext
        SnackBar(content: Text('Failed to delete purchase entry: $e')),
      );
    }
  }
  // ============== DELETE FUNCTIONALITY END ==============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Purchase Entry'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // ============== APPBAR DELETE ACTION START ==============
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Entry',
            onPressed: () {
              // Pass the BuildContext from the build method to the confirm dialog
              _confirmAndDeletePurchaseEntry(context);
            },
          ),
        ],
        // ============== APPBAR DELETE ACTION END ==============
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildReadOnlyTextField('Product Name', _productNameController),
                const SizedBox(height: 16),
                _buildReadOnlyTextField('SKU', _skuController),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter quantity';
                    }
                    final n = double.tryParse(value.trim());
                    if (n == null) {
                      return 'Please enter a valid number';
                    }
                    if (n <= 0) {
                      return 'Quantity must be positive';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _unitOptions.contains(_selectedUnit) ? _selectedUnit : null,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: _unitOptions.map((String unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedUnit = newValue!;
                    });
                  },
                  validator: (value) =>
                  value == null ? 'Please select a unit' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _purchasePricePerUnitController,
                  decoration: const InputDecoration(
                    labelText: 'Purchase Price Per Unit',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter purchase price per unit';
                    }
                    final n = double.tryParse(value.trim());
                    if (n == null) {
                      return 'Please enter a valid number';
                    }
                    if (n <= 0) {
                      return 'Price per unit must be positive';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _totalPurchasePriceController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Total Purchase Price (Auto-calculated)',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Theme.of(context).disabledColor.withOpacity(0.05),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _supplierNameController,
                  decoration: const InputDecoration(
                    labelText: 'Supplier Name (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                          "Purchase Date: ${DateFormat.yMMMd().format(_selectedDate)}"),
                    ),
                    TextButton(
                      onPressed: () => _selectDate(context),
                      child: const Text('Change Date'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
