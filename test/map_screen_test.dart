import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barbershop_booking/features/customer/screens/nearby_map_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_main_nav.dart';

void main() {
  testWidgets('Test CustomerMainNav and NearbyMapScreen pump', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CustomerMainNav()));
    await tester.pump();
    expect(find.byType(CustomerMainNav), findsOneWidget);

    // Tap the map tab in bottom nav
    await tester.tap(find.text('Nearby Map'));
    await tester.pump();
    expect(find.byType(NearbyMapScreen), findsOneWidget);
  });
}
