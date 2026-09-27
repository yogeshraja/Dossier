import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/app/theme.dart';
import 'package:dossier/data/local/initial_data.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';
import 'package:dossier/features/auth/screens/auth_screen.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/features/dossiers/widgets/dossier_list_pane.dart';
import 'package:dossier/features/cases/widgets/case_intake_pane.dart';
import 'package:dossier/features/billing_pos/widgets/billing_hub_pane.dart';
import 'package:dossier/features/media_prep/screens/media_prep_studio_screen.dart';
import 'package:dossier/features/billing_pos/screens/quick_pos_screen.dart';
import 'package:dossier/features/sync/screens/vault_sync_screen.dart';
import 'package:dossier/features/settings/screens/settings_screen.dart';
import 'package:dossier/presentation/screens/splash_screen.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: DossierApp(),
    ),
  );
}

class DossierApp extends ConsumerWidget {
  const DossierApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(kioskSettingsProvider);

    return MaterialApp(
      title: 'Dossier - Kiosk Vault & POS',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: settings.themeMode,
      home: const SplashScreen(),
    );
  }
}

class KioskWorkstationHome extends ConsumerStatefulWidget {
  const KioskWorkstationHome({super.key});

  @override
  ConsumerState<KioskWorkstationHome> createState() => _KioskWorkstationHomeState();
}

class _KioskWorkstationHomeState extends ConsumerState<KioskWorkstationHome> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _seedInitialData();
  }

  Future<void> _seedInitialData() async {
    final db = ref.read(databaseProvider);
    await InitialDataSeeder.cleanDummyData(db);
    await InitialDataSeeder.seedDatabase(db);
  }

  void _showOperatorMenu(BuildContext context) {
    final auth = ref.read(authProvider);
    final currentOp = auth.currentOperator;

    showDialog(
      context: context,
      builder: (ctx) => DossierDialog(
        title: 'Operator Session',
        icon: Icons.account_circle_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentOp != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: currentOp.role.color,
                      child: Text(
                        currentOp.initials,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(currentOp.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(currentOp.role.label, style: TextStyle(fontSize: 11, color: currentOp.role.color)),
                          Text(currentOp.phone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text('Switch Active Operator:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...auth.registeredOperators.map((op) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: op.role.color,
                    child: Text(op.initials, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(op.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: Text(op.role.label, style: const TextStyle(fontSize: 10)),
                  trailing: op.id == currentOp?.id
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18)
                      : null,
                  onTap: () {
                    ref.read(authProvider.notifier).switchOperator(op.id);
                    Navigator.of(ctx).pop();
                  },
                )),
          ],
        ),
        actions: [
          DossierButton(
            text: 'Sign Out',
            variant: DossierButtonVariant.danger,
            icon: Icons.logout_rounded,
            size: DossierButtonSize.sm,
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
          ),
          DossierButton(
            text: 'Close',
            variant: DossierButtonVariant.outline,
            size: DossierButtonSize.sm,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;
    final isMobile = screenWidth < 640;
    final settings = ref.watch(kioskSettingsProvider);
    final authState = ref.watch(authProvider);
    final currentOperator = authState.currentOperator;

    if (isMobile) {
      // Mobile Layout with Bottom Navigation Bar
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_shared_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('DOSSIER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
            ],
          ),
          actions: [
            if (currentOperator != null)
              IconButton(
                icon: CircleAvatar(
                  radius: 12,
                  backgroundColor: currentOperator.role.color,
                  child: Text(
                    currentOperator.initials,
                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                tooltip: 'Operator: ${currentOperator.fullName}',
                onPressed: () => _showOperatorMenu(context),
              ),
            IconButton(
              icon: Icon(settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
              tooltip: 'Toggle Theme',
              onPressed: () => ref.read(kioskSettingsProvider.notifier).toggleTheme(),
            ),
          ],
        ),
        body: _buildAnimatedTabContent(_selectedTabIndex),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedTabIndex,
          onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt_rounded), label: 'Dossiers'),
            NavigationDestination(icon: Icon(Icons.burst_mode_outlined), selectedIcon: Icon(Icons.burst_mode_rounded), label: 'Media'),
            NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale_rounded), label: 'POS'),
            NavigationDestination(icon: Icon(Icons.cloud_sync_outlined), selectedIcon: Icon(Icons.cloud_sync_rounded), label: 'Sync'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Settings'),
          ],
        ),
      );
    }

    // Desktop & Tablet Navigation Rail Layout
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
            backgroundColor: Theme.of(context).navigationRailTheme.backgroundColor,
            extended: isDesktop,
            minExtendedWidth: 200,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.folder_shared_rounded, color: Colors.white, size: 20),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DOSSIER',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'KIOSK VAULT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            fontSize: 9,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Operator Chip
                      if (currentOperator != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => _showOperatorMenu(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: currentOperator.role.color,
                                    child: Text(
                                      currentOperator.initials,
                                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (isDesktop) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        currentOperator.fullName,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down_rounded, size: 18),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      isDesktop
                          ? DossierButton(
                              text: settings.themeMode == ThemeMode.dark ? 'Light Mode' : 'Dark Mode',
                              icon: settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              size: DossierButtonSize.sm,
                              variant: DossierButtonVariant.outline,
                              onPressed: () => ref.read(kioskSettingsProvider.notifier).toggleTheme(),
                            )
                          : IconButton(
                              onPressed: () => ref.read(kioskSettingsProvider.notifier).toggleTheme(),
                              icon: Icon(
                                settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                size: 20,
                              ),
                              tooltip: 'Toggle Theme',
                            ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt_rounded),
                label: Text('Dossiers & Intake'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.burst_mode_outlined),
                selectedIcon: Icon(Icons.burst_mode_rounded),
                label: Text('Media Studio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale_rounded),
                label: Text('POS & Billing'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.cloud_sync_outlined),
                selectedIcon: Icon(Icons.cloud_sync_rounded),
                label: Text('Vault Sync'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded),
                label: Text('Catalog & Settings'),
              ),
            ],
          ),
          VerticalDivider(width: 1, thickness: 1, color: Theme.of(context).dividerColor),

          // Main Workspace View with animated transitions
          Expanded(
            child: _buildAnimatedTabContent(_selectedTabIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTabContent(int index) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(index),
        child: _buildTabContent(index),
      ),
    );
  }

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return const _DossierAdaptiveWorkspace();
      case 1:
        return const MediaPrepStudioScreen();
      case 2:
        return const QuickPosScreen();
      case 3:
        return const VaultSyncScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const SizedBox();
    }
  }
}

class _DossierAdaptiveWorkspace extends ConsumerWidget {
  const _DossierAdaptiveWorkspace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // Auto-collapse billing pane if space is constrained (< 1000px)
        final isWideEnoughForBilling = availableWidth >= 950;
        final isBillingExpanded = ref.watch(isBillingHubExpandedProvider) && isWideEnoughForBilling;

        // On very narrow screens (< 600px), switch to stepper or full-width stack
        if (availableWidth < 600) {
          final activeDossier = ref.watch(activeDossierProvider);
          if (activeDossier == null) {
            return const DossierListPane(width: double.infinity);
          }
          return const CaseIntakePane();
        }

        return Row(
          children: [
            // Pane 1: Customer Dossiers Directory (Responsive 260px - 300px)
            SizedBox(
              width: availableWidth > 1200 ? 300 : 260,
              child: const DossierListPane(),
            ),

            // Pane 2: Active Case Intake & Stage Progression Stepper
            const Expanded(
              child: CaseIntakePane(),
            ),

            // Pane 3: Collapsible Billing, Dynamic UPI QR, Thermal Slip & WhatsApp Alerts
            if (isBillingExpanded)
              SizedBox(
                width: availableWidth > 1300 ? 330 : 300,
                child: const BillingHubPane(),
              ),
          ],
        );
      },
    );
  }
}
