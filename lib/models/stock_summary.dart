import 'package:cloud_firestore/cloud_firestore.dart';

class StockSummary {
  final String id; // Document ID, typically shopId_productId
  final String shopId;
  final String productId;
  final String productName;
  final String sku;
  final int totalPurchased;
  final int totalSold;
  final int availableStock;
  final Timestamp lastUpdated;

  StockSummary({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.totalPurchased,
    required this.totalSold,
    required this.availableStock,
    required this.lastUpdated,
  });

  factory StockSummary.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception("StockSummary data is null!");
    }
    return StockSummary(
      id: doc.id,
      shopId: data['shopId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      sku: data['sku'] as String? ?? '',
      totalPurchased: data['totalPurchased'] as int? ?? 0,
      totalSold: data['totalSold'] as int? ?? 0,
      availableStock: data['availableStock'] as int? ?? 0,
      lastUpdated: data['lastUpdated'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'productId': productId,
      'productName': productName,
      'sku': sku,
      'totalPurchased': totalPurchased,
      'totalSold': totalSold,
      'availableStock': availableStock,
      'lastUpdated': lastUpdated, // Or FieldValue.serverTimestamp() if preferred on write
    };
  }
}
