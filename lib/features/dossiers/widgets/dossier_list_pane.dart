import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/dossiers/widgets/new_dossier_dialog.dart';

class DossierListPane extends ConsumerWidget {
  const DossierListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossiersAsync = ref.watch(dossiersStreamProvider);
    final activeDossier = ref.watch(activeDossierProvider);
    final searchQuery = ref.watch(dossierSearchQueryProvider);

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(right: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: Column(
        children: [
          // Header & Search
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dossiers',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                        foregroundColor: const Color(0xFF818CF8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (val) => ref.read(dossierSearchQueryProvider.notifier).state = val,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search phone or name...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                            onPressed: () => ref.read(dossierSearchQueryProvider.notifier).state = '',
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),

          // Customer List
          Expanded(
            child: dossiersAsync.when(
              data: (dossiers) {
                if (dossiers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 40, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text('No customers found', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: dossiers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1E293B)),
                  itemBuilder: (context, index) {
                    final d = dossiers[index];
                    final isSelected = activeDossier?.id == d.id;

                    return InkWell(
                      onTap: () {
                        ref.read(activeDossierIdProvider.notifier).state = d.id;
                        ref.read(activeCaseIdProvider.notifier).state = null; // reset case selection
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: isSelected ? const Color(0xFF6366F1).withOpacity(0.18) : Colors.transparent,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
                              child: Text(
                                d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.fullName,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        d.phoneNumber,
                                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFF818CF8), size: 18),
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
