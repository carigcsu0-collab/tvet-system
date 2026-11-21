import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/records_refresh.dart';
import 'shared/presentation/screens/activity_logs_screen.dart';
import 'shared/presentation/screens/assessors_screen.dart';
import 'shared/presentation/screens/assessees_list_screen.dart';
import 'shared/presentation/screens/assessor_fee_letter_screen.dart';
import 'shared/presentation/screens/centers_screen.dart';
import 'shared/presentation/screens/certificate_of_appearance_screen.dart';
import 'shared/presentation/screens/code_monitoring_screen.dart';
import 'shared/presentation/screens/dashboard_screen.dart';
import 'shared/presentation/screens/document_code_settings_screen.dart';
import 'shared/presentation/screens/document_monitoring_screen.dart';
import 'shared/presentation/screens/document_records_screen.dart';
import 'shared/presentation/screens/payment_slip_screen.dart';
import 'shared/presentation/screens/scholar_billing_screen.dart';
import 'shared/presentation/screens/training_batches_screen.dart';
import 'shared/presentation/screens/users_screen.dart';
import 'shared/presentation/widgets/app_nav_drawer.dart';
import 'shared/presentation/widgets/window_title_bar.dart';
import 'main.dart';

// Keys to reload lists when their tab is selected.
final _documentRecordsKey = GlobalKey<DocumentRecordsScreenState>();
final _assessmentKey = GlobalKey<AssesseesListScreenState>();
final _trainingKey = GlobalKey<AssesseesListScreenState>();
final _paymentSlipKey = GlobalKey<PaymentSlipScreenState>();
final _trainingBatchesKey = GlobalKey<TrainingBatchesScreenState>();
final _scholarBillingKey = GlobalKey<ScholarBillingScreenState>();
final _codeMonitoringKey = GlobalKey<CodeMonitoringScreenState>();

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final _recordsRefresh = RecordsRefresh();
  final _visitedTabs = <int>{0};

  @override
  Widget build(BuildContext context) {
    final titles = [
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
    ];

    final screens = [
      const DashboardScreen(),
      const CertificateOfAppearanceScreen(),
      const AssessorFeeLetterScreen(),
      DocumentRecordsScreen(key: _documentRecordsKey),
      PaymentSlipScreen(key: _paymentSlipKey),
      const DocumentMonitoringScreen(),
      CodeMonitoringScreen(key: _codeMonitoringKey),
      const CentersScreen(),
      const AssessorsScreen(),
      AssesseesListScreen(key: _assessmentKey, type: 'assessment'),
      AssesseesListScreen(key: _trainingKey, type: 'training'),
      TrainingBatchesScreen(key: _trainingBatchesKey),
      ScholarBillingScreen(key: _scholarBillingKey),
      const UsersScreen(),
      const ActivityLogsScreen(),
      const DocumentCodeSettingsScreen(),
    ];

    void refreshRecords() => _documentRecordsKey.currentState?.load();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        WindowTitleBar(title: 'TVET Documents - ${titles[_selectedIndex]}'),
        Expanded(
          child: Scaffold(
            appBar: AppBar(
              title: Text(titles[_selectedIndex]),
              actions: [
                if (_selectedIndex == 3)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh records',
                    onPressed: refreshRecords,
                  ),
                IconButton(
                  icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                  tooltip: isDark ? 'Light mode' : 'Dark mode',
                  onPressed: () {
                    context.findAncestorStateOfType<MyAppState>()?.toggleTheme();
                  },
                ),
              ],
            ),
            drawer: AppNavDrawer(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) {
                setState(() {
                  _selectedIndex = i;
                  _visitedTabs.add(i);
                });
                Navigator.pop(context);
                if (i == 3) {
                  _documentRecordsKey.currentState?.load();
                } else if (i == 4) {
                  _paymentSlipKey.currentState?.reload();
                } else if (i == 6) {
                  _codeMonitoringKey.currentState?.load();
                } else if (i == 9) {
                  _assessmentKey.currentState?.load();
                } else if (i == 10) {
                  _trainingKey.currentState?.load();
                } else if (i == 11) {
                  _trainingBatchesKey.currentState?.load();
                } else if (i == 12) {
                  _scholarBillingKey.currentState?.load();
                }
              },
            ),
            body: ChangeNotifierProvider.value(
              value: _recordsRefresh,
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  for (int i = 0; i < screens.length; i++)
                    _visitedTabs.contains(i) ? screens[i] : const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
