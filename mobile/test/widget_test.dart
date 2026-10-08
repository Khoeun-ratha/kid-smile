import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kid_smile/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    // The splash screen opens a real sqflite DB on startup; outside of an
    // Android/iOS test runner there's no platform channel for it, so we
    // point sqflite at the FFI (desktop) backend instead.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KidSmileApp());
    await tester.pump();

    expect(find.text('Kid Smile'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
