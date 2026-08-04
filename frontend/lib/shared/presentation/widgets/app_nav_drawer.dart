import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_theme.dart';
import '../../../core/auth_provider.dart';

class AppNavDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppNavDrawer({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.csuMaroonLight : AppTheme.csuMaroon;

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        // Branded header
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, AppTheme.csuMaroonDark],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.network(
                        'https://csu.edu.ph/img/csulogo_index.png',
                        height: 44,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.school, color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TVET Documents',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Carig Campus',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            auth.rememberedEmail ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Documents section
        _sectionLabel(context, 'Documents'),
        const NavigationDrawerDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.card_membership_outlined),
          selectedIcon: Icon(Icons.card_membership),
          label: Text('Certificate of Appearance'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.message_outlined),
          selectedIcon: Icon(Icons.message),
          label: Text('Internal Communication'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.mail_outline),
          selectedIcon: Icon(Icons.mail),
          label: Text('External Communication'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.verified_outlined),
          selectedIcon: Icon(Icons.verified),
          label: Text('Endorsement'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: Text('Report on Assessment Proceedings'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.rate_review_outlined),
          selectedIcon: Icon(Icons.rate_review),
          label: Text('Performance Evaluation Instrument'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.table_chart_outlined),
          selectedIcon: Icon(Icons.table_chart),
          label: Text("Assessor's Fee"),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: Text('Document Records'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text('Payment Slip'),
        ),

        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),

        // Centers section
        _sectionLabel(context, 'Centers'),
        const NavigationDrawerDestination(
          icon: Icon(Icons.business_outlined),
          selectedIcon: Icon(Icons.business),
          label: Text('Centers'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Assessors'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: Text('Assessment Centers'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.school_outlined),
          selectedIcon: Icon(Icons.school),
          label: Text('Training Centers'),
        ),

        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),

        // Administration section
        _sectionLabel(context, 'Administration'),
        const NavigationDrawerDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('User Accounts'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: Text('Account Logs'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.tag_outlined),
          selectedIcon: Icon(Icons.tag),
          label: Text('Document Code Settings'),
        ),

        const SizedBox(height: 8),
        const Divider(),

        // Logout
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.error),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            onTap: () => auth.logout(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
