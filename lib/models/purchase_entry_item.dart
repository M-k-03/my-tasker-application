import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseEntryItem {
  final String id;
  final String productId; // Added
  final String productName;
  final String sku;
  final int quantityPurchased; // Changed from double quantity
  final String unit;
  final String? supplierName;
  final Timestamp purchaseDate; // Added to read the actual purchaseDate field
  final Timestamp createdAt; // For existing createdAt field or future use
  final double totalPurchasePrice;
  final double purchasePricePerUnit;
  final String shopId;
  final String userId; // Added userId field
  final Timestamp? expiryDate;
  final String? notes; // Added for notes

  PurchaseEntryItem({
    required this.id,
    required this.productId, // Added
    required this.productName,
    required this.sku,
    required this.quantityPurchased,
    required this.unit,
    this.supplierName,
    required this.purchaseDate,
    required this.createdAt,
    required this.totalPurchasePrice,
    required this.purchasePricePerUnit,
    required this.userId, // Added to constructor
    required this.shopId,
    this.expiryDate,
    this.notes, // Added for notes
  });

  factory PurchaseEntryItem.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return PurchaseEntryItem(
      id: snapshot.id,
      productId: data['productId'] as String? ?? '', // Added
      productName: data['productName'] ?? 'N/A',
      sku: data['sku'] ?? 'N/A',
      // Read from the 'quantity' field in Firestore
      quantityPurchased: (data['quantity'] as num?)?.toInt() ?? 0, // CHANGED: Read from 'quantity'
      unit: data['unit'] ?? 'units', // Default to 'units' if not present
      supplierName: data['supplierName'],
      purchaseDate: data['purchaseDate'] as Timestamp? ?? Timestamp.now(), // Read from 'purchaseDate'
      createdAt: data['createdAt'] as Timestamp? ?? data['purchaseDate'] as Timestamp? ?? Timestamp.now(), // Fallback for createdAt
      totalPurchasePrice: (data['totalPurchasePrice'] as num?)?.toDouble() ?? 0.0,
      purchasePricePerUnit: (data['purchasePricePerUnit'] as num?)?.toDouble() ?? 0.0,
      shopId: data['shopId'] as String? ?? '',
      userId: data['userId'] as String? ?? '', // Read userId
      expiryDate: data['expiryDate'] as Timestamp?,
      notes: data['notes'] as String?, // Added for notes
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId, // Added
      'productName': productName,
      'sku': sku,
      'quantityPurchased': quantityPurchased,
      'unit': unit,
      'purchaseDate': purchaseDate,
      'supplierName': supplierName,
      'createdAt': createdAt,
      'totalPurchasePrice': totalPurchasePrice,
      'purchasePricePerUnit': purchasePricePerUnit,
      'userId': userId, // Add userId to map
      'shopId': shopId,
      'expiryDate': expiryDate,
      'notes': notes, // Added for notes
    };
  }
}
