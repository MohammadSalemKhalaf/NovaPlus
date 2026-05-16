import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_app/app.dart';

void main() {
  testWidgets('renders starter text', (WidgetTester tester) async {
    await tester.pumpWidget(const NovaPlusApp());

    expect(find.byType(SizedBox), findsWidgets);
  });
}
