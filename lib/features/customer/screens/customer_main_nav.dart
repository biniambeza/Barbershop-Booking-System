import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'customer_home_screen.dart';
import 'nearby_map_screen.dart';
import 'customer_bookings_screen.dart';

class CustomerMainNav extends StatefulWidget {
  const CustomerMainNav({super.key});

  @override
  State<CustomerMainNav> createState() => _CustomerMainNavState();
}

class _CustomerMainNavState extends State<CustomerMainNav> {
  int _currentIndex = 0;

  void _navigateToMap() {
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CustomerHomeScreen(onOpenMap: _navigateToMap),
      const NearbyMapScreen(),
      const CustomerBookingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: AppTheme.darkSurface,
        indicatorColor: AppTheme.primaryGold,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: Colors.black),
            label: 'Barbershops',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: Colors.black),
            label: 'Nearby Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Colors.black),
            label: 'Appointments',
          ),
        ],
      ),
    );
  }
}
