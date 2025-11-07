// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:poliedro_pi/main.dart';
import 'package:poliedro_pi/src/features/auth/providers/auth_provider.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    // Monta o aplicativo com os providers necessários
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
        child: const App(),
      ),
    );

    // Deve existir um MaterialApp na árvore
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
