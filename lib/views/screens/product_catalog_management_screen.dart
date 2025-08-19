import 'package:flutter/material.dart';
import 'package:my_tasker/views/widgets/define_product_form.dart';
import 'package:my_tasker/views/widgets/bulk_upload_form.dart'; // Added import

class ProductCatalogManagementScreen extends StatefulWidget {
  const ProductCatalogManagementScreen({super.key});

  @override
  State<ProductCatalogManagementScreen> createState() =>
      _ProductCatalogManagementScreenState();
}

class _ProductCatalogManagementScreenState
    extends State<ProductCatalogManagementScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DefineProductForm(), // Index 0
    const BulkUploadForm(), // Index 1 - Changed to use the actual form
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Define Product' : 'Bulk Upload Products'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: IndexedStack( // Use IndexedStack to preserve state of each tab
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_business_outlined), // Changed Icon for Define Product
            label: 'Define Product',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file_outlined),
            label: 'Bulk Upload',
          ),
        ],
      ),
    );
  }
}
