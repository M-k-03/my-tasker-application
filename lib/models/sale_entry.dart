import 'package:cloud_firestore/cloud_firestore.dart';

class SaleEntry {
  final String? id; // Firestore document ID
  final String productId;
  final String productName;
  final String? sku;
  final int quantitySold;
  final double pricePerUnitAtSale;
  final double totalAmountForProduct;
  final Timestamp createdAt; // Renamed from saleTimestamp
  final String shopId; // Added
  final String userId; // Added

  SaleEntry({
    this.id,
    required this.productId,
    required this.productName,
    this.sku,
    required this.quantitySold,
    required this.pricePerUnitAtSale,
    required this.totalAmountForProduct,
    required this.createdAt, // Renamed
    required this.shopId, // Added
    required this.userId, // Added
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'sku': sku,
      'quantitySold': quantitySold,
      'pricePerUnitAtSale': pricePerUnitAtSale,
      'totalAmountForProduct': totalAmountForProduct,
      'createdAt': createdAt, // Renamed
      'shopId': shopId, // Added
      'userId': userId,   // Added
    };
  }

  factory SaleEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception("SaleEntry data is null for document ${doc.id}");
    }
    return SaleEntry(
      id: doc.id,
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      sku: data['sku'] as String?, // sku can be null
      quantitySold: data['quantitySold'] as int? ?? 0,
      pricePerUnitAtSale: (data['pricePerUnitAtSale'] as num?)?.toDouble() ?? 0.0,
      totalAmountForProduct: (data['totalAmountForProduct'] as num?)?.toDouble() ?? 0.0,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(), // Renamed and reading 'createdAt'
      shopId: data['shopId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
    );
  }
}
