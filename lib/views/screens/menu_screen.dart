import 'package:flutter/material.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart'; // Added for exit functionality
import 'package:my_tasker/views/screens/analytics_screen.dart';
import 'package:my_tasker/views/screens/stock_management_screen.dart';
import 'package:my_tasker/views/screens/settings_screen.dart';
import 'package:my_tasker/views/screens/product_catalog_management_screen.dart'; // IMPORT ADDED

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  // Helper class to structure menu item data
  static final List<_MenuItem> _menuItems = [ 
    _MenuItem(
      title: 'Product Catalog', 
      imagePath: 'assets/images/add_product_icon.png', 
      targetScreen: const ProductCatalogManagementScreen(), // UPDATED to new screen
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
      title: 'Settings',
      imagePath: 'assets/images/settings_icon.png', 
      targetScreen: const SettingsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Menu'),
        centerTitle: true, 
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
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
                    // Simplified navigation
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
    required this.targetScreen, // CORRECTED LINE
  });
}
