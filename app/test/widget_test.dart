import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('App shows login screen when not authenticated', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusLifeApp());
    await tester.pumpAndSettle();
    expect(find.text('CampusLife'), findsOneWidget);
  });
}
