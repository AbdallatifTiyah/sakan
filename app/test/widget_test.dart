import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('الرئيسية بتفتح وفيها عنوان سكنّا وزر أضف شقتك', (WidgetTester tester) async {
    await tester.pumpWidget(const SakannaApp());
    // بدون pumpAndSettle — بيئة الاختبار بلا اتصال حقيقي بالقاعدة، فطلبات
    // الشبكة الحقيقية ما بتستقر أبداً (لا mock هون، قرار مقصود لتبسيط النطاق).
    await tester.pump();

    expect(find.text('سكنّا'), findsOneWidget);
    expect(find.text('أضف شقتك'), findsOneWidget);
  });

  testWidgets('الشريط السفلي بيبدّل لشاشتي الباحثين والإعدادات', (WidgetTester tester) async {
    await tester.pumpWidget(const SakannaApp());
    await tester.pump();

    await tester.tap(find.text('الباحثين'));
    await tester.pump();
    expect(find.text('الباحثون عن سكن'), findsOneWidget);

    await tester.tap(find.text('الإعدادات'));
    await tester.pump();
    expect(find.text('اللغة'), findsOneWidget);
    expect(find.text('حسابي'), findsOneWidget);
  });

  testWidgets('تبديل اللغة بالإعدادات بيغيّر نص شاشة الإعدادات نفسها', (WidgetTester tester) async {
    await tester.pumpWidget(const SakannaApp());
    await tester.pump();

    await tester.tap(find.text('الإعدادات'));
    await tester.pump();
    expect(find.text('Settings'), findsNothing);

    await tester.tap(find.text('English'));
    await tester.pump();
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('My account'), findsOneWidget);
  });
}
