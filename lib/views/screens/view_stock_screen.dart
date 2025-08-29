import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_tasker/models/stock_summary_item.dart'; // Import the new model

class ViewStockScreen extends StatefulWidget {
  final String shopId; // Added shopId
  const ViewStockScreen({super.key, required this.shopId}); // Modified to accept shopId

  @override
  State<ViewStockScreen> createState() => _ViewStockScreenState();
}

class _ViewStockScreenState extends State<ViewStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<StockSummaryItem> _stockSummaryItems = []; // Changed from Product to StockSummaryItem
  bool _isLoading = false;
  final int _itemsPerPage = 15;
  DocumentSnapshot? _lastFetchedStockSummaryDocument; // Renamed
  bool _canLoadMore = true;

  @override
  void initState() {
    super.initState();
    print("DEBUG ViewStockScreen (${widget.shopId}): initState called. Fetching initial stock summary.");
    _fetchStockSummaryItems(); // Initial fetch - Renamed method
  }

  @override
  void dispose() {
    _searchController.dispose();
    print("DEBUG ViewStockScreen (${widget.shopId}): dispose called (Stock Summary).");
    super.dispose();
  }

  Future<void> _fetchStockSummaryItems({String searchQuery = '', bool isPaginating = false}) async {
    print("DEBUG ViewStockScreen (${widget.shopId}): _fetchStockSummaryItems - Shop: ${widget.shopId}, Search: '$searchQuery', Paginating: $isPaginating, IsLoading: $_isLoading, CanLoadMore: $_canLoadMore");

    if (_isLoading && isPaginating) {
      print("DEBUG ViewStockScreen (${widget.shopId}): Already loading more stock summary (paginating), returning.");
      return;
    }
    if (!isPaginating && _isLoading) {
      print("DEBUG ViewStockScreen (${widget.shopId}): Already loading stock summary (new search/initial), returning.");
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      if (!isPaginating) {
        print("DEBUG ViewStockScreen (${widget.shopId}): Resetting stock summary list for new search/initial load.");
        _stockSummaryItems = [];
        _lastFetchedStockSummaryDocument = null;
        _canLoadMore = true; // Reset on new search
      }
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      // Query 'stock_summary' collection instead of 'master_products'
      Query query = firestore
          .collection('stock_summary') // CHANGED: Target collection
          .where('shopId', isEqualTo: widget.shopId); // Filter by shopId

      String trimmedSearchQuery = searchQuery.trim();
      String lowerCaseSearchQueryForQuery = "";

      if (trimmedSearchQuery.isNotEmpty) {
        lowerCaseSearchQueryForQuery = trimmedSearchQuery.toLowerCase();
        // Assuming 'productName_lowercase' exists in 'stock_summary' and is suitable for search
        query = query.orderBy('productName_lowercase');
        query = query
            .where('productName_lowercase', isGreaterThanOrEqualTo: lowerCaseSearchQueryForQuery)
            .where('productName_lowercase', isLessThanOrEqualTo: '$lowerCaseSearchQueryForQuery\\uf8ff');
        print("DEBUG ViewStockScreen (${widget.shopId}): Applying search to 'productName_lowercase' in stock_summary: '$lowerCaseSearchQueryForQuery'");
      } else {
        query = query.orderBy('productName_lowercase'); // Default order if no search query
        print("DEBUG ViewStockScreen (${widget.shopId}): No search query provided. Fetching all products ordered by 'productName_lowercase'.");
      }

      if (isPaginating && _lastFetchedStockSummaryDocument != null) { // Renamed variable
        print("DEBUG ViewStockScreen (${widget.shopId}): Paginating stock summary. Starting after doc ID: ${_lastFetchedStockSummaryDocument!.id}");
        query = query.startAfterDocument(_lastFetchedStockSummaryDocument!);
      }
      query = query.limit(_itemsPerPage);

      QuerySnapshot stockSummarySnapshot = await query.get(); // Renamed snapshot
      print("DEBUG ViewStockScreen (${widget.shopId}): Fetched ${stockSummarySnapshot.docs.length} stock summary documents for shop ${widget.shopId}.");

      if (!mounted) return;

      if (stockSummarySnapshot.docs.isEmpty) {
        setState(() {
          if (isPaginating) {
            _canLoadMore = false;
            print("DEBUG ViewStockScreen (${widget.shopId}): No more stock summary items to paginate for shop ${widget.shopId}.");
          }
          _isLoading = false;
        });
        if (!isPaginating && _stockSummaryItems.isEmpty) { // Check renamed list
          if (trimmedSearchQuery.isNotEmpty) {
            print("DEBUG ViewStockScreen (${widget.shopId}): No stock items found matching search criteria '$lowerCaseSearchQueryForQuery' for shop ${widget.shopId}.");
          } else {
            print("DEBUG ViewStockScreen (${widget.shopId}): No stock items found initially for shop ${widget.shopId}.");
          }
        }
        return;
      }

      if (stockSummarySnapshot.docs.isNotEmpty) {
        _lastFetchedStockSummaryDocument = stockSummarySnapshot.docs.last; // Renamed variable
      }
      if (stockSummarySnapshot.docs.length < _itemsPerPage) {
        _canLoadMore = false;
        print("DEBUG ViewStockScreen (${widget.shopId}): Fetched less than itemsPerPage from stock_summary, setting _canLoadMore to false.");
      }

      // Convert documents to StockSummaryItem objects
      List<StockSummaryItem> fetchedBatchItems = stockSummarySnapshot.docs
          .map((doc) => StockSummaryItem.fromFirestore(doc))
          .toList();

      if (!mounted) return;
      setState(() {
        if (isPaginating) {
          _stockSummaryItems.addAll(fetchedBatchItems); // Add to renamed list
          print("DEBUG ViewStockScreen (${widget.shopId}): Added ${fetchedBatchItems.length} paginated stock items. Total: ${_stockSummaryItems.length}");
        } else {
          _stockSummaryItems = fetchedBatchItems; // Set renamed list
          print("DEBUG ViewStockScreen (${widget.shopId}): Set ${fetchedBatchItems.length} stock items for new search/initial.");
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
    _fetchStockSummaryItems(searchQuery: query, isPaginating: false); // Call renamed method
  }

  void _loadMore() {
    print("DEBUG ViewStockScreen (${widget.shopId}): _loadMore stock summary called. CanLoadMore: $_canLoadMore, IsLoading: $_isLoading");
    if (!_isLoading && _canLoadMore) {
      _fetchStockSummaryItems(searchQuery: _searchController.text, isPaginating: true); // Call renamed method
    } else {
      print("DEBUG ViewStockScreen (${widget.shopId}): _loadMore - conditions not met.");
    }
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG ViewStockScreen (${widget.shopId}): build - Stock Items: ${_stockSummaryItems.length}, Loading: $_isLoading, CanLoadMore: $_canLoadMore");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              print("DEBUG ViewStockScreen (${widget.shopId}): Refresh button pressed.");
              _fetchStockSummaryItems(searchQuery: _searchController.text, isPaginating: false); // Call renamed method
            },
          )
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              key: const Key("search_stock_field"),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Product Name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!_isLoading &&
                    _canLoadMore &&
                    scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                  _loadMore();
                }
                return false;
              },
              child: (_isLoading && _stockSummaryItems.isEmpty) // Check renamed list
                  ? const Center(child: CircularProgressIndicator(key: Key("initial_full_loader")))
                  : _stockSummaryItems.isEmpty // Check renamed list
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      _isLoading ? 'Loading...' : (_searchController.text.isEmpty ? 'No stock items found.' : 'No stock items match your search.'),
                      textAlign: TextAlign.center,
                      key: const Key("no_products_text")
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: _stockSummaryItems.length + (_canLoadMore && _stockSummaryItems.isNotEmpty ? 1 : 0), // Use renamed list
                itemBuilder: (context, index) {
                  if (index == _stockSummaryItems.length && _canLoadMore && _stockSummaryItems.isNotEmpty) { // Use _stockSummaryItems here
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(key: Key("pagination_loader")),
                      ),
                    );
                  }
                  if (index >= _stockSummaryItems.length) { // Use renamed list
                    return Container(); // Should not happen with correct itemCount
                  }
                  final stockItem = _stockSummaryItems[index]; // Use StockSummaryItem

                  ShapeBorder cardShape;
                  // Use stockItem.currentStock
                  if (stockItem.currentStock == 0) {
                    cardShape = RoundedRectangleBorder(
                      side: BorderSide(color: Colors.redAccent[700] ?? Colors.redAccent, width: 1.5),
                      borderRadius: BorderRadius.circular(8.0),
                    );
                  } else {
                    cardShape = RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0));
                  }

                  // Use stockItem.id or stockItem.productId for key
                  return Card(
                    key: Key("stock_item_card_${stockItem.id}"), // Use id from StockSummaryItem
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    shape: cardShape,
                    elevation: 2.0,
                    child: ListTile(
                      title: Text(stockItem.productName), // Use stockItem properties
                      subtitle: Text(
                          'SKU: ${stockItem.sku ?? "N/A"} - Units: ${stockItem.units ?? "N/A"}'), // Use stockItem properties
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            'Qty: ${stockItem.currentStock}', // Use stockItem.currentStock
                            style: TextStyle(
                              color: stockItem.currentStock == 0 // Use stockItem.currentStock
                                  ? Colors.redAccent[700]
                                  : Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('Price: \$${stockItem.price.toStringAsFixed(2)}'), // Use stockItem.price
                        ],
                      ),
                      isThreeLine: true,
                      // onTap: () {
                      //   // TODO: Navigate to product detail screen or edit stock screen if needed
                      //   print("Tapped on ${stockItem.productName}");
                      // },
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
