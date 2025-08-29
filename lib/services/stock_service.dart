import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_tasker/models/purchase_entry_item.dart'; // Adjusted import based on user confirmation
import 'package:my_tasker/models/sale_entry.dart';
import 'package:my_tasker/models/stock_summary_item.dart'; // CHANGED: Import StockSummaryItem

class StockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateStockOnPurchase(PurchaseEntryItem purchase) async { // Changed type to PurchaseEntryItem
    if (purchase.productId.isEmpty || purchase.shopId.isEmpty) {
      print('StockService_DEBUG: Purchase productId or shopId is empty. ProductId: ${purchase.productId}, ShopId: ${purchase.shopId}');
      print('Error: Product ID or Shop ID is empty in the purchase entry. Skipping stock update.');
      // Optionally, throw an exception or handle this more gracefully
      return;
    }

    final stockSummaryDocId = '${purchase.shopId}_${purchase.productId}';
    final stockSummaryRef = _firestore.collection('stock_summary').doc(stockSummaryDocId);

    print('StockService_DEBUG: Starting transaction for stock update. PurchaseId (derived): ${purchase.id}, ProductId: ${purchase.productId}, ShopId: ${purchase.shopId}');

    return _firestore.runTransaction((transaction) async {
      // Get product master data
      final productMasterRef = _firestore.collection('master_products').doc(purchase.productId);
      print('StockService_DEBUG: Attempting to fetch master_products document: ${productMasterRef.path}');
      final productMasterSnapshot = await transaction.get(productMasterRef);

      if (!productMasterSnapshot.exists) {
        print('StockService_DEBUG: ERROR - Product master not found for productId: ${purchase.productId} at path ${productMasterRef.path}');
        // If the product doesn't exist in master_products, we cannot reliably get its selling price/units.
        // This is a critical issue that should ideally be prevented upstream.
        throw Exception('Product with ID ${purchase.productId} not found in master_products. Cannot update stock summary.');
      }
      final productMasterData = productMasterSnapshot.data() as Map<String, dynamic>;
      print('StockService_DEBUG: Product master data fetched for ${purchase.productId}: $productMasterData');
      final String masterProductName = productMasterData['productName'] ?? purchase.productName; // Fallback to purchase name
      final String? masterSku = productMasterData['sku'] as String? ?? purchase.sku; // Fallback to purchase sku
      final double masterSellingPrice = (productMasterData['price'] as num?)?.toDouble() ?? 0.0; // CHANGED: Use 'price' field
      print('StockService_DEBUG: Read master_products field "price": ${productMasterData['price']}, Type: ${productMasterData['price']?.runtimeType}, Resolved masterSellingPrice: $masterSellingPrice');
      final String? masterUnits = productMasterData['units'] as String? ?? purchase.unit; // Fallback to purchase unit

      final stockSnapshot = await transaction.get(stockSummaryRef);

      if (stockSnapshot.exists) {
        final currentSummary = StockSummaryItem.fromFirestore(stockSnapshot); // CHANGED: Use StockSummaryItem

        print('StockService_DEBUG: Stock summary exists for ${stockSummaryDocId}. Current stock: ${currentSummary.currentStock}, Current price: ${currentSummary.price}');
        // Prepare data for update, using master product data
        Map<String, dynamic> dataToUpdate = {
          'currentStock': currentSummary.currentStock + purchase.quantityPurchased,
          'lastUpdated': FieldValue.serverTimestamp(),
          'productName': masterProductName,
          'productName_lowercase': masterProductName.toLowerCase(),
          'sku': masterSku,
          'price': masterSellingPrice, // Update with standard selling price from master
          'units': masterUnits,      // Update with standard units from master
        };
        transaction.update(stockSummaryRef, {
          ...dataToUpdate
        });
        print('StockService_DEBUG: Updated existing stock summary for ${stockSummaryDocId} with new price: $masterSellingPrice');
      } else {
        // Document does not exist, create it using StockSummaryItem and master product data
        final newSummary = StockSummaryItem(
          id: stockSummaryDocId,
          shopId: purchase.shopId,
          productId: purchase.productId,
          productName: masterProductName,
          productName_lowercase: masterProductName.toLowerCase(),
          sku: masterSku,
          currentStock: purchase.quantityPurchased, // CHANGED: Directly set currentStock
          units: masterUnits,
          price: masterSellingPrice,
          lastUpdated: Timestamp.now(), // Firestore will use serverTimestamp on write via FieldValue
        );
        Map<String, dynamic> dataToSet = newSummary.toMap(); // CHANGED: Use toMap()
        print('StockService_DEBUG: Creating new stock summary for ${stockSummaryDocId}. Data before server timestamp: $dataToSet');
        dataToSet['lastUpdated'] = FieldValue.serverTimestamp();
        transaction.set(stockSummaryRef, dataToSet);
        print('StockService_DEBUG: Set new stock summary for ${stockSummaryDocId} with price: $masterSellingPrice');
      }
    }).catchError((error, stackTrace) { // Added stackTrace for better debugging
      print('StockService_DEBUG: ERROR in transaction for stock summary on purchase: $error. StackTrace: $stackTrace');
      // Rethrow or handle as per your app's error handling strategy
      throw error;
    });
  }

  Future<void> updateStockOnSale(SaleEntry sale) async {
    if (sale.productId.isEmpty || sale.shopId.isEmpty) {
      print('StockService_DEBUG: Sale productId or shopId is empty. ProductId: ${sale.productId}, ShopId: ${sale.shopId}');
      print('Error: Product ID or Shop ID is empty in the sale entry. Skipping stock update.'); // Weak warning
      return;
    }

    final stockSummaryDocId = '${sale.shopId}_${sale.productId}';
    final stockSummaryRef = _firestore.collection('stock_summary').doc(stockSummaryDocId);

    print('StockService_DEBUG: Starting transaction for stock update ON SALE. SaleId: ${sale.id}, ProductId: ${sale.productId}, ShopId: ${sale.shopId}');

    return _firestore.runTransaction((transaction) async {
      final stockSnapshot = await transaction.get(stockSummaryRef);

      if (stockSnapshot.exists) {
        // Document exists, update it
        final currentSummary = StockSummaryItem.fromFirestore(stockSnapshot); // CHANGED: Use StockSummaryItem
        print('StockService_DEBUG: Stock summary exists for ${stockSummaryDocId} during SALE. Current stock: ${currentSummary.currentStock}');

        transaction.update(stockSummaryRef, {
          'currentStock': currentSummary.currentStock - sale.quantitySold, // CHANGED: Adjust currentStock
          'lastUpdated': FieldValue.serverTimestamp(),
          // Product master data like name, sku, price, units are generally NOT updated during a sale.
        });
      } else {
        print('StockService_DEBUG: WARNING - StockSummaryItem document not found for ${stockSummaryDocId} during SALE. Creating new summary from master_products.');
        // StockSummaryItem document does not exist - this is unusual for a sale.
        // Create it, sourcing master data from master_products.
        print('Warning: StockSummaryItem document not found for shopId: ${sale.shopId}, productId: ${sale.productId} during sale. Creating new summary from master_products.');

        final productMasterRef = _firestore.collection('master_products').doc(sale.productId);
        print('StockService_DEBUG: Attempting to fetch master_products document for SALE: ${productMasterRef.path}');
        final productMasterSnapshot = await transaction.get(productMasterRef);

        if (!productMasterSnapshot.exists) {
          print('StockService_DEBUG: ERROR - Product master not found for productId during SALE: ${sale.productId} at path ${productMasterRef.path}');
          throw Exception('Product with ID ${sale.productId} not found in master_products. Cannot create stock summary for sale.');
        }
        final productMasterData = productMasterSnapshot.data() as Map<String, dynamic>;
        print('StockService_DEBUG: Product master data fetched for SALE ${sale.productId}: $productMasterData');
        final String masterProductName = productMasterData['productName'] ?? sale.productName; // Fallback to sale name
        final String? masterSku = productMasterData['sku'] as String? ?? sale.sku; // Fallback to sale sku
        final double masterSellingPrice = (productMasterData['price'] as num?)?.toDouble() ?? sale.pricePerUnitAtSale; // CHANGED: Use 'price' field
        print('StockService_DEBUG: Read master_products field "price" for SALE: ${productMasterData['price']}, Type: ${productMasterData['price']?.runtimeType}, Resolved masterSellingPrice for SALE: $masterSellingPrice');
        final String? masterUnits = productMasterData['units'] as String?;

        final newSummary = StockSummaryItem(
          id: stockSummaryDocId,
          shopId: sale.shopId,
          productId: sale.productId,
          productName: masterProductName,
          productName_lowercase: masterProductName.toLowerCase(),
          sku: masterSku,
          currentStock: -sale.quantitySold, // Initial stock is negative as it's a sale without prior record
          units: masterUnits,
          price: masterSellingPrice, // Use standard selling price from master
          lastUpdated: Timestamp.now(), // Placeholder, Firestore will use serverTimestamp
        );
        Map<String, dynamic> dataToSet = newSummary.toMap(); // CHANGED: Use toMap()
        print('StockService_DEBUG: Creating new stock summary for ${stockSummaryDocId} during SALE. Data before server timestamp: $dataToSet');
        dataToSet['lastUpdated'] = FieldValue.serverTimestamp();
        transaction.set(stockSummaryRef, dataToSet);
        print('StockService_DEBUG: Set new stock summary for ${stockSummaryDocId} during SALE with price: $masterSellingPrice');
      }
    }).catchError((error, stackTrace) { // Added stackTrace for better debugging
      print('StockService_DEBUG: ERROR in transaction for stock summary on SALE: $error. StackTrace: $stackTrace');
      throw error;
    });
  }
}
