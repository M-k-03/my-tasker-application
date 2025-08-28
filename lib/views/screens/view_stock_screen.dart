import 'package:flutter/material.dart';
import 'package:my_tasker/models/product.dart'; // Ensure this path is correct
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewStockScreen extends StatefulWidget {
  final String shopId; // Added shopId
  const ViewStockScreen({super.key, required this.shopId}); // Modified constructor

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
    print("DEBUG ViewStockScreen (${widget.shopId}): initState called. Fetching initial products.");
    _fetchProducts(); // Initial fetch
  }

  @override
  void dispose() {
    _searchController.dispose();
    print("DEBUG ViewStockScreen (${widget.shopId}): dispose called.");
    super.dispose();
  }

  Future<void> _fetchProducts({String searchQuery = '', bool isPaginating = false}) async {
    print("DEBUG ViewStockScreen (${widget.shopId}): _fetchProducts - Shop: ${widget.shopId}, Search: '$searchQuery', Paginating: $isPaginating, IsLoading: $_isLoading, CanLoadMore: $_canLoadMore");

    if (_isLoading && isPaginating) {
      print("DEBUG ViewStockScreen (${widget.shopId}): Already loading more (paginating), returning.");
      return;
    }
    if (!isPaginating && _isLoading) {
      print("DEBUG ViewStockScreen (${widget.shopId}): Already loading (new search/initial), returning.");
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      if (!isPaginating) {
        print("DEBUG ViewStockScreen (${widget.shopId}): Resetting product list for new search/initial load.");
        _products = [];
        _lastFetchedProductDocument = null;
        _canLoadMore = true; // Reset on new search
      }
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      Query query = firestore
          .collection('master_products')
          .where('shopId', isEqualTo: widget.shopId) // Filter by shopId
          // OrderBy will be applied based on whether there's a search query or not
          ;

      String trimmedSearchQuery = searchQuery.trim();
      String lowerCaseSearchQueryForQuery = "";

      if (trimmedSearchQuery.isNotEmpty) {
        lowerCaseSearchQueryForQuery = trimmedSearchQuery.toLowerCase();
        query = query.orderBy('productName_lowercase'); // Order by the field used in range filter
        query = query
            .where('productName_lowercase', isGreaterThanOrEqualTo: lowerCaseSearchQueryForQuery)
            .where('productName_lowercase', isLessThanOrEqualTo: '$lowerCaseSearchQueryForQuery\\uf8ff');
        print("DEBUG ViewStockScreen (${widget.shopId}): Applying search to 'productName_lowercase': '$lowerCaseSearchQueryForQuery' (Original input: '$searchQuery')");
      } else {
        query = query.orderBy('productName_lowercase'); // Default order if no search query
        print("DEBUG ViewStockScreen (${widget.shopId}): No search query provided. Fetching all products ordered by 'productName_lowercase'.");
      }
      if (isPaginating && _lastFetchedProductDocument != null) {
        print("DEBUG ViewStockScreen (${widget.shopId}): Paginating. Starting after doc ID: ${_lastFetchedProductDocument!.id}");
        query = query.startAfterDocument(_lastFetchedProductDocument!);
      }
      query = query.limit(_itemsPerPage);

      QuerySnapshot productSnapshot = await query.get();
      print("DEBUG ViewStockScreen (${widget.shopId}): Fetched ${productSnapshot.docs.length} product documents from master_products for shop ${widget.shopId}.");

      if (!mounted) return;

      if (productSnapshot.docs.isEmpty) {
        setState(() {
          if (isPaginating) {
            _canLoadMore = false;
            print("DEBUG ViewStockScreen (${widget.shopId}): No more products to paginate for shop ${widget.shopId}.");
          }
          _isLoading = false;
        });
        if (!isPaginating && _products.isEmpty) {
          if (trimmedSearchQuery.isNotEmpty) {
            print("DEBUG ViewStockScreen (${widget.shopId}): No products found matching search criteria '$lowerCaseSearchQueryForQuery' (Original input: '$searchQuery') for shop ${widget.shopId}.");
          } else {
            print("DEBUG ViewStockScreen (${widget.shopId}): No products found initially for shop ${widget.shopId}.");
          }
        }
        return;
      }

      if (productSnapshot.docs.isNotEmpty) {
        _lastFetchedProductDocument = productSnapshot.docs.last;
      }
      if (productSnapshot.docs.length < _itemsPerPage) {
        _canLoadMore = false;
        print("DEBUG ViewStockScreen (${widget.shopId}): Fetched less than itemsPerPage, setting _canLoadMore to false for shop ${widget.shopId}.");
      }

      List<Product> fetchedBatchProducts = [];
      for (var productDoc in productSnapshot.docs) {
        String productId = productDoc.id;
        String productNameForDebug = (productDoc.data() as Map<String, dynamic>)['productName'] ?? 'N/A';
        print("DEBUG ViewStockScreen ($productNameForDebug, ID: $productId, Shop: ${widget.shopId}): Calculating stock.");

        // Calculate Total Purchased
        int totalPurchased = 0;
        QuerySnapshot purchaseEntriesSnapshot = await firestore
            .collection('purchase_entries')
            .where('productId', isEqualTo: productId)
            .where('shopId', isEqualTo: widget.shopId) // Filter by shopId
            .get();
        print("DEBUG ViewStockScreen ($productNameForDebug, Shop: ${widget.shopId}): Found ${purchaseEntriesSnapshot.docs.length} purchase entries.");
        for (var entryDoc in purchaseEntriesSnapshot.docs) {
          final data = entryDoc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('quantity')) {
            totalPurchased += (data['quantity'] as num?)?.toInt() ?? 0;
          }
        }
        print("DEBUG ViewStockScreen ($productNameForDebug, Shop: ${widget.shopId}): Total Purchased: $totalPurchased");

        // Calculate Total Sold
        int totalSold = 0;
        QuerySnapshot saleEntriesSnapshot = await firestore
            .collection('sale_entries')
            .where('productId', isEqualTo: productId)
            .where('shopId', isEqualTo: widget.shopId) // Filter by shopId
            .get();
        print("DEBUG ViewStockScreen ($productNameForDebug, Shop: ${widget.shopId}): Found ${saleEntriesSnapshot.docs.length} sale entries.");
        for (var entryDoc in saleEntriesSnapshot.docs) {
          final data = entryDoc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('quantitySold')) {
            totalSold += (data['quantitySold'] as num?)?.toInt() ?? 0;
          }
        }
        print("DEBUG ViewStockScreen ($productNameForDebug, Shop: ${widget.shopId}): Total Sold: $totalSold");

        int actualCalculatedStock = totalPurchased - totalSold;
        int stockForProductModel = actualCalculatedStock < 0 ? 0 : actualCalculatedStock;
        print("DEBUG ViewStockScreen ($productNameForDebug, Shop: ${widget.shopId}): Actual Calculated Stock: $actualCalculatedStock, Stock for Product Model: $stockForProductModel");
        
        // Product.fromFirestore now expects shopId and userId from the productDoc,
        // and currentStock is calculated and passed separately.
        // We've already ensured Product.fromFirestore can handle these fields.
        fetchedBatchProducts.add(Product.fromFirestore(productDoc, stockForProductModel));
      }

      if (!mounted) return;
      setState(() {
        if (isPaginating) {
          _products.addAll(fetchedBatchProducts);
          print("DEBUG ViewStockScreen (${widget.shopId}): Added ${fetchedBatchProducts.length} paginated products. Total: ${_products.length}");
        } else {
          _products = fetchedBatchProducts;
          print("DEBUG ViewStockScreen (${widget.shopId}): Set ${fetchedBatchProducts.length} products for new search/initial.");
        }
        _isLoading = false;
      });

    } catch (e, s) {
      print("Error fetching products in ViewStockScreen (${widget.shopId}): $e");
      print("Stack trace: $s");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    print("DEBUG ViewStockScreen (${widget.shopId}): _onSearchChanged called with query: '$query'");
    _fetchProducts(searchQuery: query, isPaginating: false);
  }

  void _loadMore() {
    print("DEBUG ViewStockScreen (${widget.shopId}): _loadMore called. CanLoadMore: $_canLoadMore, IsLoading: $_isLoading");
    if (!_isLoading && _canLoadMore) {
      _fetchProducts(searchQuery: _searchController.text, isPaginating: true);
    } else {
      print("DEBUG ViewStockScreen (${widget.shopId}): _loadMore - conditions not met.");
    }
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG ViewStockScreen (${widget.shopId}): build - Products: ${_products.length}, Loading: $_isLoading, CanLoadMore: $_canLoadMore");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Stock'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              print("DEBUG ViewStockScreen (${widget.shopId}): Refresh button pressed.");
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
                  print("DEBUG ViewStockScreen (${widget.shopId}): Scroll threshold reached for load more.");
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
                    key: Key("product_card_${product.id ?? index}"),
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    shape: cardShape,
                    elevation: 2.0,
                    child: ListTile(
                      title: Text(product.productName),
                      subtitle: Text(
                          'SKU: ${product.sku ?? "N/A"} - Barcode: ${product.barcode ?? "N/A"}\\nUnits: ${product.units ?? "N/A"}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Qty: ${product.currentStock}',
                            style: TextStyle(
                              color: product.currentStock == 0
                                  ? Colors.redAccent[700]
                                  : Colors.green[700],
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
