import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_tasker/models/product.dart'; // Ensure this path is correct

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Product>> searchProducts(String query) async {
    if (query.isEmpty) {
      return [];
    }
    String searchQuery = query;
    List<Product> products = [];
    Set<String> productIds = {}; // To avoid duplicate products in search results

    try {
      print("DEBUG ProductService: searchProducts called with query: '$searchQuery'");

      // Search by Product Name
      QuerySnapshot nameSnapshot = await _firestore
          .collection('master_products')
          .where('productName', isGreaterThanOrEqualTo: searchQuery)
          .where('productName', isLessThanOrEqualTo: searchQuery + '\uf8ff')
          .limit(10) // Limit results for performance
          .get();

      print("DEBUG ProductService: Name search returned ${nameSnapshot.docs.length} docs.");
      for (var doc in nameSnapshot.docs) {
        if (!productIds.contains(doc.id)) {
          dynamic rawData = doc.data();
          if (rawData is Map<String, dynamic>) {
            num? stockNum = rawData['currentStock'] as num?;
            int stock = stockNum?.toInt() ?? 0;
            products.add(Product.fromFirestore(doc, stock));
            productIds.add(doc.id);
          } else {
            print("DEBUG ProductService (Name Search): Document data was not a Map for doc ID: ${doc.id}");
          }
        }
      }

      // If not enough results, search by SKU (limit 15 total products)
      if (products.length < 15) {
        QuerySnapshot skuSnapshot = await _firestore
            .collection('master_products')
            .where('sku', isEqualTo: searchQuery)
            .limit(5) // Limit additional results
            .get();
        print("DEBUG ProductService: SKU search returned ${skuSnapshot.docs.length} docs.");
        for (var doc in skuSnapshot.docs) {
          if (!productIds.contains(doc.id) && products.length < 15) {
            dynamic rawData = doc.data();
            if (rawData is Map<String, dynamic>) {
              num? stockNum = rawData['currentStock'] as num?;
              int stock = stockNum?.toInt() ?? 0;
              products.add(Product.fromFirestore(doc, stock));
              productIds.add(doc.id);
            } else {
              print("DEBUG ProductService (SKU Search): Document data was not a Map for doc ID: ${doc.id}");
            }
          }
        }
      }

      // If still not enough results, search by Barcode (limit 15 total products)
      if (products.length < 15) {
        QuerySnapshot barcodeSnapshot = await _firestore
            .collection('master_products')
            .where('barcode', isEqualTo: searchQuery)
            .limit(5) // Limit additional results
            .get();
        print("DEBUG ProductService: Barcode search returned ${barcodeSnapshot.docs.length} docs.");
        for (var doc in barcodeSnapshot.docs) {
          if (!productIds.contains(doc.id) && products.length < 15) {
            dynamic rawData = doc.data();
            if (rawData is Map<String, dynamic>) {
              num? stockNum = rawData['currentStock'] as num?;
              int stock = stockNum?.toInt() ?? 0;
              products.add(Product.fromFirestore(doc, stock));
              productIds.add(doc.id);
            } else {
              print("DEBUG ProductService (Barcode Search): Document data was not a Map for doc ID: ${doc.id}");
            }
          }
        }
      }

      print('DEBUG ProductService: Search results for "$query": ${products.length} products found.');
      return products;

    } catch (e) {
      print("Error in ProductService.searchProducts: $e");
      return []; // Return empty list on error
    }
  }

  Future<List<Product>> getInitialProducts({int limit = 20}) async {
    try {
      print("DEBUG ProductService: getInitialProducts called with limit: $limit");
      QuerySnapshot snapshot = await _firestore
          .collection('master_products') // Ensure this is your correct collection name
          .orderBy('productName') // Or any other field you prefer for ordering initial items
          .limit(limit)
          .get();

      List<Product> products = [];
      if (snapshot.docs.isEmpty) {
        print("DEBUG ProductService: No documents found in master_products for getInitialProducts.");
      }
      for (var doc in snapshot.docs) {
        dynamic rawData = doc.data();
        if (rawData is Map<String, dynamic>) {
          // Correctly read 'currentStock' as num? then convert to int
          num? stockNum = rawData['currentStock'] as num?;
          int stock = stockNum?.toInt() ?? 0;
          products.add(Product.fromFirestore(doc, stock));
        } else {
          print("DEBUG ProductService (InitialProducts): Document data was not a Map for doc ID: ${doc.id}");
        }
      }
      print("DEBUG ProductService: Returning ${products.length} products from getInitialProducts.");
      return products;
    } catch (e) {
      print("Error in ProductService.getInitialProducts: $e");
      return []; // Return empty list on error
    }
  }

  // Example: Add a new product (if you have such functionality)
  // This is just a placeholder and would need proper error handling and UI integration
  Future<String?> addProduct(Product product) async {
    try {
      // Note: Product.toFirestore() would need to be defined in your Product model
      // It should not include the 'id' field as Firestore generates that.
      // It should also correctly format fields like 'createdAt' to Timestamp.
      // For now, assuming a simple map. Ensure your Product model has a toMap() or toFirestore().
      Map<String, dynamic> productData = {
        'productName': product.productName,
        'price': product.price,
        'sku': product.sku,
        'barcode': product.barcode,
        'units': product.units,
        'category': product.category,
        'currentStock': product.currentStock, // Initial stock when adding
        'imageUrl': product.imageUrl,
        'isManuallyAddedSku': product.isManuallyAddedSku,
        'createdAt': FieldValue.serverTimestamp(), // Use server timestamp for creation
      };
      DocumentReference docRef = await _firestore.collection('master_products').add(productData);
      print("DEBUG ProductService: Product added with ID: ${docRef.id}");
      return docRef.id;
    } catch (e) {
      print("Error in ProductService.addProduct: $e");
      return null;
    }
  }
}
