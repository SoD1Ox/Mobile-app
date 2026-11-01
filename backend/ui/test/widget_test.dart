import 'package:flutter_test/flutter_test.dart';

import 'package:staffing_agency_ui/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const TaskTrackerApp());
    expect(find.byType(TaskTrackerApp), findsOneWidget);
  });
}
