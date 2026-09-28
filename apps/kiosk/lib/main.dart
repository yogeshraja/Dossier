import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:dossier/features/billing_pos/screens/daily_sales_register_screen.dart';
import 'package:dossier/features/settings/screens/services_catalog_screen.dart';
import 'package:dossier/features/settings/screens/settings_screen.dart';
import 'package:dossier/presentation/screens/splash_screen.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_resizable_split_view.dart';
import 'package:dossier/presentation/navigation/collapsible_sidebar.dart';
import 'package:dossier/presentation/widgets/command_palette_dialog.dart';
import 'package:dossier/presentation/widgets/kiosk_status_bar.dart';

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
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF6366F1)),
                      tooltip: 'Operator Settings & Vault',
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        setState(() => _selectedTabIndex = 5);
                      },
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

  void _openCommandPalette() {
    CommandPaletteDialog.show(
      context,
      onNavigateTab: (tabIndex) {
        setState(() => _selectedTabIndex = tabIndex);
      },
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

    Widget body;

    if (isMobile) {
      // Mobile Layout with Bottom Navigation Bar
      body = Scaffold(
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
            const KioskStatusBar(compact: true),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.search_rounded, size: 20),
              tooltip: 'Quick Search & Actions',
              onPressed: _openCommandPalette,
            ),
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
            NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics_rounded), label: 'Register'),
            NavigationDestination(icon: Icon(Icons.format_list_bulleted_outlined), selectedIcon: Icon(Icons.format_list_bulleted_rounded), label: 'Catalog'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Settings'),
          ],
        ),
      );
    } else {
      // Desktop & Tablet Navigation Rail Layout
      body = Scaffold(
        body: Row(
          children: [
            CollapsibleSidebar(
              selectedIndex: _selectedTabIndex,
              onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
              currentOperator: currentOperator,
              onShowOperatorMenu: () => _showOperatorMenu(context),
              onToggleTheme: () => ref.read(kioskSettingsProvider.notifier).toggleTheme(),
              onOpenCommandPalette: _openCommandPalette,
              currentThemeMode: settings.themeMode,
              isInitiallyCollapsed: !isDesktop,
            ),

            // Main Workspace View with ambient header and animated transitions
            Expanded(
              child: Column(
                children: [
                  // Workspace Top Ambient Header
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Quick Search / Command Palette Hint Pill
                        Flexible(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _openCommandPalette,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      isDesktop ? 'Search dossiers, cases, services...' : 'Quick Search...',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Ctrl K', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Ambient Kiosk Status Bar
                        KioskStatusBar(compact: !isDesktop),
                      ],
                    ),
                  ),

                  // Tab Content
                  Expanded(
                    child: _buildAnimatedTabContent(_selectedTabIndex),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _openCommandPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openCommandPalette,
      },
      child: Focus(
        autofocus: true,
        child: body,
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
        return const DailySalesRegisterScreen();
      case 4:
        return const ServicesCatalogScreen();
      case 5:
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

        // Auto-collapse billing pane if space is constrained (< 950px)
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

        final panes = [
          // Pane 1: Customer Dossiers Directory (Resizable 220px - 450px)
          const ResizablePane(
            id: 'dossier_list',
            initialSize: 280.0,
            minSize: 220.0,
            maxSize: 450.0,
            child: DossierListPane(),
          ),

          // Pane 2: Active Case Intake & Stage Progression Stepper (Flexible)
          const ResizablePane(
            id: 'case_intake',
            isFlexible: true,
            minSize: 320.0,
            child: CaseIntakePane(),
          ),

          // Pane 3: Collapsible Billing, Dynamic UPI QR, Thermal Slip & WhatsApp Alerts
          if (isBillingExpanded)
            const ResizablePane(
              id: 'billing_hub',
              initialSize: 320.0,
              minSize: 280.0,
              maxSize: 480.0,
              child: BillingHubPane(),
            ),
        ];

        return DossierResizableSplitView(
          direction: Axis.horizontal,
          panes: panes,
          responsiveBreakpoint: 600.0,
        );
      },
    );
  }
}
