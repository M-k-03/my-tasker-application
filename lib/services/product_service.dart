import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_tasker/models/product.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Product>> searchProducts(String query) async {
    if (query.isEmpty) {
      return [];
    }
    String searchQuery = query;
    List<Product> products = [];
    Set<String> productIds = {};

    try {
      QuerySnapshot nameSnapshot = await _firestore
          .collection('master_products')
          .where('productName', isGreaterThanOrEqualTo: searchQuery)
          .where('productName', isLessThanOrEqualTo: searchQuery + '\uf8ff')
          .limit(10)
          .get();

      for (var doc in nameSnapshot.docs) {
        if (!productIds.contains(doc.id)) {
          int stock = (doc.data() as Map<String, dynamic>?)?['currentStock'] as int? ?? 0;
          products.add(Product.fromFirestore(doc, stock));
          productIds.add(doc.id);
        }
      }

      if (products.length < 15) {
        QuerySnapshot skuSnapshot = await _firestore
            .collection('master_products')
            .where('sku', isEqualTo: searchQuery)
            .limit(5)
            .get();
        for (var doc in skuSnapshot.docs) {
          if (!productIds.contains(doc.id)) {
            int stock = (doc.data() as Map<String, dynamic>?)?['currentStock'] as int? ?? 0;
            products.add(Product.fromFirestore(doc, stock));
            productIds.add(doc.id);
          }
        }
      }

      if (products.length < 15) {
        QuerySnapshot barcodeSnapshot = await _firestore
            .collection('master_products')
            .where('barcode', isEqualTo: searchQuery)
            .limit(5)
            .get();
        for (var doc in barcodeSnapshot.docs) {
          if (!productIds.contains(doc.id)) {
            int stock = (doc.data() as Map<String, dynamic>?)?['currentStock'] as int? ?? 0;
            products.add(Product.fromFirestore(doc, stock));
            productIds.add(doc.id);
          }
        }
      }

      print('Search results for "$query": ${products.length} products found.');
      return products;

    } catch (e) {
      print("Error searching products: $e");
      return [];
    }
  }

  // This is the method that was missing
  Future<List<Product>> getInitialProducts({int limit = 20}) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('master_products')
          .orderBy('productName')
          .limit(limit)
          .get();

      List<Product> products = [];
      for (var doc in snapshot.docs) {
        // Assuming 'currentStock' is a field in your master_products documents
        int stock = (doc.data() as Map<String, dynamic>?)?['currentStock'] as int? ?? 0;
        products.add(Product.fromFirestore(doc, stock));
      }
      return products;
    } catch (e) {
      print("Error fetching initial products: $e");
      return []; // Return empty list on error
    }
  }
}
