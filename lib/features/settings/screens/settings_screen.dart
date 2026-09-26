import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/features/settings/widgets/edit_service_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _kioskNameCtrl = TextEditingController();
  final _kioskPhoneCtrl = TextEditingController();
  final _kioskAddressCtrl = TextEditingController();
  final _upiVpaCtrl = TextEditingController();

  static const _categoryLabels = {
    'GOVT_SCHEME': 'Govt Schemes',
    'PRINTING': 'Printing & Xerox',
    'CERTIFICATE': 'Certificates',
    'UTILITY': 'Utility Bills',
    'LEGAL': 'Legal & Typing',
    'FINANCIAL': 'Financial',
  };

  static const _currencyPresets = [
    {'symbol': '₹', 'code': 'INR', 'label': '₹ INR'},
    {'symbol': '\$', 'code': 'USD', 'label': '\$ USD'},
    {'symbol': '€', 'code': 'EUR', 'label': '€ EUR'},
    {'symbol': '£', 'code': 'GBP', 'label': '£ GBP'},
    {'symbol': 'AED', 'code': 'AED', 'label': 'AED'},
    {'symbol': 'SAR', 'code': 'SAR', 'label': 'SAR'},
    {'symbol': '৳', 'code': 'BDT', 'label': '৳ BDT'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final settings = ref.read(kioskSettingsProvider);
    _kioskNameCtrl.text = settings.kioskName;
    _kioskPhoneCtrl.text = settings.kioskPhone;
    _kioskAddressCtrl.text = settings.kioskAddress;
    _upiVpaCtrl.text = settings.merchantUpiVpa;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _kioskNameCtrl.dispose();
    _kioskPhoneCtrl.dispose();
    _kioskAddressCtrl.dispose();
    _upiVpaCtrl.dispose();
    super.dispose();
  }

  void _saveKioskProfile() {
    ref.read(kioskSettingsProvider.notifier).updateKioskInfo(
          name: _kioskNameCtrl.text.trim(),
          address: _kioskAddressCtrl.text.trim(),
          phone: _kioskPhoneCtrl.text.trim(),
          upiVpa: _upiVpaCtrl.text.trim(),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kiosk Profile & Receipt Headers updated!'), backgroundColor: Color(0xFF10B981)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(kioskSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 750;

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Catalog & Settings',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(text: 'Services Catalog'),
                          Tab(text: 'Currency & Theme'),
                          Tab(text: 'Kiosk Identity & QR'),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Catalog Customization & Kiosk Settings',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          const Text('Configure service fee breakups, document checklists, currency, and themes',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 440,
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(icon: Icon(Icons.format_list_bulleted_rounded, size: 15), text: 'Services Catalog'),
                          Tab(icon: Icon(Icons.currency_exchange_rounded, size: 15), text: 'Currency & Theme'),
                          Tab(icon: Icon(Icons.storefront_rounded, size: 15), text: 'Kiosk Profile & QR'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildServicesCatalogTab(settings, isDark),
                _buildCurrencyThemeTab(settings, isDark),
                _buildKioskProfileTab(settings, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 1: Services Catalog & Opt-ins ---
  Widget _buildServicesCatalogTab(KioskSettings settings, bool isDark) {
    final servicesAsync = ref.watch(activeServicesStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Opt-ins Bar
          DossierCard(
            variant: DossierCardVariant.flat,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active Service Category Opt-Ins:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _categoryLabels.entries.map((entry) {
                    final isOptedIn = settings.activeCategories.contains(entry.key);
                    return FilterChip(
                      selected: isOptedIn,
                      label: Text(entry.value, style: const TextStyle(fontSize: 11.5)),
                      visualDensity: VisualDensity.compact,
                      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      onSelected: (_) => ref.read(kioskSettingsProvider.notifier).toggleCategory(entry.key),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Services Table Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text('Configured Master Services',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              DossierButton(
                text: 'Add Custom Service',
                icon: Icons.add_rounded,
                size: DossierButtonSize.sm,
                variant: DossierButtonVariant.primary,
                onPressed: () {
                  DossierDialog.show(
                    context: context,
                    builder: (_) => const EditServiceDialog(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Services List
          Expanded(
            child: servicesAsync.when(
              data: (services) {
                if (services.isEmpty) {
                  return const Center(child: Text('No services configured'));
                }

                return ListView.separated(
                  itemCount: services.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final s = services[index];
                    List<dynamic> docs = [];
                    try {
                      docs = jsonDecode(s.requiredDocsJson);
                    } catch (_) {}

                    return DossierCard(
                      variant: DossierCardVariant.outlined,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.description_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    DossierBadge(
                                      text: _categoryLabels[s.category] ?? s.category,
                                      variant: DossierBadgeVariant.neutral,
                                      fontSize: 9.5,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Portal: ${settings.currencySymbol}${s.defaultPortalFee.toStringAsFixed(0)}  •  Shop: ${settings.currencySymbol}${s.defaultServiceFee.toStringAsFixed(0)}  •  Total: ${settings.currencySymbol}${(s.defaultPortalFee + s.defaultServiceFee).toStringAsFixed(0)}',
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                                if (docs.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Docs: ${docs.join(", ")}',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 10.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            tooltip: 'Edit Service',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              DossierDialog.show(
                                context: context,
                                builder: (_) => EditServiceDialog(existingService: s),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading services: $err')),
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 2: Currency & Theme Customization ---
  Widget _buildCurrencyThemeTab(KioskSettings settings, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Theme Mode Switcher
          DossierCard(
            variant: DossierCardVariant.glass,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Appearance & Color Theme', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      selected: settings.themeMode == ThemeMode.dark,
                      avatar: const Icon(Icons.dark_mode_rounded, size: 16),
                      label: const Text('Modern Dark Mode'),
                      onSelected: (_) => ref.read(kioskSettingsProvider.notifier).setThemeMode(ThemeMode.dark),
                    ),
                    ChoiceChip(
                      selected: settings.themeMode == ThemeMode.light,
                      avatar: const Icon(Icons.light_mode_rounded, size: 16),
                      label: const Text('Crisp Light Mode'),
                      onSelected: (_) => ref.read(kioskSettingsProvider.notifier).setThemeMode(ThemeMode.light),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Currency Customizer
          DossierCard(
            variant: DossierCardVariant.glass,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.currency_exchange_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Global Currency & Formatting', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Select your local currency for receipts, POS carts, and UPI links.', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _currencyPresets.map((c) {
                    final isSelected = settings.currencySymbol == c['symbol'] && settings.currencyCode == c['code'];
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(c['label']!),
                      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => ref.read(kioskSettingsProvider.notifier).updateCurrency(c['symbol']!, c['code']!),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 3: Kiosk Profile & Hardware / QR Settings ---
  Widget _buildKioskProfileTab(KioskSettings settings, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DossierCard(
        variant: DossierCardVariant.glass,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storefront_rounded, size: 18),
                SizedBox(width: 8),
                Text('Kiosk Identity & Receipt Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            DossierInputField(
              controller: _kioskNameCtrl,
              label: 'Kiosk / Cyber Center Name *',
              hintText: 'e.g. Metro CSC Center',
              prefixIcon: const Icon(Icons.store_rounded, size: 18),
            ),
            const SizedBox(height: 14),
            DossierInputField(
              controller: _kioskPhoneCtrl,
              label: 'Public Contact Number *',
              hintText: 'e.g. +91 98765 43210',
              prefixIcon: const Icon(Icons.phone_rounded, size: 18),
            ),
            const SizedBox(height: 14),
            DossierInputField(
              controller: _kioskAddressCtrl,
              label: 'Center Physical Address',
              hintText: 'e.g. Shop 4, Main Market, Civil Lines',
              prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
            ),
            const SizedBox(height: 14),
            DossierInputField(
              controller: _upiVpaCtrl,
              label: 'Merchant UPI ID *',
              hintText: 'e.g. yourshop@oksbi',
              prefixIcon: const Icon(Icons.qr_code_rounded, size: 18),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: DossierButton(
                text: 'Save Kiosk Profile',
                icon: Icons.save_rounded,
                variant: DossierButtonVariant.primary,
                size: DossierButtonSize.md,
                onPressed: _saveKioskProfile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
