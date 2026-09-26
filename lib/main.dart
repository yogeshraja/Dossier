import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/local/initial_data.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/dossiers/widgets/dossier_list_pane.dart';
import 'package:dossier/features/cases/widgets/case_intake_pane.dart';
import 'package:dossier/features/billing_pos/widgets/billing_hub_pane.dart';
import 'package:dossier/features/media_prep/screens/media_prep_studio_screen.dart';
import 'package:dossier/features/billing_pos/screens/quick_pos_screen.dart';
import 'package:dossier/features/sync/screens/vault_sync_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: DossierApp(),
    ),
  );
}

class DossierApp extends StatelessWidget {
  const DossierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dossier - Kiosk Vault & POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo accent
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A), // Slate 900
        ),
        scaffoldBackgroundColor: const Color(0xFF090D16),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
        ),
        dividerColor: const Color(0xFF334155),
      ),
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: Row(
        children: [
          // Left Navigation Rail for Workstation
          NavigationRail(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
            backgroundColor: const Color(0xFF0F172A),
            extended: isDesktop,
            minExtendedWidth: 210,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_shared_rounded, color: Colors.white, size: 22),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DOSSIER',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'KIOSK VAULT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            fontSize: 10,
                            color: Color(0xFF818CF8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt_rounded, color: Color(0xFF818CF8)),
                label: Text('Dossiers & Intake'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.burst_mode_outlined),
                selectedIcon: Icon(Icons.burst_mode_rounded, color: Color(0xFF818CF8)),
                label: Text('Media Studio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale_rounded, color: Color(0xFF818CF8)),
                label: Text('POS & Billing'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.cloud_sync_outlined),
                selectedIcon: Icon(Icons.cloud_sync_rounded, color: Color(0xFF818CF8)),
                label: Text('Vault Sync'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF334155)),

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
        return const _Dossier3PaneWorkspace();
      case 1:
        return const MediaPrepStudioScreen();
      case 2:
        return const QuickPosScreen();
      case 3:
        return const VaultSyncScreen();
      default:
        return const SizedBox();
    }
  }
}

class _Dossier3PaneWorkspace extends StatelessWidget {
  const _Dossier3PaneWorkspace();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        // Pane 1: Customer Dossiers Directory
        DossierListPane(),

        // Pane 2: Active Case Intake & Stage Progression Stepper
        Expanded(
          child: CaseIntakePane(),
        ),

        // Pane 3: Billing, Dynamic UPI QR, Thermal Slip & WhatsApp Alerts
        BillingHubPane(),
      ],
    );
  }
}
