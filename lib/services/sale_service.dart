import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_tasker/models/sale_entry.dart';
import 'package:my_tasker/models/cart_item.dart';
import 'package:my_tasker/services/stock_service.dart'; // Added: Import StockService

class SaleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StockService _stockService = StockService(); // Added: Instantiate StockService

  // Constructor
  SaleService();

  // Updated to use SaleEntry and List<CartItem>, and to accept shopId and userId
  Future<void> recordSaleAndUpdateStock(List<CartItem> cartItems, String shopId, String userId) async { // Changed signature
    WriteBatch batch = _firestore.batch();
    Timestamp saleTimestamp = Timestamp.now(); // Use the same timestamp for all entries in this sale
    List<SaleEntry> savedSaleEntries = []; // Added: To store entries for stock update

    // 1. For each cartItem, create a SaleEntry document in 'sale_entries'.
    for (var item in cartItems) {
      DocumentReference saleDocRef = _firestore.collection('sale_entries').doc();
      
      // Create a SaleEntry object. The 'id' will be from saleDocRef.id
      SaleEntry entryForSave = SaleEntry(
        id: saleDocRef.id, // Capture the auto-generated ID
        productId: item.productId,
        productName: item.productName,
        sku: item.sku, // Assuming CartItem has sku
        quantitySold: item.quantity,
        pricePerUnitAtSale: item.price, // Assuming CartItem has price
        totalAmountForProduct: item.price * item.quantity,
        createdAt: saleTimestamp, // Consistent timestamp, field renamed in SaleEntry
        shopId: shopId,             // Added
        userId: userId,             // Added
      );

      batch.set(saleDocRef, entryForSave.toMap()); 
      savedSaleEntries.add(entryForSave); // Add to list for subsequent stock update
      print('DEBUG SaleService: Adding SaleEntry for ${item.productName} (Qty: ${item.quantity}) to batch for shop $shopId, user $userId.');
    }

    // 2. Commit the batch to save sale entries
    try {
      await batch.commit();
      print('Sale entries recorded successfully for shop $shopId.');
    } catch (e) {
      print('Error during sale entries batch commit for shop $shopId: ${e.toString()}');
      throw Exception('Failed to record sale entries for shop $shopId: ${e.toString()}');
    }

    // 3. Update stock for each saved sale entry using StockService
    // This is done after sale entries are confirmed to be saved.
    int successfulStockUpdates = 0;
    for (SaleEntry entry in savedSaleEntries) {
      try {
        await _stockService.updateStockOnSale(entry);
        print('DEBUG SaleService: Stock update requested for ${entry.productName} (Qty: ${entry.quantitySold}) via StockService.');
        successfulStockUpdates++;
      } catch (e) {
        // Log error for individual stock update failure but continue with others
        print('ERROR SaleService: Failed to update stock for ${entry.productName} (ID: ${entry.productId}, SaleEntryID: ${entry.id}) via StockService: ${e.toString()}');
        // Depending on requirements, you might want to collect these errors and report them.
      }
    }

    print('Sale process completed for shop $shopId. $successfulStockUpdates/${savedSaleEntries.length} stock updates processed successfully via StockService.');
  }

  // You might add other methods here, e.g.,
  // Future<List<SaleEntry>> fetchSalesHistory({required String shopId}) async { ... }
  // Future<SaleEntry?> getSaleEntryDetails(String saleEntryId, {required String shopId}) async { ... }
}
