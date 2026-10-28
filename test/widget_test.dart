// Basit duman testi: uygulama kabuğu hatasız açılıyor mu?
// (Supabase başlatma gerektirmemesi için doğrudan EslesmeApp kullanılmaz;
// eşleşme/puanlama mantığı geldikçe gerçek testler eklenecek.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp kabuğu açılır', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Eşleşme'))),
    );
    expect(find.text('Eşleşme'), findsOneWidget);
  });
}
