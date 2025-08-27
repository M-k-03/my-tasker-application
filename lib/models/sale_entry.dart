import 'package:cloud_firestore/cloud_firestore.dart';

class SaleEntry {
  final String? id; // Firestore document ID
  final String productId;
  final String productName;
  final String? sku;
  final int quantitySold;
  final double pricePerUnitAtSale;
  final double totalAmountForProduct;
  final Timestamp saleTimestamp;
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
    required this.saleTimestamp,
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
      'saleTimestamp': saleTimestamp,
      'shopId': shopId, // Added
      'userId': userId,   // Added
    };
  }

  // Consider adding a factory constructor if you need to create SaleEntry from a map
  // factory SaleEntry.fromMap(Map<String, dynamic> map, String documentId) {
  //   return SaleEntry(
  //     id: documentId,
  //     productId: map['productId'],
  //     productName: map['productName'],
  //     sku: map['sku'],
  //     quantitySold: map['quantitySold'],
  //     pricePerUnitAtSale: map['pricePerUnitAtSale'],
  //     totalAmountForProduct: map['totalAmountForProduct'],
  //     saleTimestamp: map['saleTimestamp'],
  //     shopId: map['shopId'],
  //     userId: map['userId'],
  //   );
  // }
}
