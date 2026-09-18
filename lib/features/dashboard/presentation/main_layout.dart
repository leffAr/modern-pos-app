import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../products/presentation/products_screen.dart';
import '../../pos/presentation/pos_screen.dart';
import '../../purchases/presentation/purchase_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../settings/presentation/printer_settings_screen.dart';
import '../../settings/presentation/store_settings_screen.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../promos/presentation/promos_screen.dart';
import '../../auth/presentation/login_screen.dart';
import '../../shifts/presentation/shifts_screen.dart';
import '../../users/presentation/users_screen.dart';
import '../../expenses/presentation/expense_screen.dart';
import '../../inventory/presentation/stock_opname_screen.dart';

class MainLayout extends StatefulWidget {
  final String userRole; // "Admin" or "Kasir"
  final String userName; // Nama pengguna yang login
  final String userId;
  const MainLayout({super.key, this.userRole = 'Admin', this.userName = 'Admin Utama', this.userId = 'USR-DEFAULT-ADMIN'});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  List<Widget> get _screens {
    final screens = <Widget>[];
    if (widget.userRole == 'Admin') {
      screens.add(DashboardScreen(userRole: widget.userRole, userName: widget.userName));
    }
    if (widget.userRole == 'Kasir') {
      screens.add(POSScreen(cashierName: widget.userName));
    }
    if (widget.userRole == 'Admin') {
      screens.add(const ProductsScreen());
      screens.add(const StockOpnameScreen());
      screens.add(const CategoriesScreen());
      screens.add(const PromosScreen());
      screens.add(const PurchaseScreen());
      screens.add(ExpenseScreen(userName: widget.userName));
      screens.add(const ReportsScreen());
    }
    screens.add(ShiftsScreen(userRole: widget.userRole, userName: widget.userName));
    screens.add(CustomersScreen(userRole: widget.userRole));
    if (widget.userRole == 'Admin') {
      screens.add(const UsersScreen());
      screens.add(const StoreSettingsScreen());
    }
    screens.add(const PrinterSettingsScreen());
    return screens;
  }

  late final List<NavigationRailDestination> _navDestinations;

  @override
  void initState() {
    super.initState();
    
    _navDestinations = [];

    // 1. Dashboard (Bisa diakses Admin saja)
    if (widget.userRole == 'Admin') {
      _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')));
    }

    // 2. POS / Kasir (HANYA KASIR)
    if (widget.userRole == 'Kasir') {
      _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: Text('POS / Kasir')));
    }

    // 3. Menu khusus Admin (Produk, Kategori, Diskon/Promo, Pembelian, Laporan)
    if (widget.userRole == 'Admin') {
      _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text("Produk")));
      _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: Text("Stok Opname")));
      _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: Text('Kategori')));
      _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.local_offer_outlined), selectedIcon: Icon(Icons.local_offer), label: Text('Diskon / Promo')));
      _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: Text('Pembelian')));
      _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.money_off_outlined), selectedIcon: Icon(Icons.money_off), label: Text('Pengeluaran')));
      _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('Laporan')));
    }
    
    // Shift (Bisa diakses Admin dan Kasir)
    _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.access_time_outlined), selectedIcon: Icon(Icons.access_time), label: Text('Shift')));

    // 4. Pelanggan (Bisa diakses Admin dan Kasir)
    _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Pelanggan')));

    // 5. Pengaturan Khusus Admin (Kelola Kasir, Profil Toko)
    if (widget.userRole == 'Admin') {
      _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge), label: Text('Kelola Pengguna')));
      _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: Text('Profil Toko')));
    }

    // 6. Printer (Bisa diakses Admin dan Kasir)
    _navDestinations.add(const NavigationRailDestination(icon: Icon(Icons.print_outlined), selectedIcon: Icon(Icons.print), label: Text('Printer')));
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Adaptive layout: BottomNav for mobile, NavRail for tablet/desktop
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      drawer: isMobile
          ? Drawer(
              child: Column(
                children: [
                  UserAccountsDrawerHeader(
                    accountName: Text(widget.userName),
                    accountEmail: Text(widget.userRole),
                    currentAccountPicture: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Colors.blue, size: 40),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _navDestinations.length,
                      itemBuilder: (context, index) {
                        final dest = _navDestinations[index];
                        return ListTile(
                          leading: _selectedIndex == index ? dest.selectedIcon : dest.icon,
                          title: dest.label,
                          selected: _selectedIndex == index,
                          onTap: () {
                            _onDestinationSelected(index);
                            Navigator.pop(context); // Close drawer
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            LayoutBuilder(
              builder: (context, constraint) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraint.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _onDestinationSelected,
                        labelType: NavigationRailLabelType.all,
                        destinations: _navDestinations,
                        trailing: Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: IconButton(
                                icon: const Icon(Icons.logout, color: Colors.red),
                                tooltip: 'Logout',
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.clear();
                                  if (context.mounted) {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (!isMobile) const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? Builder(
              builder: (context) => BottomAppBar(
                shape: const CircularNotchedRectangle(),
                notchMargin: 8.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: 'Buka Menu',
                      icon: const Icon(Icons.menu, size: 28),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                    if (widget.userRole == 'Admin') ...[
                      IconButton(
                        tooltip: 'Dashboard',
                        icon: Icon(Icons.dashboard, color: _selectedIndex == 0 ? Colors.blue : Colors.grey),
                        onPressed: () => _onDestinationSelected(0),
                      ),
                      IconButton(
                        tooltip: 'Produk',
                        icon: Icon(Icons.inventory_2, color: _selectedIndex == 1 ? Colors.blue : Colors.grey),
                        onPressed: () => _onDestinationSelected(1),
                      ),
                    ],
                    if (widget.userRole == 'Kasir') ...[
                      IconButton(
                        tooltip: 'POS Kasir',
                        icon: Icon(Icons.point_of_sale, color: _selectedIndex == 0 ? Colors.blue : Colors.grey),
                        onPressed: () => _onDestinationSelected(0),
                      ),
                      IconButton(
                        tooltip: 'Shift',
                        icon: Icon(Icons.access_time, color: _selectedIndex == 1 ? Colors.blue : Colors.grey),
                        onPressed: () => _onDestinationSelected(1),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
