import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/app/theme.dart';
import 'package:dossier/data/local/initial_data.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/features/dossiers/widgets/dossier_list_pane.dart';
import 'package:dossier/features/cases/widgets/case_intake_pane.dart';
import 'package:dossier/features/billing_pos/widgets/billing_hub_pane.dart';
import 'package:dossier/features/media_prep/screens/media_prep_studio_screen.dart';
import 'package:dossier/features/billing_pos/screens/quick_pos_screen.dart';
import 'package:dossier/features/sync/screens/vault_sync_screen.dart';
import 'package:dossier/features/settings/screens/settings_screen.dart';

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
      home: const KioskWorkstationHome(),
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
    await InitialDataSeeder.seedDatabase(db);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;
    final isTablet = screenWidth >= 640 && screenWidth < 1000;
    final isMobile = screenWidth < 640;
    final settings = ref.watch(kioskSettingsProvider);

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
            IconButton(
              icon: Icon(settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
              tooltip: 'Toggle Theme',
              onPressed: () => ref.read(kioskSettingsProvider.notifier).toggleTheme(),
            ),
          ],
        ),
        body: _buildTabContent(_selectedTabIndex),
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
                  child: isDesktop
                      ? OutlinedButton.icon(
                          onPressed: () => ref.read(kioskSettingsProvider.notifier).toggleTheme(),
                          icon: Icon(
                            settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            size: 15,
                          ),
                          label: Text(settings.themeMode == ThemeMode.dark ? 'Light' : 'Dark', style: const TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Theme.of(context).dividerColor),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        )
                      : IconButton(
                          onPressed: () => ref.read(kioskSettingsProvider.notifier).toggleTheme(),
                          icon: Icon(
                            settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            size: 20,
                          ),
                          tooltip: 'Toggle Theme',
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

          // Main Workspace View
          Expanded(
            child: _buildTabContent(_selectedTabIndex),
          ),
        ],
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
