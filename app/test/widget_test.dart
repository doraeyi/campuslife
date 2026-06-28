import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('App shows schedule title', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusLifeApp());
    expect(find.text('我的班表'), findsOneWidget);
  });
}
