import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront, color: Colors.black),
            label: context.l10n.navBarbershops,
          ),
          NavigationDestination(
            icon: const Icon(Icons.content_cut_outlined),
            selectedIcon: const Icon(Icons.content_cut, color: Colors.black),
            label: context.l10n.findBarbers,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month, color: Colors.black),
            label: context.l10n.navAppointments,
          ),
        ],
      ),
    );
  }
}
