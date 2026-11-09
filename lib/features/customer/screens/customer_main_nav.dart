import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'customer_home_screen.dart';
import 'customer_bookings_screen.dart';

class CustomerMainNav extends StatefulWidget {
  const CustomerMainNav({super.key});

  @override
  State<CustomerMainNav> createState() => _CustomerMainNavState();
}

class _CustomerMainNavState extends State<CustomerMainNav> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CustomerHomeScreen(),
    CustomerBookingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Colors.black),
            label: 'Appointments',
          ),
        ],
      ),
    );
  }
}
