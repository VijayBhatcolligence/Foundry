import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_app/main.dart';

void main() {
  testWidgets('FoundryApp renders without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const FoundryApp());
    expect(find.byType(FoundryApp), findsOneWidget);
  });
}
