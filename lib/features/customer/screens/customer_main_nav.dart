import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../shared/widgets/ui_kit.dart';
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
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: FloatingPillNavBar(
        selectedIndex: _currentIndex,
        onSelected: (idx) => setState(() => _currentIndex = idx),
        items: [
          PillNavItem(
            icon: Icons.storefront_outlined,
            selectedIcon: Icons.storefront,
            label: context.l10n.navBarbershops,
          ),
          PillNavItem(
            icon: Icons.content_cut_outlined,
            selectedIcon: Icons.content_cut,
            label: context.l10n.findBarbers,
          ),
          PillNavItem(
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
            label: context.l10n.navAppointments,
          ),
        ],
      ),
    );
  }
}
