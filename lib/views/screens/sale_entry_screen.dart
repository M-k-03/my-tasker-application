import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:my_tasker/models/product.dart';
import 'package:my_tasker/models/sale_entry.dart';
import 'package:my_tasker/models/cart_item.dart'; // Added import for CartItem
import 'package:my_tasker/services/product_service.dart';
import 'package:my_tasker/services/sale_service.dart';
import 'package:my_tasker/utils/app_colors.dart';
import 'package:my_tasker/utils/validators.dart';
import 'package:my_tasker/views/widgets/custom_app_bar.dart';
import 'package:my_tasker/views/widgets/custom_button.dart';
import 'package:my_tasker/views/widgets/custom_text_field.dart';

class SaleEntryScreen extends StatefulWidget {
  const SaleEntryScreen({super.key});

  @override
  State<SaleEntryScreen> createState() => _SaleEntryScreenState();
}

class _SaleEntryScreenState extends State<SaleEntryScreen> {
  final ProductService _productService = ProductService();
  final SaleService _saleService = SaleService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerMobileController = TextEditingController();
  final GlobalKey<FormState> _customerFormKey = GlobalKey<FormState>();

  MobileScannerController? _scannerController;

  List<Product> _frequentlyPurchasedProducts = [];
  List<Product> _searchResults = [];
  List<CartItem> _cart = [];
  bool _isLoading = false;
  bool _showFrequentItems = true;
  bool _isFrequentProductsExpanded = false; // MODIFIED: Added state for expansion

  // UI Feedback State
  String _uiFeedbackMessage = '';
  Color _uiFeedbackMessageColor = AppColors.textColor; // Default color

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      // autoStart: false, // Default is true, MobileScanner widget will handle starting
    );
    _loadFrequentlyPurchasedProducts();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        _searchProducts(''); // Clear search results and show frequent items
        _clearUiFeedback(); // Clear feedback when search is cleared
      } else {
        _searchProducts(_searchController.text);
      }
    });
  }

  void _setUiFeedback(String message, Color color) {
    if (mounted) {
      setState(() {
        _uiFeedbackMessage = message;
        _uiFeedbackMessageColor = color;
      });
    }
  }

  void _clearUiFeedback() {
    if (mounted) {
      setState(() {
        _uiFeedbackMessage = '';
      });
    }
  }

  // MODIFIED: Added toggle function
  void _toggleFrequentProductsExpansion() {
    setState(() {
      _isFrequentProductsExpanded = !_isFrequentProductsExpanded;
    });
  }

  Widget _buildFeedbackWidget() {
    if (_uiFeedbackMessage.isEmpty) {
      return const SizedBox.shrink(); // Return an empty widget if no message
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(
        _uiFeedbackMessage,
        style: TextStyle(color: _uiFeedbackMessageColor, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _loadFrequentlyPurchasedProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      _frequentlyPurchasedProducts = await _productService.getFrequentlyPurchasedProducts(limit: 10); // Still fetch 10, display 3 or 7
      print('Fetched frequently purchased: $_frequentlyPurchasedProducts');
      if (mounted) {
        for (var p in _frequentlyPurchasedProducts) {
          print('Frequent Product: ${p.productName}, Stock: ${p.currentStock}');
        }
      }
      _clearUiFeedback();
    } catch (e) {
      print('Error loading frequent items: $e');
      _setUiFeedback("Error loading frequent items: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchProducts(String query) async {
    if (!mounted) return;
    _clearUiFeedback();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showFrequentItems = true;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _showFrequentItems = false;
    });
    try {
      final String queryLowercase = query.toLowerCase();
      _searchResults = await _productService.searchProducts(queryLowercase);
      if (_searchResults.isEmpty && query.isNotEmpty) {
        _setUiFeedback("No products found for '$query'.", AppColors.textColor);
      }
    } catch (e) {
      _setUiFeedback("Error searching products: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanBarcode() async {
    if (!mounted) return;
    _clearUiFeedback();
    try {
      if (_scannerController == null) {
        _setUiFeedback("Scanner controller not initialized. Please try again or restart the screen.", Colors.red);
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Scan Barcode'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: MobileScanner(
                controller: _scannerController,
                onDetect: (BarcodeCapture capture) {
                  if (!mounted) return;
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                    final String scannedValue = barcodes.first.rawValue!;
                    _scannerController?.stop();
                    Navigator.of(context).pop();
                    _handleScannedBarcode(scannedValue);
                  }
                },
                errorBuilder: (context, error) {
                  return Center(child: Text('Error starting camera: ${error.toString()}'));
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  if(mounted) {
                    _scannerController?.stop();
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        },
      ).then((_) {
        if (_scannerController !=null && _scannerController!.value.isRunning){
          _scannerController!.stop();
        }
      });
    } catch (e) {
      _setUiFeedback("Error opening scanner: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _handleScannedBarcode(String barcodeValue) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      List<Product> productsFound = await _productService.searchProducts(barcodeValue);

      if (productsFound.isEmpty) {
        _setUiFeedback("Product with barcode '$barcodeValue' not found.", Colors.orangeAccent);
      } else if (productsFound.length == 1) {
        final product = productsFound.first;
        if (product.currentStock <= 0) {
          _setUiFeedback("${product.productName} is out of stock.", Colors.orangeAccent);
        } else {
          _addToCart(product);
          _setUiFeedback("${product.productName} added to cart.", Colors.green);
          _searchController.clear();
        }
      } else {
        _setUiFeedback("Multiple products found for this barcode. Please search manually.", Colors.orangeAccent);
      }
    } catch (e) {
      _setUiFeedback("Error processing barcode: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  void _addToCart(Product product) {
    print('Attempting to add to cart: ${product.productName}, Stock: ${product.currentStock}');
    if (!mounted) {
      print('_addToCart: not mounted');
      return;
    }
    _clearUiFeedback();
    if (product.currentStock <= 0) {
      print('${product.productName} is out of stock.');
      _setUiFeedback("${product.productName} is out of stock.", Colors.orangeAccent);
      return;
    }

    final int existingItemIndex = _cart.indexWhere((item) => item.productId == product.id);
    print('Existing item index: $existingItemIndex');

    print('Calling setState in _addToCart for ${product.productName}');
    setState(() {
      if (existingItemIndex != -1) {
        if (_cart[existingItemIndex].quantity < product.currentStock) {
          _cart[existingItemIndex].quantity++;
          _setUiFeedback("${product.productName} quantity updated in cart.", Colors.green);
        } else {
          _setUiFeedback("Max stock reached for ${product.productName}.", Colors.orangeAccent);
        }
      } else {
        _cart.add(CartItem(
          productId: product.id,
          productName: product.productName,
          price: product.price,
          quantity: 1,
          sku: product.sku,
          currentStock: product.currentStock,
        ));
        _setUiFeedback("${product.productName} added to cart.", Colors.green);
      }
      print('Cart after update: $_cart');
    });
    print('Finished _addToCart for ${product.productName}');
  }

  void _removeCartItem(int index) {
    if (!mounted) return;
    setState(() {
      _setUiFeedback("${_cart[index].productName} removed from cart.", AppColors.textColor);
      _cart.removeAt(index);
    });
  }

  void _updateCartItemQuantity(int index, int newQuantity) {
    if (!mounted) return;
    _clearUiFeedback();
    final item = _cart[index];
    if (newQuantity <= 0) {
      _removeCartItem(index);
    } else if (newQuantity > item.currentStock) {
      _setUiFeedback("Only ${item.currentStock} units of ${item.productName} available.", Colors.orangeAccent);
    }
    else {
      setState(() {
        _cart[index].quantity = newQuantity;
        _setUiFeedback("${item.productName} quantity updated.", Colors.green);
      });
    }
  }

  double _calculateTotal() {
    return _cart.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  Future<void> _completeSale() async {
    if (!mounted) return;
    _clearUiFeedback();

    if (_cart.isEmpty) {
      _setUiFeedback("Cart is empty. Please add products.", Colors.orangeAccent);
      return;
    }

    if (_customerFormKey.currentState?.validate() != true) {
      _setUiFeedback("Please enter valid customer details.", Colors.orangeAccent);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool stockSufficient = true;
      List<String> stockIssues = [];

      for (var cartItem in _cart) {
        Product? productDetails = await _productService.getProductDetailsById(cartItem.productId);

        if (productDetails == null) {
          stockSufficient = false;
          stockIssues.add("${cartItem.productName} (ID: ${cartItem.productId}) not found or error fetching details.");
          continue;
        }

        int liveStock = productDetails.currentStock;

        if (cartItem.quantity > liveStock) {
          stockSufficient = false;
          stockIssues.add(
              "${productDetails.productName}: Requested ${cartItem.quantity}, Available ${liveStock}");
        }
      }

      if (!stockSufficient) {
        _setUiFeedback("Stock changed: ${stockIssues.join(', ')}. Please review cart.", Colors.red);
        if (mounted) {
          setState(() {_isLoading = false;});
        }
        return;
      }

      await _saleService.recordSaleAndUpdateStock(_cart);

      _setUiFeedback("Sale recorded successfully!", Colors.green);
      if (mounted) {
        setState(() {
          _cart.clear();
          _customerNameController.clear();
          _customerMobileController.clear();
          _searchController.clear();
          _showFrequentItems = true;
        });
      }
      _loadFrequentlyPurchasedProducts();
    } catch (e) {
      _setUiFeedback("Error recording sale: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerMobileController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'New Sale / Billing'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer Details Form
              Form(
                key: _customerFormKey,
                child: Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _customerNameController,
                        labelText: 'Customer Name',
                        hintText: 'Optional',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: _customerMobileController,
                        labelText: 'Customer Mobile',
                        hintText: 'Optional',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return null;
                          }
                          return Validators.validateMobile(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Product Search
              CustomTextField(
                controller: _searchController,
                labelText: 'Search Products (Name/SKU/Barcode)',
                hintText: 'Type to search...',
                prefixIcon: Icons.search,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                  tooltip: 'Scan Barcode',
                ),
              ),
              const SizedBox(height: 8),

              _buildFeedbackWidget(),

              // Product Display Area (Frequent or Search Results)
              _isLoading && (_showFrequentItems || _searchResults.isNotEmpty)
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MODIFIED: Header for Frequently Purchased
                  if (_showFrequentItems && _frequentlyPurchasedProducts.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Frequently Purchased:',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          icon: Icon(_isFrequentProductsExpanded ? Icons.remove_circle_outline : Icons.add_circle_outline),
                          tooltip: _isFrequentProductsExpanded ? 'Show less' : 'Show more',
                          onPressed: _toggleFrequentProductsExpansion,
                        ),
                      ],
                    ),
                  _showFrequentItems
                      ? _buildProductList(_frequentlyPurchasedProducts, isFrequentlyPurchased: true)
                      : _buildProductList(_searchResults, isFrequentlyPurchased: false),
                ],
              ),

              const Divider(thickness: 1),

              // Cart Section
              Text(
                'Cart Items (${_cart.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, right: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Product',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Qty',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Subtotal',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.black, height: 1, thickness: 1),
              _cart.isEmpty
                  ? const Center(child: Text('Cart is empty.'))
                  : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cart.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.black, height: 1, thickness: 1),
                itemBuilder: (context, index) {
                  final item = _cart[index];
                  return Dismissible(
                    key: ValueKey(item.productId + item.productName + index.toString()),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      _removeCartItem(index);
                    },
                    background: Container(
                      color: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: AlignmentDirectional.centerEnd,
                      child: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.white,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              item.productName,
                              style: Theme.of(context).textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Decrease quantity',
                                  onPressed: () => _updateCartItemQuantity(index, item.quantity - 1),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Text(
                                    item.quantity.toString(),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline, color: AppColors.primaryColor, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Increase quantity',
                                  onPressed: () => _updateCartItemQuantity(index, item.quantity + 1),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ₹${_calculateTotal().toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  CustomButton(
                    text: 'Complete Sale',
                    onPressed: _isLoading ? null : _completeSale,
                    isLoading: _isLoading,
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(List<Product> products, {bool isFrequentlyPurchased = false}) {
    if (_isLoading && products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (products.isEmpty && !_isLoading && !_showFrequentItems && _searchController.text.isNotEmpty) {
      return const SizedBox.shrink();
    }
    if (products.isEmpty && _showFrequentItems && !_isLoading) {
      return const Center(child: Text('No frequently purchased items found.'));
    }

    // MODIFIED: Dynamic item count for frequently purchased list
    int itemCount;
    if (isFrequentlyPurchased) {
      if (_isFrequentProductsExpanded) {
        itemCount = products.length > 7 ? 7 : products.length; // Max 7 when expanded
      } else {
        itemCount = products.length > 3 ? 3 : products.length; // Max 3 when collapsed
      }
    } else {
      itemCount = products.length;
    }

    if (itemCount == 0 && isFrequentlyPurchased) { // If no frequent items to show based on count, show message or shrink
      return _frequentlyPurchasedProducts.isEmpty ? const Center(child: Text('No frequently purchased items found.')) : const SizedBox.shrink();
    }


    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount, // MODIFIED
      itemBuilder: (context, index) {
        final product = products[index];
        bool isOutOfStock = product.currentStock <= 0;
        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
          child: ListTile(
            title: Text(product.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                isFrequentlyPurchased
                    ? 'Price: ₹${product.price.toStringAsFixed(2)} | Stock: ${product.currentStock}'
                    : 'SKU: ${product.sku} | Price: ₹${product.price.toStringAsFixed(2)} | Stock: ${product.currentStock}'
            ),
            trailing: IconButton(
              icon: Icon(Icons.add_shopping_cart, color: isOutOfStock ? Colors.grey : AppColors.primaryColor),
              onPressed: isOutOfStock ? null : () => _addToCart(product),
              tooltip: isOutOfStock ? 'Out of Stock' : 'Add to Cart',
            ),
            onTap: isOutOfStock ? null : () => _addToCart(product),
          ),
        );
      },
    );
  }
}
