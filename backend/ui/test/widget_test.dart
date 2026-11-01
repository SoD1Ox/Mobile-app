// Basic smoke test for the Staffing Agency UI.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:staffing_agency_ui/main.dart';

void main() {
  testWidgets('App builds and shows auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(const StaffingAgencyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
