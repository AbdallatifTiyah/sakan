import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('الرئيسية بتفتح وفيها عنوان سكنّا وزر أضف شقتك', (WidgetTester tester) async {
    await tester.pumpWidget(const SakannaApp());
    await tester.pumpAndSettle();

    expect(find.text('سكنّا'), findsOneWidget);
    expect(find.text('أضف شقتك'), findsOneWidget);
    expect(find.text('شقق متاحة للعائلات'), findsOneWidget);
  });

  testWidgets('الضغط على كرت إعلان يفتح شاشة التفاصيل', (WidgetTester tester) async {
    await tester.pumpWidget(const SakannaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('شقة عائلية واسعة قرب حي الطيرة').first);
    await tester.pumpAndSettle();

    expect(find.text('أرسل طلب التواصل'), findsOneWidget);
  });
}
