// Basic smoke test: the app widget tree builds without throwing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:staffing_agency_ui/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const StaffingAgencyApp());
    expect(find.byType(Navigator), findsOneWidget);
  });
}
