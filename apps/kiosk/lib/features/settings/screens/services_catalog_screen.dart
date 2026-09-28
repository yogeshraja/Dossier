import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/features/settings/widgets/edit_service_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';

class ServicesCatalogScreen extends ConsumerStatefulWidget {
  const ServicesCatalogScreen({super.key});

  @override
  ConsumerState<ServicesCatalogScreen> createState() => _ServicesCatalogScreenState();
}

class _ServicesCatalogScreenState extends ConsumerState<ServicesCatalogScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedCategoryFilter = 'ALL';

  static const _categoryLabels = {
    'GOVT_SCHEME': 'Govt Schemes',
    'PRINTING': 'Printing & Xerox',
    'CERTIFICATE': 'Certificates',
    'UTILITY': 'Utility Bills',
    'LEGAL': 'Legal & Typing',
    'FINANCIAL': 'Financial',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final settings = ref.watch(kioskSettingsProvider);
    final servicesAsync = ref.watch(activeServicesStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.format_list_bulleted_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Services & Price Catalog',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Master catalog of government schemes, printing rates, and counter service fees',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    DossierButton(
                      text: 'Add Custom Service',
                      icon: Icons.add_rounded,
                      size: isNarrow ? DossierButtonSize.sm : DossierButtonSize.md,
                      variant: DossierButtonVariant.primary,
                      tooltip: 'Define a new billable service offering in your catalog',
                      onPressed: () {
                        DossierDialog.show(
                          context: context,
                          builder: (_) => const EditServiceDialog(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Search & Category Filters
            DossierCard(
              variant: DossierCardVariant.glass,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: DossierInputField(
                          hintText: 'Search services by title or document requirements...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Categories:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[400]),
                      ),
                      ChoiceChip(
                        label: const Text('All', style: TextStyle(fontSize: 11.5)),
                        selected: _selectedCategoryFilter == 'ALL',
                        visualDensity: VisualDensity.compact,
                        selectedColor: primaryColor.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedCategoryFilter = 'ALL');
                        },
                      ),
                      ..._categoryLabels.entries.map((entry) {
                        final isSelected = _selectedCategoryFilter == entry.key;
                        final isOptedIn = settings.activeCategories.contains(entry.key);
                        return ChoiceChip(
                          avatar: isOptedIn ? const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)) : null,
                          label: Text(entry.value, style: const TextStyle(fontSize: 11.5)),
                          selected: isSelected,
                          visualDensity: VisualDensity.compact,
                          selectedColor: primaryColor.withValues(alpha: 0.2),
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedCategoryFilter = entry.key);
                          },
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Services Grid/List View
            Expanded(
              child: servicesAsync.when(
                data: (services) {
                  final query = _searchCtrl.text.trim().toLowerCase();
                  final filteredServices = services.where((s) {
                    final matchesCategory = _selectedCategoryFilter == 'ALL' || s.category == _selectedCategoryFilter;
                    final matchesQuery = query.isEmpty ||
                        s.name.toLowerCase().contains(query) ||
                        s.category.toLowerCase().contains(query) ||
                        s.requiredDocsJson.toLowerCase().contains(query);
                    return matchesCategory && matchesQuery;
                  }).toList();

                  if (filteredServices.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[500]),
                          const SizedBox(height: 12),
                          Text(
                            query.isNotEmpty ? 'No services matching "$query"' : 'No services configured in this category',
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Click "Add Custom Service" above to introduce a new offering.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredServices.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final s = filteredServices[index];
                      List<dynamic> docs = [];
                      try {
                        docs = jsonDecode(s.requiredDocsJson);
                      } catch (_) {}

                      final totalFee = s.defaultPortalFee + s.defaultServiceFee;

                      return DossierCard(
                        variant: DossierCardVariant.outlined,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.description_rounded, color: primaryColor, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        s.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                      ),
                                      DossierBadge(
                                        label: _categoryLabels[s.category] ?? s.category,
                                        variant: DossierBadgeVariant.primary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        'Portal Fee: ${settings.currencySymbol}${s.defaultPortalFee.toStringAsFixed(0)}',
                                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                                      ),
                                      Text(
                                        'Shop Fee: ${settings.currencySymbol}${s.defaultServiceFee.toStringAsFixed(0)}',
                                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                                      ),
                                      Text(
                                        'Total Rate: ${settings.currencySymbol}${totalFee.toStringAsFixed(0)}',
                                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  if (docs.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Required Exhibits: ${docs.join(" • ")}',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              tooltip: 'Edit Service Pricing',
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
      ),
    );
  }
}
