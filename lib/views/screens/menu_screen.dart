import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for Firebase Auth
import 'package:my_tasker/views/screens/login_screen.dart'; // Added for navigation to Login
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:my_tasker/views/screens/analytics_screen.dart';
import 'package:my_tasker/views/screens/stock_management_screen.dart';
import 'package:my_tasker/views/screens/settings_screen.dart';
import 'package:my_tasker/views/screens/product_catalog_management_screen.dart';
import 'package:my_tasker/views/screens/sale_entry_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  static final List<_MenuItem> _menuItems = [
    _MenuItem(
      title: 'Product Catalog',
      imagePath: 'assets/images/add_product_icon.png',
      targetScreen: const ProductCatalogManagementScreen(),
    ),
    _MenuItem(
      title: 'Analytics',
      imagePath: 'assets/images/analytics_icon.png',
      targetScreen: const AnalyticsScreen(),
    ),
    _MenuItem(
      title: 'Stock Management',
      imagePath: 'assets/images/stock_management_icon.png',
      targetScreen: const StockManagementScreen(),
    ),
    _MenuItem(
      title: 'Sale Entry',
      imagePath: 'assets/images/sale-entry.png',
      targetScreen: const SaleEntryScreen(),
    ),
    _MenuItem(
      title: 'Settings',
      imagePath: 'assets/images/settings_icon.png',
      targetScreen: const SettingsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? 'No email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Menu'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // automaticallyImplyLeading is false, so we manually add a leading button for the drawer
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Open menu',
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Exit App',
            onPressed: () {
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
              accountName: null, // You can add user's name here if available
              accountEmail: Text(currentUserEmail),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person, size: 50),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false, // Remove all previous routes
                );
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/menu-bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0, left: 8.0, right: 8.0, bottom: 8.0),
          child: GridView.builder(
            itemCount: _menuItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (BuildContext context, int index) {
              final menuItem = _menuItems[index];
              return Card(
                elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                child: InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => menuItem.targetScreen));
                  },
                  borderRadius: BorderRadius.circular(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            menuItem.imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            menuItem.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Helper class for menu item data
class _MenuItem {
  final String title;
  final String imagePath;
  final Widget targetScreen;

  const _MenuItem({
    required this.title,
    required this.imagePath,
    required this.targetScreen,
  });
}
