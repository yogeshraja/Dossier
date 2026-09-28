import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/app/theme.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/dossiers/widgets/new_dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';

class DossierListPane extends ConsumerWidget {
  final double? width;
  const DossierListPane({super.key, this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossiersAsync = ref.watch(dossiersStreamProvider);
    final allCasesAsync = ref.watch(allCasesStreamProvider);
    final activeDossier = ref.watch(activeDossierProvider);
    final searchQuery = ref.watch(dossierSearchQueryProvider);
    final activeFilter = ref.watch(dossierFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allCases = allCasesAsync.asData?.value ?? [];

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
      ),
      child: Column(
        children: [
          // Header & Search
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Dossiers',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        dossiersAsync.maybeWhen(
                          data: (dossiers) => DossierBadge(
                            label: '${dossiers.length}',
                            variant: DossierBadgeVariant.neutral,
                          ),
                          orElse: () => const SizedBox(),
                        ),
                      ],
                    ),
                    DossierButton(
                      text: 'Add',
                      icon: Icons.person_add_alt_1_rounded,
                      size: DossierButtonSize.sm,
                      variant: DossierButtonVariant.primary,
                      onPressed: () {
                        DossierDialog.show(
                          context: context,
                          builder: (_) => const NewDossierDialog(),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DossierInputField(
                  isSearch: true,
                  hintText: 'Search phone or name...',
                  initialValue: searchQuery,
                  showClearButton: true,
                  onChanged: (val) => ref.read(dossierSearchQueryProvider.notifier).state = val,
                ),
                const SizedBox(height: 10),

                // Smart Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: DossierFilterCategory.values.map((cat) {
                      final isSelected = activeFilter == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF6366F1),
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : Theme.of(context).dividerColor.withValues(alpha: 0.6),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onSelected: (_) {
                            ref.read(dossierFilterProvider.notifier).state = cat;
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),

          // Customer List
          Expanded(
            child: dossiersAsync.when(
              data: (dossiers) {
                // Apply smart filter logic
                final filteredList = dossiers.where((d) {
                  final customerCases = allCases.where((c) => c.dossierId == d.id).toList();
                  switch (activeFilter) {
                    case DossierFilterCategory.all:
                      return true;
                    case DossierFilterCategory.activeJobs:
                      return customerCases.any((c) => c.stage != 'COMPLETED');
                    case DossierFilterCategory.pendingDocs:
                      return customerCases.any((c) => c.stage == 'DOCS_NEEDED' || c.stage == 'INTAKE');
                    case DossierFilterCategory.unpaidDues:
                      return customerCases.any((c) => (c.totalEstimatedAmount - c.advancePaid) > 0);
                  }
                }).toList();

                if (filteredList.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded, size: 36, color: Colors.grey[500]),
                          const SizedBox(height: 8),
                          Text(
                            activeFilter == DossierFilterCategory.all
                                ? 'No customers found'
                                : 'No matching dossiers for ${activeFilter.label}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filteredList.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  separatorBuilder: (context, _) =>
                      Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                  itemBuilder: (context, index) {
                    final d = filteredList[index];
                    final isSelected = activeDossier?.id == d.id;
                    final customerCases = allCases.where((c) => c.dossierId == d.id).toList();

                    // Urgency ring logic
                    final hasPendingDocs = customerCases.any((c) => c.stage == 'DOCS_NEEDED');
                    final isReadyForPickup = customerCases.any((c) => c.stage == 'READY_FOR_PICKUP');
                    final totalDues = customerCases.fold<double>(
                      0.0,
                      (sum, c) => sum + (c.totalEstimatedAmount - c.advancePaid).clamp(0.0, double.infinity),
                    );

                    Color ringColor = Colors.transparent;
                    if (hasPendingDocs) {
                      ringColor = const Color(0xFFF59E0B); // Amber
                    } else if (isReadyForPickup) {
                      ringColor = const Color(0xFF10B981); // Emerald
                    }

                    return Material(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.1)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          ref.read(activeDossierIdProvider.notifier).state = d.id;
                          ref.read(activeCaseIdProvider.notifier).state = null; // reset case selection
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar with Urgency Ring
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ringColor != Colors.transparent ? ringColor : Colors.transparent,
                                    width: ringColor != Colors.transparent ? 2.2 : 0,
                                  ),
                                ),
                                padding: EdgeInsets.all(ringColor != Colors.transparent ? 2 : 0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
                                        : null,
                                    color: isSelected
                                        ? null
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            d.fullName,
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                              fontSize: 13.5,
                                              color: isSelected ? Theme.of(context).colorScheme.primary : null,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (totalDues > 0)
                                          Container(
                                            margin: const EdgeInsets.only(left: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Due ₹${totalDues.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFFEF4444),
                                                fontFeatures: AppThemes.tabularFigures,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 11, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            d.phoneNumber,
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 11.5,
                                              fontFeatures: AppThemes.tabularFigures,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (hasPendingDocs)
                                          const Text(
                                            'Docs Req.',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFFF59E0B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )
                                        else if (isReadyForPickup)
                                          const Text(
                                            'Ready',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF10B981),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.chevron_right_rounded,
                                    color: Theme.of(context).colorScheme.primary, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
            ),
          ),
        ],
      ),
    );
  }
}
