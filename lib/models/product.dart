import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String productName;
  final double price;
  final String? sku;
  final String? barcode;
  final String? units;
  final DateTime? createdAt;
  final bool? isManuallyAddedSku;
  final int currentStock;

  String? category;
  String? imageUrl;
  int quantityToSell;

  Product({
    required this.id,
    required this.productName,
    required this.price,
    this.sku,
    this.barcode,
    this.units,
    this.createdAt,
    this.isManuallyAddedSku,
    required this.currentStock,
    this.category, // Added to constructor
    this.imageUrl, // Added to constructor
    this.quantityToSell = 0, // Default to 0
  });

  factory Product.fromFirestore(DocumentSnapshot doc, int stockQty) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      productName: data['productName'] as String? ?? 'N/A',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      sku: data['sku'] as String?,
      barcode: data['barcode'] as String?,
      units: data['units'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isManuallyAddedSku: data['isManuallyAddedSku'] as bool?,
      currentStock: stockQty,
      category: data['category'] as String?,
      imageUrl: data['imageUrl'] as String?,
      quantityToSell: 0,
    );
  }

  static Product createDummy({
    required String id,
    required String name,
    required double price,
    required int stock,
    String? sku,
    String? units,
    String? barcode,
    DateTime? createdAt,
    bool? isManuallyAddedSku,
    String? category,
    String? imageUrl,
  }) {
    return Product(
      id: id,
      productName: name,
      price: price,
      currentStock: stock,
      sku: sku ?? 'SKU-$id',
      units: units ?? 'pcs',
      barcode: barcode ?? 'BC-$id',
      createdAt: createdAt ?? DateTime.now().subtract(Duration(days: int.tryParse(id.replaceAll('P','')) ?? 1 % 30)),
      isManuallyAddedSku: isManuallyAddedSku ?? ((int.tryParse(id.replaceAll('P','')) ?? 1 % 2) == 0),
      category: category ?? 'Default Category',
      imageUrl: imageUrl,
      quantityToSell: 0,
    );
  }
}
