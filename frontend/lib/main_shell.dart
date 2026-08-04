import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/records_refresh.dart';
import 'shared/presentation/screens/activity_logs_screen.dart';
import 'shared/presentation/screens/assessors_screen.dart';
import 'shared/presentation/screens/assessees_list_screen.dart';
import 'shared/presentation/screens/assessor_fee_letter_screen.dart';
import 'shared/presentation/screens/centers_screen.dart';
import 'shared/presentation/screens/certificate_of_appearance_screen.dart';
import 'shared/presentation/screens/dashboard_screen.dart';
import 'shared/presentation/screens/document_code_settings_screen.dart';
import 'shared/presentation/screens/document_records_screen.dart';
import 'shared/presentation/screens/document_screen.dart';
import 'shared/presentation/screens/endorsement_screen.dart';
import 'shared/presentation/screens/payment_slip_screen.dart';
import 'shared/presentation/screens/pei_screen.dart';
import 'shared/presentation/screens/rap_screen.dart';
import 'shared/presentation/screens/users_screen.dart';
import 'shared/presentation/widgets/app_nav_drawer.dart';
import 'main.dart';

// Keys to reload lists when their tab is selected.
final _documentRecordsKey = GlobalKey<DocumentRecordsScreenState>();
final _assessmentKey = GlobalKey<AssesseesListScreenState>();
final _trainingKey = GlobalKey<AssesseesListScreenState>();

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final _recordsRefresh = RecordsRefresh();
  final _visitedTabs = <int>{0};

  final List<FieldConfig> _internalFields = const [
    FieldConfig(name: 'to', label: 'To (Name, Designation, Office, Address)'),
    FieldConfig(name: 'from', label: 'Thru (Office)'),
    FieldConfig(name: 'subject', label: 'Subject'),
    FieldConfig(name: 'body', label: 'Body', maxLines: 5),
  ];

  final List<FieldConfig> _externalFields = const [
    FieldConfig(name: 'recipient', label: 'To (Name, Designation, Office, Address)'),
    FieldConfig(name: 'organization', label: 'Designation / Office'),
    FieldConfig(name: 'address', label: 'Address'),
    FieldConfig(name: 'subject', label: 'Subject'),
    FieldConfig(name: 'body', label: 'Body', maxLines: 5),
  ];

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Dashboard',
      'Certificate of Appearance',
      'Internal Communication',
      'External Communication',
      'Endorsement',
      'Report on Assessment Proceedings',
      'Performance Evaluation Instrument',
      "Assessor's Fee",
      'Document Records',
      'Payment Slip',
      'Centers',
      'Assessors',
      'Assessment Centers',
      'Training Centers',
      'User Accounts',
      'Account Logs',
      'Document Code Settings',
    ];

    final screens = [
      const DashboardScreen(),
      const CertificateOfAppearanceScreen(),
      DocumentScreen(
        slug: AppConstants.internalSlug,
        title: 'Internal Communication',
        icon: Icons.message,
        fields: _internalFields,
        showLetterhead: true,
        allowTable: true,
      ),
      DocumentScreen(
        slug: AppConstants.externalSlug,
        title: 'External Communication',
        icon: Icons.mail_outline,
        fields: _externalFields,
        showLetterhead: true,
        allowTable: true,
      ),
      const EndorsementScreen(),
      const RapScreen(),
      const PeiScreen(),
      const AssessorFeeLetterScreen(),
      DocumentRecordsScreen(key: _documentRecordsKey),
      const PaymentSlipScreen(),
      const CentersScreen(),
      const AssessorsScreen(),
      AssesseesListScreen(key: _assessmentKey, type: 'assessment'),
      AssesseesListScreen(key: _trainingKey, type: 'training'),
      const UsersScreen(),
      const ActivityLogsScreen(),
      const DocumentCodeSettingsScreen(),
    ];

    void refreshRecords() => _documentRecordsKey.currentState?.load();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          if (_selectedIndex == 8)
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
          if (i == 8) {
            _documentRecordsKey.currentState?.load();
          } else if (i == 12) {
            _assessmentKey.currentState?.load();
          } else if (i == 13) {
            _trainingKey.currentState?.load();
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
    );
  }
}
