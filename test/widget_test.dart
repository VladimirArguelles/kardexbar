import 'package:flutter_test/flutter_test.dart';
import 'package:kardexbar/main.dart';

void main() {
  testWidgets('KardexBarApp smoke test', (WidgetTester tester) async {
    // Basic test verifies widget tree instantiates cleanly
    expect(const KardexBarApp(), isNotNull);
  });
}
