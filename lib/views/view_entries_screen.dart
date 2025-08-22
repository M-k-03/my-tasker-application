import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';

// Helper class to hold all information and state for displaying a product's stock
class ProductStockDisplay {
  final String productId;
  final String productName;
  final String? sku;

  int totalPurchased;
  int totalSold;
  bool isLoadingStock;
  String? stockCalculationError;

  ProductStockDisplay({
    required this.productId,
    required this.productName,
    this.sku,
    this.totalPurchased = 0,
    this.totalSold = 0,
    this.isLoadingStock = true, // Initially true, as stock needs to be calculated
    this.stockCalculationError,
  });

  int get calculatedStock => totalPurchased - totalSold;
}

class ViewEntriesScreen extends StatefulWidget {
  const ViewEntriesScreen({super.key});

  @override
  State<ViewEntriesScreen> createState() => _ViewEntriesScreenState();
}

class _ViewEntriesScreenState extends State<ViewEntriesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ProductStockDisplay> _allProductsStockInfo = [];
  bool _isLoadingProductList = true; // For the initial fetch of master_products
  String? _generalLoadingError;

  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    print("DEBUG ViewStockScreen: initState called.");
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchText = _searchController.text;
        });
      }
    });
    _fetchAllProductData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    print("DEBUG ViewStockScreen: dispose called.");
    super.dispose();
  }

  Future<void> _fetchAllProductData() async {
    print("DEBUG ViewStockScreen: _fetchAllProductData started.");
    if (!mounted) return;
    setState(() {
      _isLoadingProductList = true;
      _generalLoadingError = null;
      _allProductsStockInfo = []; // Clear previous data
    });

    try {
      // 1. Fetch all product definitions from master_products
      print("DEBUG ViewStockScreen: Fetching from 'master_products' collection.");
      QuerySnapshot productDefinitionsSnapshot =
      await _firestore.collection('master_products').orderBy('productName').get();

      if (!mounted) return;

      if (productDefinitionsSnapshot.docs.isEmpty) {
        print("DEBUG ViewStockScreen: No documents found in 'master_products'.");
        setState(() {
          _isLoadingProductList = false;
          _generalLoadingError = "No product definitions found.";
        });
        return;
      }
      print("DEBUG ViewStockScreen: Found ${productDefinitionsSnapshot.docs.length} product definitions.");

      // Create initial list of ProductStockDisplay objects
      List<ProductStockDisplay> tempProducts = [];
      for (var doc in productDefinitionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        tempProducts.add(ProductStockDisplay(
          productId: doc.id,
          productName: data['productName'] as String? ?? 'N/A',
          sku: data['sku'] as String?,
        ));
      }

      // Update state with the product list (stock will be loading for each)
      setState(() {
        _allProductsStockInfo = tempProducts;
        _isLoadingProductList = false;
      });

      // 2. Asynchronously calculate stock for each product
      for (var productInfo in _allProductsStockInfo) {
        // Don't await here; let them run in parallel and update UI individually
        _calculateStockForProduct(productInfo.productId);
      }
    } catch (e, s) {
      print("DEBUG ViewStockScreen: Error in _fetchAllProductData: $e\n$s");
      if (mounted) {
        setState(() {
          _isLoadingProductList = false;
          _generalLoadingError = "Error loading product list: $e";
        });
      }
    }
  }

  Future<void> _calculateStockForProduct(String productId) async {
    // Find the product in our state list
    final productIndex = _allProductsStockInfo.indexWhere((p) => p.productId == productId);
    if (productIndex == -1) {
      print("DEBUG ViewStockScreen: ProductId $productId not found in _allProductsStockInfo during stock calculation. Might have been removed or list cleared.");
      return;
    }

    // For easier reference and to avoid mutating original if error before setState
    ProductStockDisplay currentProduct = _allProductsStockInfo[productIndex];
    String productNameForDebug = currentProduct.productName;

    print("DEBUG ViewStockScreen ($productNameForDebug, ID: $productId): Starting stock calculation.");

    // Ensure isLoadingStock is true for this item if not already
    // This is important if refresh is called, to show loading indicator again
    if (!currentProduct.isLoadingStock || currentProduct.stockCalculationError != null) {
      if(mounted) {
        setState(() {
          _allProductsStockInfo[productIndex].isLoadingStock = true;
          _allProductsStockInfo[productIndex].stockCalculationError = null;
        });
      }
    }


    try {
      // Fetch total purchased
      print("DEBUG ViewStockScreen ($productNameForDebug): Fetching purchases (productId: $productId)");
      QuerySnapshot purchaseSnapshot = await _firestore
          .collection('purchase_entries')
          .where('productId', isEqualTo: productId)
          .get();

      int totalPurchased = 0;
      print("DEBUG ViewStockScreen ($productNameForDebug): Found ${purchaseSnapshot.docs.length} purchase entries.");
      for (var doc in purchaseSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final quantity = data['quantity'] as num?;
        if (quantity != null) {
          totalPurchased += quantity.toInt();
          print("DEBUG ViewStockScreen ($productNameForDebug): Purchase doc ${doc.id}, quantity: ${quantity.toInt()}");
        } else {
          print("DEBUG ViewStockScreen ($productNameForDebug): Purchase doc ${doc.id} has null/missing 'quantity'.");
        }
      }
      print("DEBUG ViewStockScreen ($productNameForDebug): Calculated Total Purchased: $totalPurchased");

      // Fetch total sold
      print("DEBUG ViewStockScreen ($productNameForDebug): Fetching sales (productId: $productId)");
      QuerySnapshot saleSnapshot = await _firestore
          .collection('sale_entries')
          .where('productId', isEqualTo: productId)
          .get();

      int totalSold = 0;
      print("DEBUG ViewStockScreen ($productNameForDebug): Found ${saleSnapshot.docs.length} sale entries.");
      for (var doc in saleSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final quantitySold = data['quantitySold'] as num?;
        if (quantitySold != null) {
          totalSold += quantitySold.toInt();
          print("DEBUG ViewStockScreen ($productNameForDebug): Sale doc ${doc.id}, quantitySold: ${quantitySold.toInt()}");
        } else {
          print("DEBUG ViewStockScreen ($productNameForDebug): Sale doc ${doc.id} has null/missing 'quantitySold'.");
        }
      }
      print("DEBUG ViewStockScreen ($productNameForDebug): Calculated Total Sold: $totalSold");

      if (mounted) {
        // Re-check index as list could change due to other async operations (though less likely here)
        final currentIndex = _allProductsStockInfo.indexWhere((p) => p.productId == productId);
        if (currentIndex != -1) {
          setState(() {
            _allProductsStockInfo[currentIndex].totalPurchased = totalPurchased;
            _allProductsStockInfo[currentIndex].totalSold = totalSold;
            _allProductsStockInfo[currentIndex].isLoadingStock = false;
            _allProductsStockInfo[currentIndex].stockCalculationError = null;
            print("DEBUG ViewStockScreen ($productNameForDebug): Stock calculation successful. Final Stock: ${_allProductsStockInfo[currentIndex].calculatedStock}");
          });
        } else {
          print("DEBUG ViewStockScreen ($productNameForDebug): ProductId $productId disappeared from list before UI update for stock calculation.");
        }
      }
    } catch (e, s) {
      print("DEBUG ViewStockScreen ($productNameForDebug): Error calculating stock for $productId: $e\n$s");
      if (mounted) {
        final currentIndex = _allProductsStockInfo.indexWhere((p) => p.productId == productId);
        if (currentIndex != -1) {
          setState(() {
            _allProductsStockInfo[currentIndex].isLoadingStock = false;
            _allProductsStockInfo[currentIndex].stockCalculationError = "Error: $e";
          });
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    print("DEBUG ViewStockScreen: build method called.");
    List<ProductStockDisplay> filteredList = _allProductsStockInfo.where((item) {
      if (_searchText.isEmpty) {
        return true;
      }
      return item.productName.toLowerCase().contains(_searchText.toLowerCase()) ||
          (item.sku?.toLowerCase().contains(_searchText.toLowerCase()) ?? false);
    }).toList();

    Widget bodyContent;

    if (_isLoadingProductList) {
      bodyContent = const Center(child: CircularProgressIndicator(key: Key("initial_load_indicator")));
      print("DEBUG ViewStockScreen: Displaying initial loading indicator.");
    } else if (_generalLoadingError != null) {
      bodyContent = Center(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.black.withOpacity(0.7),
          child: Text(_generalLoadingError!, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
      print("DEBUG ViewStockScreen: Displaying general error: $_generalLoadingError");
    } else if (_allProductsStockInfo.isEmpty && !_isLoadingProductList) {
      bodyContent = Center(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.black.withOpacity(0.7),
          child: const Text('No products found to display.', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
      print("DEBUG ViewStockScreen: Displaying 'No products found' message.");
    }
    else if (filteredList.isEmpty && _searchText.isNotEmpty) {
      bodyContent = Center(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.black.withOpacity(0.7),
          child: Text('No products match your search: "$_searchText".', style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
      print("DEBUG ViewStockScreen: Displaying 'No products match search' message.");
    }
    else {
      print("DEBUG ViewStockScreen: Displaying product list. Filtered count: ${filteredList.length}");
      bodyContent = Container(
        color: Colors.white.withOpacity(0.85), // Semi-transparent layer for readability
        child: ListView.builder(
          key: const Key("product_stock_list"), // This one can be const as it's a fixed key
          itemCount: filteredList.length,
          itemBuilder: (context, index) {
            final item = filteredList[index];
            Widget stockWidget;

            if (item.isLoadingStock) {
              stockWidget = SizedBox( // Removed const here
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, key: Key("stock_loader_${item.productId}")), // Removed const
              );
            } else if (item.stockCalculationError != null) {
              stockWidget = Tooltip( // Removed const here
                message: item.stockCalculationError!,
                child: Icon(Icons.error_outline, color: Colors.red[700], size: 20, key: Key("stock_error_${item.productId}")), // Removed const
              );
            } else {
              stockWidget = Text(
                '${item.calculatedStock}',
                key: Key("stock_value_${item.productId}"), // Removed const
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: item.calculatedStock < 0 ? Colors.red[700] :
                  item.calculatedStock == 0 ? Colors.orange[700] :
                  Colors.green[700],
                ),
              );
            }

            return Card(
              key: Key("product_card_${item.productId}"), // Removed const
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              elevation: 2,
              child: ListTile(
                title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: item.sku != null && item.sku!.isNotEmpty
                    ? Text('SKU: ${item.sku}')
                    : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Stock:', style: TextStyle(fontSize: 12)),
                    stockWidget,
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Stock Levels'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Stock Data',
            onPressed: _fetchAllProductData, // Calls the main data loading function
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Exit App',
            onPressed: () {
              FlutterExitApp.exitApp(iosForceExit: true);
            },
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by Product Name or SKU',
                  hintText: 'Enter search term...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.85),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                      : null,
                ),
              ),
            ),
            Expanded(child: bodyContent),
          ],
        ),
      ),
    );
  }

}
