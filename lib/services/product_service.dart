import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_tasker/models/product.dart'; // Ensure this path is correct

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper method to fetch live stock, similar to ViewStockScreen
  Future<int> _fetchLiveStockForProduct(String productId) async {
    try {
      // DocumentSnapshot productDoc = await _firestore.collection('master_products').doc(productId).get();
      // if (!productDoc.exists) {
      //   print("DEBUG ProductService (_fetchLiveStockForProduct): Product $productId not found.");
      //   return 0; // Or throw error
      // }
      // No need to fetch productDoc again if we only need to calculate stock from entries

      int totalPurchased = 0;
      QuerySnapshot purchaseSnapshot = await _firestore
          .collection('purchase_entries')
          .where('productId', isEqualTo: productId)
          .get();
      for (var doc in purchaseSnapshot.docs) {
        num? purchasedQty = (doc.data() as Map<String, dynamic>)['quantity'] as num?;
        totalPurchased += purchasedQty?.toInt() ?? 0;
      }

      int totalSold = 0;
      QuerySnapshot saleSnapshot = await _firestore
          .collection('sale_entries')
          .where('productId', isEqualTo: productId)
          .get();
      for (var doc in saleSnapshot.docs) {
        num? soldQty = (doc.data() as Map<String, dynamic>)['quantitySold'] as num?;
        totalSold += soldQty?.toInt() ?? 0;
      }
      int stock = totalPurchased - totalSold;
      print("DEBUG ProductService (_fetchLiveStockForProduct $productId): Purchased: $totalPurchased, Sold: $totalSold, CalculatedStock: $stock");
      return stock < 0 ? 0 : stock; // Cap at 0
    } catch (e) {
      print("Error in _fetchLiveStockForProduct for $productId: $e");
      return 0; // Return default on error
    }
  }

  Future<Product?> getProductDetailsById(String productId) async {
    try {
      DocumentSnapshot productDoc = await _firestore.collection('master_products').doc(productId).get();
      if (productDoc.exists) {
        int stock = await _fetchLiveStockForProduct(productId);
        return Product.fromFirestore(productDoc, stock);
      } else {
        print("DEBUG ProductService (getProductDetailsById): Product $productId not found.");
        return null;
      }
    } catch (e) {
      print("Error in ProductService.getProductDetailsById for $productId: $e");
      return null;
    }
  }

  Future<List<Product>> searchProducts(String queryLowercase) async {
    if (queryLowercase.isEmpty) {
      return [];
    }
    List<Product> products = [];
    Set<String> productIds = {}; // To avoid duplicate products in search results

    try {
      print("DEBUG ProductService: searchProducts called with query (lowercase): '$queryLowercase'");

      // Search by Product Name (case-insensitive using a dedicated lowercase field)
      QuerySnapshot nameSnapshot = await _firestore
          .collection('master_products')
          .where('productName_lowercase', isGreaterThanOrEqualTo: queryLowercase) 
          .where('productName_lowercase', isLessThanOrEqualTo: queryLowercase + '\uf8ff')
          .limit(10)
          .get();

      print("DEBUG ProductService: Name search (lowercase) returned ${nameSnapshot.docs.length} docs.");
      for (var doc in nameSnapshot.docs) {
        if (!productIds.contains(doc.id)) {
          int stock = await _fetchLiveStockForProduct(doc.id);
          products.add(Product.fromFirestore(doc, stock));
          productIds.add(doc.id);
        }
      }

      // SKU search (uses lowercase query)
      if (products.length < 15) {
        // This assumes SKUs are either stored as lowercase or you have a 'sku_lowercase' field to query against.
        // If SKUs are stored in mixed/specific case, this query might not find them with a lowercase input.
        QuerySnapshot skuSnapshot = await _firestore
            .collection('master_products')
            .where('sku', isEqualTo: queryLowercase) // Querying 'sku' field with lowercase input
            .limit(5) 
            .get();
        print("DEBUG ProductService: SKU search returned ${skuSnapshot.docs.length} docs for query: $queryLowercase");
        for (var doc in skuSnapshot.docs) {
          if (!productIds.contains(doc.id) && products.length < 15) {
            int stock = await _fetchLiveStockForProduct(doc.id);
            products.add(Product.fromFirestore(doc, stock));
            productIds.add(doc.id);
          }
        }
      }

      // Barcode search (uses lowercase query)
      if (products.length < 15) {
        // Similar to SKU, this assumes barcodes are lowercase or you have a 'barcode_lowercase' field.
        QuerySnapshot barcodeSnapshot = await _firestore
            .collection('master_products')
            .where('barcode', isEqualTo: queryLowercase) // Querying 'barcode' field with lowercase input
            .limit(5)
            .get();
        print("DEBUG ProductService: Barcode search returned ${barcodeSnapshot.docs.length} docs for query: $queryLowercase");
        for (var doc in barcodeSnapshot.docs) {
          if (!productIds.contains(doc.id) && products.length < 15) {
            int stock = await _fetchLiveStockForProduct(doc.id);
            products.add(Product.fromFirestore(doc, stock));
            productIds.add(doc.id);
          }
        }
      }
      
      print('DEBUG ProductService: Search results for original query (now lowercase processed): ${products.length} products found.');
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
          .collection('master_products')
          .orderBy('productName')
          .limit(limit)
          .get();

      List<Product> products = [];
      if (snapshot.docs.isEmpty) {
        print("DEBUG ProductService: No documents found for getInitialProducts.");
      }
      for (var doc in snapshot.docs) {
        int stock = await _fetchLiveStockForProduct(doc.id);
        products.add(Product.fromFirestore(doc, stock));
      }
      print("DEBUG ProductService: Returning ${products.length} products from getInitialProducts.");
      return products;
    } catch (e) {
      print("Error in ProductService.getInitialProducts: $e");
      return [];
    }
  }

  Future<String?> addProduct(Product product, String productNameLowercase) async {
    try {
      Map<String, dynamic> productData = {
        'productName': product.productName,
        'productName_lowercase': productNameLowercase, // Store lowercase version for name searching
        'price': product.price,
        'sku': product.sku,
        // If you want case-insensitive search for SKU/Barcode, add lowercase versions here too:
        // 'sku_lowercase': product.sku?.toLowerCase(),
        // 'barcode_lowercase': product.barcode?.toLowerCase(),
        'barcode': product.barcode,
        'units': product.units,
        'category': product.category,
        'imageUrl': product.imageUrl,
        'isManuallyAddedSku': product.isManuallyAddedSku,
        'createdAt': FieldValue.serverTimestamp(),
        // currentStock is not stored here as it is dynamic
      };

      DocumentReference docRef = await _firestore.collection('master_products').add(productData);
      print("DEBUG ProductService: Product added with ID: ${docRef.id}");
      return docRef.id;
    } catch (e) {
      print("Error in ProductService.addProduct: $e");
      return null;
    }
  }

  // Added placeholder for getFrequentlyPurchasedProducts
  Future<List<Product>> getFrequentlyPurchasedProducts({int limit = 10}) async {
    // Placeholder implementation: returns the first few products.
    // Replace with actual logic to determine frequently purchased items.
    print("DEBUG ProductService: getFrequentlyPurchasedProducts called with limit: $limit");
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('master_products')
          .orderBy('productName') // Or some metric of frequency if available
          .limit(limit)
          .get();

      List<Product> products = [];
      for (var doc in snapshot.docs) {
        int stock = await _fetchLiveStockForProduct(doc.id);
        products.add(Product.fromFirestore(doc, stock));
      }
      return products;
    } catch (e) {
      print("Error in ProductService.getFrequentlyPurchasedProducts: $e");
      return [];
    }
  }
}
