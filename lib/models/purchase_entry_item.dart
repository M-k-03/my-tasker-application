import 'package:cloud_firestore/cloud_firestore.dart';

// Model class to represent a purchase entry item
class PurchaseEntryItem {
  final String id;
  final String productName;
  final String sku;
  final double quantity;
  final String unit;
  final String? supplierName;
  final Timestamp purchaseDate;
  final double totalPurchasePrice;
  final double purchasePricePerUnit;
  final String shopId; // Added
  final String userId; // Added

  PurchaseEntryItem({
    required this.id,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unit,
    this.supplierName,
    required this.purchaseDate,
    required this.totalPurchasePrice,
    required this.purchasePricePerUnit,
    required this.shopId, // Added
    required this.userId, // Added
  });

  factory PurchaseEntryItem.fromSnapshot(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PurchaseEntryItem(
      id: doc.id,
      productName: data['productName'] ?? 'N/A',
      sku: data['sku'] ?? 'N/A',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: data['unit'] ?? 'units', // Default to 'units' if not present
      supplierName: data['supplierName'],
      purchaseDate: data['purchaseDate'] as Timestamp? ?? Timestamp.now(), // Handle potential null
      totalPurchasePrice: (data['totalPurchasePrice'] as num?)?.toDouble() ?? 0.0,
      purchasePricePerUnit: (data['purchasePricePerUnit'] as num?)?.toDouble() ?? 0.0,
      // For shopId and userId, default to empty string if not present in older documents.
      // Consider a more robust handling strategy if these are critical for all items.
      shopId: data['shopId'] as String? ?? '', 
      userId: data['userId'] as String? ?? '',
    );
  }

  // If you also convert PurchaseEntryItem objects to a Map for saving to Firestore,
  // you would add/update a toMap() method here:
  // Map<String, dynamic> toMap() {
  //   return {
  //     'productName': productName,
  //     'sku': sku,
  //     'quantity': quantity,
  //     'unit': unit,
  //     'supplierName': supplierName,
  //     'purchaseDate': purchaseDate,
  //     'totalPurchasePrice': totalPurchasePrice,
  //     'purchasePricePerUnit': purchasePricePerUnit,
  //     'shopId': shopId,
  //     'userId': userId,
  //   };
  // }
}
