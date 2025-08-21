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

  SaleEntry({
    this.id,
    required this.productId,
    required this.productName,
    this.sku,
    required this.quantitySold,
    required this.pricePerUnitAtSale,
    required this.totalAmountForProduct,
    required this.saleTimestamp,
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
    };
  }
}
