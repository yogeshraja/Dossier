import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo/Violet accent
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

class KioskWorkstationHome extends StatefulWidget {
  const KioskWorkstationHome({super.key});

  @override
  State<KioskWorkstationHome> createState() => _KioskWorkstationHomeState();
}

class _KioskWorkstationHomeState extends State<KioskWorkstationHome> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: Row(
        children: [
          // Left Navigation Rail for Desktop
          NavigationRail(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
            backgroundColor: const Color(0xFF0F172A),
            extended: isDesktop,
            minExtendedWidth: 200,
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
                    const Text(
                      'DOSSIER',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 16,
                        color: Colors.white,
                      ),
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
          const VerticalDivider(width: 1, thickness: 1),

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
        return _buildDossierIntakeView();
      case 1:
        return _buildMediaStudioView();
      case 2:
        return _buildPosBillingView();
      case 3:
        return _buildVaultSyncView();
      default:
        return const SizedBox();
    }
  }

  Widget _buildDossierIntakeView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Dossiers & Case Intake',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search customer phone number or start instant case intake',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('New Walk-in Customer'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by customer name, phone number, or case ID...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_outlined, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  const Text(
                    'No active case selected',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Look up an existing customer or tap "New Walk-in Customer" to begin',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaStudioView() {
    return const Center(
      child: Text(
        'Media Prep Studio (ID Card Stitcher, Compressor & 4x6 Photo Grid)',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }

  Widget _buildPosBillingView() {
    return const Center(
      child: Text(
        'POS & Billing (Dynamic UPI QR & ESC/POS Receipt Printer)',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }

  Widget _buildVaultSyncView() {
    return const Center(
      child: Text(
        'Vault Sync Engine (BYO Google Drive & Cloudflare R2)',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }
}
