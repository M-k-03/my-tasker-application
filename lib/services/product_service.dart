import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_tasker/models/product.dart'; // Ensure this path is correct

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper method to fetch live stock, now requires shopId
  Future<int> _fetchLiveStockForProduct(String productId, {required String shopId}) async {
    try {
      int totalPurchased = 0;
      QuerySnapshot purchaseSnapshot = await _firestore
          .collection('purchase_entries')
          .where('productId', isEqualTo: productId)
          .where('shopId', isEqualTo: shopId) // Filter by shopId
          .get();
      for (var doc in purchaseSnapshot.docs) {
        num? purchasedQty = (doc.data() as Map<String, dynamic>)['quantity'] as num?;
        totalPurchased += purchasedQty?.toInt() ?? 0;
      }

      int totalSold = 0;
      QuerySnapshot saleSnapshot = await _firestore
          .collection('sale_entries')
          .where('productId', isEqualTo: productId)
          .where('shopId', isEqualTo: shopId) // Filter by shopId
          .get();
      for (var doc in saleSnapshot.docs) {
        num? soldQty = (doc.data() as Map<String, dynamic>)['quantitySold'] as num?;
        totalSold += soldQty?.toInt() ?? 0;
      }
      int stock = totalPurchased - totalSold;
      print("DEBUG ProductService (_fetchLiveStockForProduct $productId, Shop: $shopId): Purchased: $totalPurchased, Sold: $totalSold, CalculatedStock: $stock");
      return stock < 0 ? 0 : stock; // Cap at 0
    } catch (e) {
      print("Error in _fetchLiveStockForProduct for $productId, Shop: $shopId: $e");
      return 0; // Return default on error
    }
  }

  Future<Product?> getProductDetailsById(String productId, {required String shopId}) async {
    try {
      // Query by document ID and shopId
      QuerySnapshot productSnapshot = await _firestore
          .collection('master_products')
          .where(FieldPath.documentId, isEqualTo: productId)
          .where('shopId', isEqualTo: shopId) // Filter by shopId
          .limit(1)
          .get();

      if (productSnapshot.docs.isNotEmpty) {
        DocumentSnapshot productDoc = productSnapshot.docs.first;
        int stock = await _fetchLiveStockForProduct(productId, shopId: shopId);
        return Product.fromFirestore(productDoc, stock);
      } else {
        print("DEBUG ProductService (getProductDetailsById): Product $productId not found in shop $shopId.");
        return null;
      }
    } catch (e) {
      print("Error in ProductService.getProductDetailsById for $productId, Shop: $shopId: $e");
      return null;
    }
  }

  Future<List<Product>> searchProducts(String queryLowercase, {required String shopId}) async {
    if (queryLowercase.isEmpty) {
      return [];
    }
    List<Product> products = [];
    Set<String> productIds = {};

    try {
      print("DEBUG ProductService: searchProducts called with query (lowercase): '$queryLowercase' for shop: $shopId");

      // Search by Product Name (filtered by shopId)
      QuerySnapshot nameSnapshot = await _firestore
          .collection('master_products')
          .where('shopId', isEqualTo: shopId) // Filter by shopId
          .where('productName_lowercase', isGreaterThanOrEqualTo: queryLowercase)
          .where('productName_lowercase', isLessThanOrEqualTo: queryLowercase + '\uf8ff')
          .limit(10)
          .get();

      print("DEBUG ProductService: Name search (shop $shopId) returned ${nameSnapshot.docs.length} docs.");
      for (var doc in nameSnapshot.docs) {
        if (!productIds.contains(doc.id)) {
          int stock = await _fetchLiveStockForProduct(doc.id, shopId: shopId);
          products.add(Product.fromFirestore(doc, stock));
          productIds.add(doc.id);
        }
      }

      // SKU search (filtered by shopId)
      if (products.length < 15) {
        QuerySnapshot skuSnapshot = await _firestore
            .collection('master_products')
            .where('shopId', isEqualTo: shopId) // Filter by shopId
            .where('sku', isEqualTo: queryLowercase)
            .limit(5)
            .get();
        print("DEBUG ProductService: SKU search (shop $shopId) returned ${skuSnapshot.docs.length} docs for query: $queryLowercase");
        for (var doc in skuSnapshot.docs) {
          if (!productIds.contains(doc.id) && products.length < 15) {
            int stock = await _fetchLiveStockForProduct(doc.id, shopId: shopId);
            products.add(Product.fromFirestore(doc, stock));
            productIds.add(doc.id);
          }
        }
      }

      // Barcode search (filtered by shopId)
      if (products.length < 15) {
        QuerySnapshot barcodeSnapshot = await _firestore
            .collection('master_products')
            .where('shopId', isEqualTo: shopId) // Filter by shopId
            .where('barcode', isEqualTo: queryLowercase)
            .limit(5)
            .get();
        print("DEBUG ProductService: Barcode search (shop $shopId) returned ${barcodeSnapshot.docs.length} docs for query: $queryLowercase");
        for (var doc in barcodeSnapshot.docs) {
          if (!productIds.contains(doc.id) && products.length < 15) {
            int stock = await _fetchLiveStockForProduct(doc.id, shopId: shopId);
            products.add(Product.fromFirestore(doc, stock));
            productIds.add(doc.id);
          }
        }
      }
      
      print('DEBUG ProductService: Search results for shop $shopId: ${products.length} products found.');
      return products;

    } catch (e) {
      print("Error in ProductService.searchProducts for shop $shopId: $e");
      return [];
    }
  }

  Future<List<Product>> getInitialProducts({int limit = 20, required String shopId}) async {
    try {
      print("DEBUG ProductService: getInitialProducts called with limit: $limit for shop: $shopId");
      QuerySnapshot snapshot = await _firestore
          .collection('master_products')
          .where('shopId', isEqualTo: shopId) // Filter by shopId
          .orderBy('productName')
          .limit(limit)
          .get();

      List<Product> products = [];
      if (snapshot.docs.isEmpty) {
        print("DEBUG ProductService: No documents found for getInitialProducts in shop $shopId.");
      }
      for (var doc in snapshot.docs) {
        int stock = await _fetchLiveStockForProduct(doc.id, shopId: shopId);
        products.add(Product.fromFirestore(doc, stock));
      }
      print("DEBUG ProductService: Returning ${products.length} products from getInitialProducts for shop $shopId.");
      return products;
    } catch (e) {
      print("Error in ProductService.getInitialProducts for shop $shopId: $e");
      return [];
    }
  }

  Future<String?> addProduct(Product product, String productNameLowercase, {required String shopId, required String userId}) async {
    try {
      Map<String, dynamic> productData = {
        'productName': product.productName,
        'productName_lowercase': productNameLowercase,
        'price': product.price,
        'sku': product.sku,
        'barcode': product.barcode,
        'units': product.units,
        'category': product.category,
        'imageUrl': product.imageUrl,
        'isManuallyAddedSku': product.isManuallyAddedSku,
        'createdAt': FieldValue.serverTimestamp(),
        'shopId': shopId, // Add shopId
        'userId': userId, // Add userId
      };

      DocumentReference docRef = await _firestore.collection('master_products').add(productData);
      print("DEBUG ProductService: Product added with ID: ${docRef.id} to shop $shopId by user $userId");
      return docRef.id;
    } catch (e) {
      print("Error in ProductService.addProduct for shop $shopId: $e");
      return null;
    }
  }

  Future<List<Product>> getFrequentlyPurchasedProducts({int limit = 10, required String shopId}) async {
    print("DEBUG ProductService: getFrequentlyPurchasedProducts called with limit: $limit for shop: $shopId");
    // This is a placeholder. Actual frequent purchase logic would be more complex,
    // possibly involving analysis of 'sale_entries' for the given shopId.
    // For now, it mirrors getInitialProducts logic for demonstration.
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('master_products')
          .where('shopId', isEqualTo: shopId) // Filter by shopId
          .orderBy('productName') 
          .limit(limit)
          .get();

      List<Product> products = [];
      for (var doc in snapshot.docs) {
        int stock = await _fetchLiveStockForProduct(doc.id, shopId: shopId);
        products.add(Product.fromFirestore(doc, stock));
      }
      return products;
    } catch (e) {
      print("Error in ProductService.getFrequentlyPurchasedProducts for shop $shopId: $e");
      return [];
    }
  }
}
