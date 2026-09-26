import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final activeDossier = ref.watch(activeDossierProvider);
    final searchQuery = ref.watch(dossierSearchQueryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),

          // Customer List
          Expanded(
            child: dossiersAsync.when(
              data: (dossiers) {
                if (dossiers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded, size: 36, color: Colors.grey[500]),
                          const SizedBox(height: 8),
                          Text('No customers found', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: dossiers.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  separatorBuilder: (context, _) => Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                  itemBuilder: (context, index) {
                    final d = dossiers[index];
                    final isSelected = activeDossier?.id == d.id;

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
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
                                      : null,
                                  color: isSelected ? null : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.fullName,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 13.5,
                                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 11, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            d.phoneNumber,
                                            style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
            ),
          ),
        ],
      ),
    );
  }
}
