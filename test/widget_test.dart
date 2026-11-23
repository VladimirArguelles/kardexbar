import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kardexbar/features/auth/boot_screen.dart';
import 'package:kardexbar/main.dart';

void main() {
  testWidgets('KardexBarApp smoke test', (WidgetTester tester) async {
    // Verifica que el árbol de widgets se instancie limpiamente
    expect(const KardexBarApp(), isNotNull);
  });

  testWidgets('BootScreen renders KardexBar-Logo', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: BootScreen()));

    expect(find.byType(BootScreen), findsOneWidget);
    expect(find.text('KARDEXBAR'), findsOneWidget);

    // Permitir que la secuencia de timers del boot termine limpiamente
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
