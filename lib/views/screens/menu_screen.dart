import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added this line
import 'package:flutter_exit_app/flutter_exit_app.dart';
// import 'package:my_tasker/views/widgets/bulk_upload_form.dart'; // No longer in drawer
// import 'package:my_tasker/views/widgets/define_product_form.dart'; // No longer in drawer
import 'package:my_tasker/views/screens/login_screen.dart';
// import 'package:my_tasker/views/screens/purchase_entry_screen.dart'; // No longer in drawer
// import 'package:my_tasker/views/screens/purchase_history_screen.dart'; // No longer in drawer
import 'package:my_tasker/views/screens/sale_entry_screen.dart';
import 'package:my_tasker/utils/shared_preferences_services.dart'; // Assuming you have this for user details

// Placeholder imports for new screens - adjust paths if necessary
import 'package:my_tasker/views/screens/product_catalog_management_screen.dart';
import 'package:my_tasker/views/screens/stock_management_screen.dart';
import 'package:my_tasker/views/screens/analytics_screen.dart'; // For AnalyticsScreen type
import 'package:my_tasker/views/screens/settings_screen.dart';   // For SettingsScreen type

class _MenuItem {
  final String title;
  final String imagePath;
  final IconData iconData; // Fallback icon
  final Widget Function(String shopId) targetScreenBuilder;

  _MenuItem({
    required this.title,
    required this.imagePath,
    required this.iconData,
    required this.targetScreenBuilder,
  });
}

class MenuScreen extends StatefulWidget {
  final String shopId; // Added shopId

  const MenuScreen({super.key, required this.shopId}); // Modified constructor

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String? _userEmail;
  String? _shopkeeperName;
  bool _isLoadingEmail = true;
  bool _isLoadingShopkeeperName = true;
  final SharedPreferencesService _prefsService = SharedPreferencesService();
  late List<_MenuItem> _menuItemsList;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _loadShopkeeperName();

    _menuItemsList = [
      _MenuItem(
        title: 'Product Catalog',
        imagePath: 'assets/images/add_product_icon.png',
        iconData: Icons.auto_stories_outlined, // Fallback
        targetScreenBuilder: (shopId) => ProductCatalogManagementScreen(shopId: shopId),
      ),
      // _MenuItem(
      //   title: 'Analytics',
      //   imagePath: 'assets/images/analytics_icon.png',
      //   iconData: Icons.analytics_outlined, // Fallback
      //   targetScreenBuilder: (shopId) => AnalyticsScreen(shopId: shopId),
      // ),
      _MenuItem(
        title: 'Stock Management',
        imagePath: 'assets/images/stock_management_icon.png',
        iconData: Icons.inventory_2_outlined, // Fallback
        targetScreenBuilder: (shopId) => StockManagementScreen(shopId: shopId),
      ),
      _MenuItem(
        title: 'Sale Entry',
        imagePath: 'assets/images/sale-entry.png',
        iconData: Icons.point_of_sale_outlined, // Fallback
        targetScreenBuilder: (shopId) => SaleEntryScreen(shopId: shopId),
      ),
    ];
  }

  Future<void> _loadUserEmail() async {
    setState(() {
      _isLoadingEmail = true;
    });
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null && currentUser.email!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _userEmail = currentUser.email;
            _isLoadingEmail = false;
          });
        }
      } else {
        // Fallback to SharedPreferences if Firebase user or email is null/empty
        String? emailFromPrefs = await _prefsService.getUserEmail();
        if (mounted) {
          setState(() {
            _userEmail = emailFromPrefs;
            _isLoadingEmail = false;
          });
        }
      }
    } catch (e) {
      print("Error loading user email: $e");
      if (mounted) {
        setState(() {
          _userEmail = "Error loading email"; // Or null, to show 'Loading email...'
          _isLoadingEmail = false;
        });
      }
    }
  }

  Future<void> _loadShopkeeperName() async {
    setState(() {
      _isLoadingShopkeeperName = true;
    });
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot shopkeeperDoc = await FirebaseFirestore.instance
            .collection('shopkeepers')
            .doc(currentUser.uid)
            .get();

        if (mounted && shopkeeperDoc.exists) {
          setState(() {
            _shopkeeperName = shopkeeperDoc.get('name') as String?;
            _isLoadingShopkeeperName = false;
          });
        } else if (mounted) {
          setState(() {
            _isLoadingShopkeeperName = false; // Name not found or doc doesn't exist
          });
        }
      }
    } catch (e) {
      print("Error loading shopkeeper name: $e");
      if (mounted) setState(() => _isLoadingShopkeeperName = false);
    }
  }
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      await _prefsService.clearLoginDetails(); // Clear any stored credentials
      // Navigate to LoginScreen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Error during logout: $e");
      // Optionally show a toast or dialog if logout fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Logout failed: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        backgroundColor: Colors.orangeAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Exit App',
            onPressed: () {
              // Consider showing a confirmation dialog before exiting
              FlutterExitApp.exitApp(iosForceExit: true);
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(
                _isLoadingShopkeeperName
                    ? 'Loading name...'
                    : _shopkeeperName ?? 'User Name', // Fallback if name is null
              ),
              accountEmail: Text(
                    _isLoadingEmail 
                    ? 'Loading email...' 
                    : _userEmail ?? 'No email available', // Handle null email after loading
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: Colors.orangeAccent),
              ),
              decoration: const BoxDecoration(
                color: Colors.orangeAccent,
              ),
            ),
            // ListTile(
            //   leading: const Icon(Icons.settings_outlined),
            //   title: const Text('Settings'),
            //   onTap: () {
            //     Navigator.pop(context); // Close the drawer
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => SettingsScreen(shopId: widget.shopId),
            //       ),
            //     );
            //   },
            // ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _logout(context); // Call the logout method
              },
            ),
          ],
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // You can adjust this count
          crossAxisSpacing: 8.0, // Further reduced spacing
          mainAxisSpacing: 8.0,  // Further reduced spacing
          childAspectRatio: 1.4, // Make tiles even wider than they are tall
        ),
        itemCount: _menuItemsList.length,
        itemBuilder: (context, index) {
          final menuItem = _menuItemsList[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => menuItem.targetScreenBuilder(widget.shopId),
                ),
              );
            },
            child: Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    menuItem.imagePath,
                    height: 36, // Reverted to a larger size
                    width: 36,  // Reverted to a larger size
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to Icon if image fails to load
                      print("Error loading image ${menuItem.imagePath}: $error");
                      return Icon(menuItem.iconData, size: 30, color: Colors.orangeAccent); // Reverted fallback icon size
                    },
                  ),
                  const SizedBox(height: 6), // Reverted spacing
                  Text(
                    menuItem.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12, // Reverted font size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
