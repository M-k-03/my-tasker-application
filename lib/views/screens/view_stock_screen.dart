import 'package:flutter/material.dart';
import 'package:my_tasker/models/product.dart'; // Ensure this path is correct
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewStockScreen extends StatefulWidget {
  const ViewStockScreen({super.key});

  @override
  State<ViewStockScreen> createState() => _ViewStockScreenState();
}

class _ViewStockScreenState extends State<ViewStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  bool _isLoading = false;
  final int _itemsPerPage = 15;
  DocumentSnapshot? _lastFetchedProductDocument;
  bool _canLoadMore = true;

  @override
  void initState() {
    super.initState();
    print("DEBUG ViewStockScreen: initState called. Fetching initial products.");
    _fetchProducts(); // Initial fetch
  }

  @override
  void dispose() {
    _searchController.dispose();
    print("DEBUG ViewStockScreen: dispose called.");
    super.dispose();
  }

  Future<void> _fetchProducts({String searchQuery = '', bool isPaginating = false}) async {
    print("DEBUG ViewStockScreen: _fetchProducts - Search: '$searchQuery', Paginating: $isPaginating, IsLoading: $_isLoading, CanLoadMore: $_canLoadMore");

    if (_isLoading && isPaginating) {
      print("DEBUG ViewStockScreen: Already loading more (paginating), returning.");
      return;
    }
    if (!isPaginating && _isLoading) {
      print("DEBUG ViewStockScreen: Already loading (new search/initial), returning.");
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      if (!isPaginating) {
        print("DEBUG ViewStockScreen: Resetting product list for new search/initial load.");
        _products = [];
        _lastFetchedProductDocument = null;
        _canLoadMore = true; // Reset on new search
      }
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      Query query = firestore.collection('master_products').orderBy('productName');

      if (searchQuery.isNotEmpty) {
        print("DEBUG ViewStockScreen: Applying search query: '$searchQuery'");
        query = query
            .where('productName', isGreaterThanOrEqualTo: searchQuery)
            .where('productName', isLessThanOrEqualTo: '$searchQuery\uf8ff');
      }

      if (isPaginating && _lastFetchedProductDocument != null) {
        print("DEBUG ViewStockScreen: Paginating. Starting after doc ID: ${_lastFetchedProductDocument!.id}");
        query = query.startAfterDocument(_lastFetchedProductDocument!);
      }
      query = query.limit(_itemsPerPage);

      QuerySnapshot productSnapshot = await query.get();
      print("DEBUG ViewStockScreen: Fetched ${productSnapshot.docs.length} product documents from master_products.");

      if (!mounted) return;

      if (productSnapshot.docs.isEmpty) {
        setState(() {
          if (isPaginating) {
            _canLoadMore = false;
            print("DEBUG ViewStockScreen: No more products to paginate.");
          }
          _isLoading = false;
        });
        if (!isPaginating && _products.isEmpty) { // Keep existing message for no results
          print("DEBUG ViewStockScreen: No products found for initial load/search query '$searchQuery'.");
        }
        return;
      }

      if (productSnapshot.docs.isNotEmpty) {
        _lastFetchedProductDocument = productSnapshot.docs.last;
      }
      if (productSnapshot.docs.length < _itemsPerPage) {
        _canLoadMore = false; // No more if fewer than requested are fetched
        print("DEBUG ViewStockScreen: Fetched less than itemsPerPage, setting _canLoadMore to false.");
      }


      List<Product> fetchedBatchProducts = [];
      for (var productDoc in productSnapshot.docs) {
        String productId = productDoc.id;
        String productNameForDebug = (productDoc.data() as Map<String, dynamic>)['productName'] ?? 'N/A';
        print("DEBUG ViewStockScreen ($productNameForDebug, ID: $productId): Calculating stock.");

        // Calculate Total Purchased
        int totalPurchased = 0;
        QuerySnapshot purchaseEntriesSnapshot = await firestore
            .collection('purchase_entries')
            .where('productId', isEqualTo: productId)
            .get();
        print("DEBUG ViewStockScreen ($productNameForDebug): Found ${purchaseEntriesSnapshot.docs.length} purchase entries.");
        for (var entryDoc in purchaseEntriesSnapshot.docs) {
          final data = entryDoc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('quantity')) {
            totalPurchased += (data['quantity'] as num?)?.toInt() ?? 0;
          }
        }
        print("DEBUG ViewStockScreen ($productNameForDebug): Total Purchased: $totalPurchased");

        // Calculate Total Sold
        int totalSold = 0;
        QuerySnapshot saleEntriesSnapshot = await firestore
            .collection('sale_entries')
            .where('productId', isEqualTo: productId)
            .get();
        print("DEBUG ViewStockScreen ($productNameForDebug): Found ${saleEntriesSnapshot.docs.length} sale entries.");
        for (var entryDoc in saleEntriesSnapshot.docs) {
          final data = entryDoc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('quantitySold')) { // Ensure field name is 'quantitySold'
            totalSold += (data['quantitySold'] as num?)?.toInt() ?? 0;
          }
        }
        print("DEBUG ViewStockScreen ($productNameForDebug): Total Sold: $totalSold");

        int actualCalculatedStock = totalPurchased - totalSold;

        // ** IMPORTANT: Cap negative stock at 0 for display and Product model **
        int stockForProductModel = actualCalculatedStock < 0 ? 0 : actualCalculatedStock;

        print("DEBUG ViewStockScreen ($productNameForDebug): Actual Calculated Stock: $actualCalculatedStock, Stock for Product Model: $stockForProductModel");

        // Pass 'stockForProductModel' to the Product constructor
        fetchedBatchProducts.add(Product.fromFirestore(productDoc, stockForProductModel));
      }

      if (!mounted) return;
      setState(() {
        if (isPaginating) {
          _products.addAll(fetchedBatchProducts);
          print("DEBUG ViewStockScreen: Added ${fetchedBatchProducts.length} paginated products. Total: ${_products.length}");
        } else {
          _products = fetchedBatchProducts;
          print("DEBUG ViewStockScreen: Set ${fetchedBatchProducts.length} products for new search/initial.");
        }
        _isLoading = false;
      });

    } catch (e, s) {
      print("Error fetching products in ViewStockScreen: $e");
      print("Stack trace: $s");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Optionally, show a more user-friendly error in the UI
      });
    }
  }

  void _onSearchChanged(String query) {
    print("DEBUG ViewStockScreen: _onSearchChanged called with query: '$query'");
    _fetchProducts(searchQuery: query, isPaginating: false);
  }

  void _loadMore() {
    print("DEBUG ViewStockScreen: _loadMore called. CanLoadMore: $_canLoadMore, IsLoading: $_isLoading");
    if (!_isLoading && _canLoadMore) {
      _fetchProducts(searchQuery: _searchController.text, isPaginating: true);
    } else {
      print("DEBUG ViewStockScreen: _loadMore - conditions not met.");
    }
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG ViewStockScreen: build - Products: ${_products.length}, Loading: $_isLoading, CanLoadMore: $_canLoadMore");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Stock'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              print("DEBUG ViewStockScreen: Refresh button pressed.");
              _fetchProducts(searchQuery: _searchController.text, isPaginating: false);
            },
          )
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!_isLoading && _canLoadMore &&
                    scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.8 &&
                    scrollInfo.metrics.maxScrollExtent > 0) {
                  print("DEBUG ViewStockScreen: Scroll threshold reached for load more.");
                  _loadMore();
                  return true;
                }
                return false;
              },
              child: (_isLoading && _products.isEmpty)
                  ? const Center(child: CircularProgressIndicator(key: Key("initial_full_loader")))
                  : _products.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      _isLoading ? 'Loading...' : (_searchController.text.isEmpty ? 'No products found.' : 'No products match your search.'),
                      textAlign: TextAlign.center,
                      key: const Key("no_products_text")
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: _products.length + (_canLoadMore && _products.isNotEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _products.length && _canLoadMore && _products.isNotEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(key: Key("bottom_load_more_indicator")),
                      ),
                    );
                  }
                  if (index >= _products.length) {
                    return Container(); // Should not happen with correct itemCount
                  }
                  final product = _products[index];

                  ShapeBorder cardShape;
                  // product.currentStock will be 0 if actualCalculatedStock was <= 0
                  if (product.currentStock == 0) {
                    cardShape = RoundedRectangleBorder(
                      side: BorderSide(color: Colors.redAccent[700] ?? Colors.redAccent, width: 1.5),
                      borderRadius: BorderRadius.circular(8.0),
                    );
                  } else {
                    cardShape = RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    );
                  }

                  return Card(
                    key: Key("product_card_${product.id ?? index}"), // Use product.id for key
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    shape: cardShape,
                    elevation: 2.0,
                    child: ListTile(
                      title: Text(product.productName),
                      subtitle: Text(
                          'SKU: ${product.sku ?? "N/A"} - Barcode: ${product.barcode ?? "N/A"}\nUnits: ${product.units ?? "N/A"}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Qty: ${product.currentStock}', // This uses the (potentially capped) stock
                            style: TextStyle(
                              color: product.currentStock == 0
                                  ? Colors.redAccent[700] // Red text for 0 stock
                                  : Colors.green[700],   // Green for positive stock
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('Price: \$${product.price.toStringAsFixed(2)}'),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
