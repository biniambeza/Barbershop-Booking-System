import 'package:flutter_test/flutter_test.dart';
import 'package:barbershop_booking/main.dart';

void main() {
  testWidgets('Barbershop smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BarbershopApp());
    expect(find.byType(BarbershopApp), findsOneWidget);
  });
}
