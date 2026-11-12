import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'customer_home_screen.dart';
import 'find_barbers_screen.dart';
import 'customer_bookings_screen.dart';

class CustomerMainNav extends StatefulWidget {
  const CustomerMainNav({super.key});

  @override
  State<CustomerMainNav> createState() => _CustomerMainNavState();
}

class _CustomerMainNavState extends State<CustomerMainNav> {
  int _currentIndex = 0;

  void _navigateToBarbers() {
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CustomerHomeScreen(onOpenBarbers: _navigateToBarbers),
      const FindBarbersScreen(),
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
            icon: Icon(Icons.content_cut_outlined),
            selectedIcon: Icon(Icons.content_cut, color: Colors.black),
            label: 'Find Barbers',
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
