import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/dossiers/widgets/new_dossier_dialog.dart';

class DossierListPane extends ConsumerWidget {
  final double? width;
  const DossierListPane({super.key, this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossiersAsync = ref.watch(dossiersStreamProvider);
    final activeDossier = ref.watch(activeDossierProvider);
    final searchQuery = ref.watch(dossierSearchQueryProvider);

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
                    const Text(
                      'Dossiers',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    IconButton.filledTonal(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const NewDossierDialog(),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      tooltip: 'New Customer',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (val) => ref.read(dossierSearchQueryProvider.notifier).state = val,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search phone or name...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => ref.read(dossierSearchQueryProvider.notifier).state = '',
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                if (dossiers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 36, color: Colors.grey[500]),
                          const SizedBox(height: 8),
                          Text('No customers found', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: dossiers.length,
                  separatorBuilder: (context, _) => Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                  itemBuilder: (context, index) {
                    final d = dossiers[index];
                    final isSelected = activeDossier?.id == d.id;

                    return InkWell(
                      onTap: () {
                        ref.read(activeDossierIdProvider.notifier).state = d.id;
                        ref.read(activeCaseIdProvider.notifier).state = null; // reset case selection
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                              child: Text(
                                d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 13,
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
                                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
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
                              Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.primary, size: 16),
                          ],
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
