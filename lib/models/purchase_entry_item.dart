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
  final double purchasePricePerUnit; // Added field

  PurchaseEntryItem({
    required this.id,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unit,
    this.supplierName,
    required this.purchaseDate,
    required this.totalPurchasePrice,
    required this.purchasePricePerUnit, // Added to constructor
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
      purchasePricePerUnit: (data['purchasePricePerUnit'] as num?)?.toDouble() ?? 0.0, // Added to factory, defaulting to 0.0
    );
  }
}
