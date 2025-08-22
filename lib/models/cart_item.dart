class CartItem {
  final String productId;
  final String productName;
  final double price;
  int quantity;
  final String? sku;
  final int currentStock; // Stock at the time of adding to cart

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.sku,
    required this.currentStock,
  });

  // Optional: Method to convert CartItem to a map, if needed for Firestore subcollections or logging
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'sku': sku,
      // 'currentStock': currentStock, // Usually not stored with the sale record itself if it's for the product's state
    };
  }
}
