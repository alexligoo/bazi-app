import 'package:flutter_test/flutter_test.dart';
import 'package:bazi_app/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const BaZiApp());
    expect(find.text('八字排盘'), findsOneWidget);
  });
}
