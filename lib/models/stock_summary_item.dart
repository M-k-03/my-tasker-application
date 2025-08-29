import 'package:cloud_firestore/cloud_firestore.dart';

class StockSummaryItem {
  final String id; // Document ID from Firestore
  final String productId;
  final String productName;
  final String productName_lowercase;
  final String? sku;
  final int currentStock;
  final String shopId;
  final String? units;
  final double price; // Selling price
  final Timestamp lastUpdated;

  StockSummaryItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productName_lowercase,
    this.sku,
    required this.currentStock,
    required this.shopId,
    this.units,
    required this.price,
    required this.lastUpdated,
  });

  factory StockSummaryItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return StockSummaryItem(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? 'N/A',
      productName_lowercase: data['productName_lowercase'] ?? (data['productName'] ?? 'N/A').toLowerCase(),
      sku: data['sku'] as String?,
      currentStock: (data['currentStock'] as num?)?.toInt() ?? 0,
      shopId: data['shopId'] ?? '',
      units: data['units'] as String?,
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: data['lastUpdated'] ?? Timestamp.now(),
    );
  }

  // Method to convert a StockSummaryItem object into a map for Firestore.
  // The 'id' field is typically not included in the map written to Firestore,
  // as it's the document ID.
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productName_lowercase': productName_lowercase,
      'sku': sku,
      'currentStock': currentStock,
      'shopId': shopId,
      'units': units,
      'price': price,
      // 'lastUpdated' should be handled by FieldValue.serverTimestamp() directly in the service
      // when writing to Firestore for it to be a server-side timestamp.
      // If including it here from the model, it would be the client-side Timestamp.now()
      // or the value read from Firestore. For writes, StockService handles it.
    };
  }
}
