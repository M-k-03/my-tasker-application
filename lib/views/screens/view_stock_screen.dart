import 'package:flutter/material.dart';
import 'package:my_tasker/models/product.dart'; // Import the Product model
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class ViewStockScreen extends StatefulWidget {
  const ViewStockScreen({super.key});

  @override
  State<ViewStockScreen> createState() => _ViewStockScreenState();
}

class _ViewStockScreenState extends State<ViewStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  bool _isLoading = false;
  int _currentPage = 1; // Current page for pagination
  final int _itemsPerPage = 15; // Number of items to fetch per page
  DocumentSnapshot? _lastFetchedProductDocument; // For Firestore pagination
  bool _canLoadMore = true; // To prevent multiple load more calls if no more data

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts({String searchQuery = '', bool isPaginating = false}) async {
    if (_isLoading && isPaginating) return; // Prevent multiple pagination calls if already loading more

    setState(() {
      _isLoading = true;
      if (!isPaginating) {
        // Reset list and pagination if it's a new search or initial load
        _products = [];
        _currentPage = 1;
        _lastFetchedProductDocument = null;
        _canLoadMore = true;
      }
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      Query query = firestore.collection('master_products').orderBy('productName'); // Default sort

      // Apply search query if provided
      if (searchQuery.isNotEmpty) {
        // Basic "starts with" search for productName.
        // For more complex search (e.g., SKU, barcode, case-insensitive),
        // you might need more sophisticated queries or client-side filtering.
        query = query
            .where('productName', isGreaterThanOrEqualTo: searchQuery)
            .where('productName', isLessThanOrEqualTo: '$searchQuery\\uf8ff');
      }

      // Apply pagination
      if (isPaginating && _lastFetchedProductDocument != null) {
        query = query.startAfterDocument(_lastFetchedProductDocument!);
      }
      query = query.limit(_itemsPerPage);

      QuerySnapshot productSnapshot = await query.get();

      if (productSnapshot.docs.isEmpty) { // Check if no documents are returned at all
        setState(() {
          if(isPaginating) _canLoadMore = false; // No more products to load if paginating
          _isLoading = false;
          // If it's not paginating and no docs, _products will remain empty, handled in build
        });
        return;
      }
      
      _lastFetchedProductDocument = productSnapshot.docs.last;
      

      List<Product> fetchedProducts = [];
      for (var productDoc in productSnapshot.docs) {
        String productId = productDoc.id;
        int currentStock = 0;

        // Fetch purchase entries to calculate current stock
        QuerySnapshot purchaseEntriesSnapshot = await firestore
            .collection('purchase_entries')
            .where('productId', isEqualTo: productId)
            .get();

        for (var entryDoc in purchaseEntriesSnapshot.docs) {
          final data = entryDoc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('quantity')) {
            currentStock += (data['quantity'] as num?)?.toInt() ?? 0;
          }
        }
        fetchedProducts.add(Product.fromFirestore(productDoc, currentStock));
      }

      setState(() {
        if (isPaginating) {
          _products.addAll(fetchedProducts);
           _currentPage++;
        } else {
          _products = fetchedProducts;
        }
        if (fetchedProducts.length < _itemsPerPage) {
          _canLoadMore = false; // Less items fetched than requested, so no more data
        }
        _isLoading = false;
      });

    } catch (e) {
      print("Error fetching products: $e");
      setState(() {
        _isLoading = false;
        // Optionally, show an error message to the user
      });
    }
  }

  void _onSearchChanged(String query) {
    // Basic debounce could be added here if desired (e.g., using a Timer)
    _fetchProducts(searchQuery: query, isPaginating: false);
  }

  void _loadMore() {
    if (!_isLoading && _canLoadMore) {
      _fetchProducts(searchQuery: _searchController.text, isPaginating: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Stock'),
        backgroundColor: Theme.of(context).colorScheme.primary,
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
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                // Load more when near the bottom: 80% of maxScrollExtent
                if (!_isLoading && _canLoadMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.8 && scrollInfo.metrics.maxScrollExtent > 0) {
                  _loadMore();
                  return true; 
                }
                return false;
              },
              child: _isLoading && _products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text( _isLoading ? 'Loading...' : (_searchController.text.isEmpty ? 'No products found.' : 'No products match your search.'), textAlign: TextAlign.center,),
                        ))
                      : ListView.builder(
                          itemCount: _products.length + (_canLoadMore && _products.isNotEmpty ? 1 : 0), // +1 for loading indicator if can load more
                          itemBuilder: (context, index) {
                            if (index == _products.length && _canLoadMore) { // Show loader at the end if we can load more
                              return const Center(child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ));
                            }
                            if (index >= _products.length) {
                              return Container(); 
                            }
                            final product = _products[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: ListTile(
                                title: Text(product.productName),
                                subtitle: Text(
                                    'SKU: ${product.sku ?? "N/A"} - Barcode: ${product.barcode ?? "N/A"}\\nUnits: ${product.units ?? "N/A"}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Qty: ${product.currentStock}'),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
