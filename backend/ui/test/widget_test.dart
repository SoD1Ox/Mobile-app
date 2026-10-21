import 'package:flutter_test/flutter_test.dart';

import 'package:task_tracker_ui/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const TaskTrackerApp());
    expect(find.byType(TaskTrackerApp), findsOneWidget);
  });
}
