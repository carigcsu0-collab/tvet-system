import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvet_documents/core/auth_provider.dart';
import 'package:tvet_documents/shared/presentation/widgets/app_nav_drawer.dart';

void main() {
  testWidgets('navigation shows code monitoring and omits removed screens',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 2500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selected;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          theme: ThemeData(
            navigationDrawerTheme: const NavigationDrawerThemeData(
              labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 6)),
            ),
          ),
          home: Scaffold(
            body: AppNavDrawer(
              selectedIndex: 0,
              onDestinationSelected: (index) => selected = index,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final labels = tester
        .widgetList<NavigationDrawerDestination>(
            find.byType(NavigationDrawerDestination))
        .map((destination) => (destination.label as Text).data)
        .toList();
    expect(labels, [
      'Dashboard',
      'Certificate of Appearance',
      "Assessor's Fee",
      'Document Records',
      'Payment Slip',
      'Document Monitoring',
      'Code Monitoring',
      'Centers',
      'Assessors',
      'Assessment Centers',
      'Training Centers',
      'Training Attendance & Billing',
      'Scholar Billing Monitoring',
      'User Accounts',
      'Account Logs',
      'Document Code Settings',
    ]);
    await tester.ensureVisible(find.text('Code Monitoring'));
    await tester.tap(find.text('Code Monitoring'));
    await tester.pump();
    expect(selected, 6);
  });
}
