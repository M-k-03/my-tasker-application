import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_tasker/models/product.dart';
import 'package:my_tasker/models/sale_entry.dart';
import 'package:my_tasker/services/product_service.dart';
import 'dart:math'; // Required for shuffle

class SaleEntryScreen extends StatefulWidget {
  const SaleEntryScreen({super.key});

  @override
  State<SaleEntryScreen> createState() => _SaleEntryScreenState();
}

class _SaleEntryScreenState extends State<SaleEntryScreen> {
  final ProductService _productService = ProductService();
  List<Product> _searchResults = [];
  List<Product> _cartItems = [];
  List<Product> _frequentItems = [];
  bool _isLoadingFrequentItems = true;
  bool _isSearchingProducts = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  double _grandTotal = 0.0;
  bool _isLoadingSale = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchResults.isNotEmpty) {
        // if (_searchController.text.isEmpty) {
        //   setState(() {
        //     _searchResults = [];
        //   });
        // }
      }
    });
    _loadFrequentItems();
  }

  Future<void> _loadFrequentItems() async {
    if (!mounted) return;
    setState(() {
      _isLoadingFrequentItems = true;
    });
    try {
      List<Product> initialProducts = await _productService.getInitialProducts(limit: 20);
      if (mounted) {
        if (initialProducts.isNotEmpty) {
          final random = Random();
          initialProducts.shuffle(random);
          setState(() {
            _frequentItems = initialProducts.take(6).toList();
          });
        }
        setState(() {
          _isLoadingFrequentItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print("Error loading frequent items: $e");
        setState(() {
          _isLoadingFrequentItems = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final searchText = _searchController.text;
    if (searchText.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _isSearchingProducts = true;
        _searchResults = [];
      });
      _productService.searchProducts(searchText).then((products) {
        if (mounted) {
          setState(() {
            _searchResults = products
                .where((p) => !_cartItems.any((cartItem) => cartItem.id == p.id))
                .toList();
            _isSearchingProducts = false;
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _isSearchingProducts = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error searching products: $error')),
          );
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearchingProducts = false;
        });
      }
    }
  }

  void _addToCart(Product product) {
    final int quantityBeingAddedToCart = 1;

    setState(() {
      final existingCartItemIndex = _cartItems.indexWhere((item) => item.id == product.id);
      if (existingCartItemIndex != -1) {
        _cartItems[existingCartItemIndex].quantityToSell += quantityBeingAddedToCart;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Increased quantity for ${product.productName} in the cart.')),
        );
      } else {
        Product cartProduct = Product(
          id: product.id,
          productName: product.productName,
          price: product.price,
          category: product.category,
          sku: product.sku,
          barcode: product.barcode,
          units: product.units,
          createdAt: product.createdAt,
          isManuallyAddedSku: product.isManuallyAddedSku,
          currentStock: product.currentStock,
          imageUrl: product.imageUrl,
          quantityToSell: quantityBeingAddedToCart,
        );
        _cartItems.add(cartProduct);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.productName} added to cart.')),
        );
      }
      _calculateGrandTotal();

      if (_searchController.text.isNotEmpty && !_searchResults.any((p) => p.id == product.id)) {
        _searchController.clear();
      }
      _searchFocusNode.unfocus();
      _frequentItems = List<Product>.from(_frequentItems);
      if (_searchController.text.isNotEmpty) {
        _onSearchChanged();
      }
    });
  }

  void _removeFromCart(Product product) {
    setState(() {
      if (product.id == null) return;
      _cartItems.removeWhere((item) => item.id == product.id);
      _calculateGrandTotal();
      _frequentItems = List<Product>.from(_frequentItems);
      if(_searchController.text.isNotEmpty){
        _onSearchChanged();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.productName} removed from cart.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _updateQuantityInCart(Product product, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(product);
      return;
    }
    setState(() {
      final index = _cartItems.indexWhere((item) => item.id == product.id);
      if (index != -1) {
        _cartItems[index].quantityToSell = newQuantity;
        _calculateGrandTotal();
      }
    });
  }

  void _calculateGrandTotal() {
    _grandTotal = _cartItems.fold(0.0, (sum, item) {
      return sum + (item.price * item.quantityToSell);
    });
  }

  Future<void> _completeSale() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty. Add products to sell.')),
      );
      return;
    }

    setState(() {
      _isLoadingSale = true;
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();
      Timestamp saleTimestamp = Timestamp.now();

      for (var itemInCart in _cartItems) {
        if (itemInCart.quantityToSell <= 0) continue;

        SaleEntry saleEntry = SaleEntry(
          productId: itemInCart.id,
          productName: itemInCart.productName,
          sku: itemInCart.sku,
          quantitySold: itemInCart.quantityToSell,
          pricePerUnitAtSale: itemInCart.price,
          totalAmountForProduct: itemInCart.price * itemInCart.quantityToSell,
          saleTimestamp: saleTimestamp,
        );
        DocumentReference saleDocRef = firestore.collection('sale_entries').doc();
        batch.set(saleDocRef, saleEntry.toMap());
      }

      await batch.commit();

      setState(() {
        _cartItems = [];
        _calculateGrandTotal();
        _isLoadingSale = false;
        _frequentItems = List<Product>.from(_frequentItems);
        if(_searchController.text.isNotEmpty) _onSearchChanged();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error completing sale: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing sale: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoadingSale = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentSearchText = _searchController.text;
    final bool hasSearchText = currentSearchText.isNotEmpty;

    final bool showInitialLoadingIndicator = _isLoadingFrequentItems && !hasSearchText;
    final bool showFrequentItemsGrid = !_isLoadingFrequentItems && _frequentItems.isNotEmpty && !hasSearchText;

    final bool showSearchLoadingIndicator = hasSearchText && _isSearchingProducts;
    final bool showSearchResultsGrid = hasSearchText && !_isSearchingProducts && _searchResults.isNotEmpty;
    final bool showNoSearchResultsMessage = hasSearchText && !_isSearchingProducts && _searchResults.isEmpty;

    List<Product> productsToDisplayInGrid = [];
    String gridTitleText = "";
    bool shouldDisplayGrid = false;

    if (showFrequentItemsGrid) {
      productsToDisplayInGrid = _frequentItems;
      shouldDisplayGrid = true;
    } else if (showSearchResultsGrid) {
      productsToDisplayInGrid = _searchResults;
      shouldDisplayGrid = true;
    }

    bool isGridSectionVisible = shouldDisplayGrid || showSearchLoadingIndicator || showNoSearchResultsMessage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 1.0,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined, size: 28),
                    tooltip: 'View Cart (${_cartItems.length})',
                    onPressed: () {
                      print('Cart icon tapped. Items: ${_cartItems.length}');
                    },
                  ),
                  if (_cartItems.isNotEmpty)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '${_cartItems.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search products by name, SKU, or barcode...',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),

          if (showInitialLoadingIndicator)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (shouldDisplayGrid)
            Padding(
              padding: EdgeInsets.only(left: 12.0, right: 12.0, top: 8.0, bottom: _cartItems.isNotEmpty ? 0 : 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (gridTitleText.isNotEmpty)
                    Text(
                      gridTitleText,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                    ),
                  if (gridTitleText.isNotEmpty) const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: productsToDisplayInGrid.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.8,
                    ),
                    itemBuilder: (context, index) {
                      final product = productsToDisplayInGrid[index];
                      bool isInCart = _cartItems.any((item) => item.id == product.id);
                      return InkWell(
                        onTap: () => _addToCart(product),
                        child: Card(
                          elevation: 2,
                          color: isInCart ? Colors.grey[300] : null,
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 18, color: isInCart ? Colors.grey[700] : Theme.of(context).colorScheme.secondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        product.productName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isInCart ? Colors.black54 : Colors.black,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
          else if (showSearchLoadingIndicator)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (showNoSearchResultsMessage)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: Text('No products found for "$currentSearchText".', style: TextStyle(fontSize: 16, color: Colors.grey[600]))),
                ),

          if (_cartItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Items (${_cartItems.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                  ),
                  Text(
                    'Grand Total: ₹${_grandTotal.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green[700]),
                  ),
                ],
              ),
            ),

          if (isGridSectionVisible || _cartItems.isNotEmpty)
            const Divider(
              height: 1.0,
              thickness: 0.5,
              indent: 16.0,
              endIndent: 16.0,
              color: Colors.grey,
            ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _cartItems.isEmpty && !isGridSectionVisible && !showInitialLoadingIndicator
                      ? Padding(
                    padding: const EdgeInsets.only(top: 16.0, left: 16, right: 16),
                    child: Center(
                      child: Text(
                        'Search or add from frequent items to build a cart.',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final itemInCart = _cartItems[index];
                      final itemKey = itemInCart.id ?? DateTime.now().millisecondsSinceEpoch.toString();
                      final TextEditingController qtyController = TextEditingController(text: itemInCart.quantityToSell.toString());
                      qtyController.selection = TextSelection.fromPosition(TextPosition(offset: qtyController.text.length));

                      return Dismissible(
                        key: Key(itemKey),
                        onDismissed: (direction) {
                          _removeFromCart(itemInCart);
                        },
                        background: Container(
                          color: Colors.red[400],
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          alignment: Alignment.centerRight,
                          child: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          elevation: 2.0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          child: ListTile(
                            title: Text(itemInCart.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('SKU: ${itemInCart.sku ?? "N/A"} - Price: ₹${itemInCart.price.toStringAsFixed(2)}'),
                            trailing: SizedBox(
                              width: 160,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _updateQuantityInCart(itemInCart, itemInCart.quantityToSell - 1),
                                  ),
                                  SizedBox(
                                    width: 30,
                                    child: TextField(
                                      controller: qtyController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                      onSubmitted: (value) {
                                        final newQuantity = int.tryParse(value) ?? itemInCart.quantityToSell;
                                        _updateQuantityInCart(itemInCart, newQuantity);
                                      },
                                      onEditingComplete: () { FocusScope.of(context).unfocus(); },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _updateQuantityInCart(itemInCart, itemInCart.quantityToSell + 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  if (_cartItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 12.0),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoadingSale ? null : _completeSale,
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all<Color>(Colors.green),
                                padding: MaterialStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.symmetric(vertical: 16.0)),
                                shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
                                elevation: MaterialStateProperty.all<double>(2.0),
                              ),
                              child: _isLoadingSale
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                  : const Text('Complete Sale', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          // MODIFIED: Added SizedBox for space below the button
                          const SizedBox(height: 50.0),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

