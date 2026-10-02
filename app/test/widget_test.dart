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
}
