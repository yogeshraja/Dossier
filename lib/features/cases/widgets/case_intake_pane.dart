import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dossier/data/local/app_database.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/features/cases/widgets/new_case_dialog.dart';
import 'package:uuid/uuid.dart';

class CaseIntakePane extends ConsumerWidget {
  const CaseIntakePane({super.key});

  static const _stages = [
    {'key': 'DRAFT', 'label': 'Draft', 'icon': Icons.edit_note_rounded},
    {'key': 'DOCS_PENDING', 'label': 'Docs Pending', 'icon': Icons.pending_actions_rounded},
    {'key': 'READY_TO_APPLY', 'label': 'Ready to Apply', 'icon': Icons.fact_check_rounded},
    {'key': 'SUBMITTED', 'label': 'Submitted', 'icon': Icons.cloud_upload_rounded},
    {'key': 'READY_FOR_PICKUP', 'label': 'Ready for Pickup', 'icon': Icons.assignment_turned_in_rounded},
    {'key': 'CLOSED', 'label': 'Closed', 'icon': Icons.check_circle_rounded},
  ];

  Color _getStageColor(String stage) {
    switch (stage) {
      case 'DRAFT':
        return Colors.grey;
      case 'DOCS_PENDING':
        return Colors.orangeAccent;
      case 'READY_TO_APPLY':
        return Colors.cyan;
      case 'SUBMITTED':
        return Colors.blueAccent;
      case 'READY_FOR_PICKUP':
        return const Color(0xFF10B981);
      case 'CLOSED':
        return const Color(0xFF6366F1);
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateStage(WidgetRef ref, String caseId, String newStage) async {
    final db = ref.read(databaseProvider);
    await db.updateCaseStage(caseId, newStage);
  }

  Future<void> _addSimulatedExhibit(WidgetRef ref, String caseId, String slotType) async {
    final db = ref.read(databaseProvider);
    const uuid = Uuid();
    final fileName = '${slotType}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await db.insertExhibit(
      ExhibitsCompanion.insert(
        id: uuid.v4(),
        caseId: caseId,
        slotType: slotType,
        fileName: fileName,
        mimeType: 'image/jpeg',
        fileSizeBytes: 145000, // 145 KB
        localPath: drift.Value('/storage/emulated/0/Dossier/$fileName'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDossier = ref.watch(activeDossierProvider);
    final activeCasesAsync = ref.watch(activeCasesStreamProvider);
    final activeCase = ref.watch(activeCaseProvider);
    final exhibitsAsync = ref.watch(activeCaseExhibitsStreamProvider);
    final isBillingExpanded = ref.watch(isBillingHubExpandedProvider);
    final settings = ref.watch(kioskSettingsProvider);

    if (activeDossier == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Select a customer dossier from the directory to view cases', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Customer Profile Banner (Wrap / Adaptive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        activeDossier.fullName.isNotEmpty ? activeDossier.fullName[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              activeDossier.fullName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        Text(
                          'Phone: ${activeDossier.phoneNumber}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => NewCaseDialog(customer: activeDossier),
                        );
                      },
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('New Case Intake', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                    if (!isBillingExpanded) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () => ref.read(isBillingHubExpandedProvider.notifier).state = true,
                        icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                        tooltip: 'Expand Billing & QR Hub',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Main Cases Workspace
          Expanded(
            child: activeCasesAsync.when(
              data: (cases) {
                if (cases.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey[500]),
                          const SizedBox(height: 10),
                          const Text('No active cases for this customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Tap "New Case Intake" above to start a service application', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }

                // Horizontal Case Tabs
                return Column(
                  children: [
                    Container(
                      height: 44,
                      color: Theme.of(context).colorScheme.surface,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: cases.length,
                        separatorBuilder: (context, _) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final c = cases[index];
                          final isSelected = activeCase?.id == c.id;

                          return ChoiceChip(
                            label: Text(c.title, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.grey[500])),
                            selected: isSelected,
                            onSelected: (_) => ref.read(activeCaseIdProvider.notifier).state = c.id,
                            selectedColor: Theme.of(context).colorScheme.primary,
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor),
                          );
                        },
                      ),
                    ),
                    Divider(height: 1, color: Theme.of(context).dividerColor),

                    // Active Case Details & Stepper
                    if (activeCase != null)
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Stage Lifecycle Stepper
                              const Text('Lifecycle Stage Progression:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _stages.map((st) {
                                    final isCurrent = activeCase.stage == st['key'];
                                    final isPassed = _stages.indexWhere((s) => s['key'] == activeCase.stage) >= _stages.indexOf(st);
                                    final stageColor = _getStageColor(st['key'] as String);

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6.0),
                                      child: ActionChip(
                                        avatar: Icon(
                                          st['icon'] as IconData,
                                          size: 14,
                                          color: isCurrent ? Colors.white : (isPassed ? stageColor : Colors.grey),
                                        ),
                                        label: Text(
                                          st['label'] as String,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                            color: isCurrent ? Colors.white : (isPassed ? stageColor : Colors.grey),
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: isCurrent ? stageColor.withValues(alpha: 0.8) : Theme.of(context).cardTheme.color,
                                        side: BorderSide(color: isCurrent ? stageColor : Theme.of(context).dividerColor),
                                        onPressed: () => _updateStage(ref, activeCase.id, st['key'] as String),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Financial Overview Card (Responsive Wrap / Grid)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardTheme.color,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Theme.of(context).dividerColor),
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.spaceAround,
                                  runAlignment: WrapAlignment.center,
                                  spacing: 16,
                                  runSpacing: 12,
                                  children: [
                                    _buildStatItem('Govt Portal Cost', '${settings.currencySymbol}${activeCase.totalPortalFee.toStringAsFixed(0)}', Colors.grey[500]!),
                                    _buildStatItem('Kiosk Profit', '${settings.currencySymbol}${activeCase.totalServiceFee.toStringAsFixed(0)}', Theme.of(context).colorScheme.primary),
                                    _buildStatItem('Total Estimate', '${settings.currencySymbol}${activeCase.totalEstimatedAmount.toStringAsFixed(0)}', Theme.of(context).colorScheme.onSurface),
                                    _buildStatItem('Advance Paid', '${settings.currencySymbol}${activeCase.advancePaid.toStringAsFixed(0)}', const Color(0xFF10B981)),
                                    _buildStatItem(
                                      'Balance Due',
                                      '${settings.currencySymbol}${(activeCase.totalEstimatedAmount - activeCase.advancePaid).clamp(0, 99999).toStringAsFixed(0)}',
                                      Colors.amber,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Document Exhibits Slot Manager
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Case Exhibits & Artifacts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  TextButton.icon(
                                    onPressed: () => _addSimulatedExhibit(ref, activeCase.id, 'ATTACHMENT'),
                                    icon: const Icon(Icons.attach_file, size: 14),
                                    label: const Text('Attach Scanned Doc', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              exhibitsAsync.when(
                                data: (exhibits) {
                                  if (exhibits.isEmpty) {
                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Theme.of(context).dividerColor),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey[500]),
                                          const SizedBox(height: 6),
                                          const Text('No exhibits attached yet', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () => _addSimulatedExhibit(ref, activeCase.id, 'AADHAAR_FRONT'),
                                                icon: const Icon(Icons.badge, size: 12),
                                                label: const Text('+ Aadhaar Front', style: TextStyle(fontSize: 11)),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () => _addSimulatedExhibit(ref, activeCase.id, 'PASSPORT_PHOTO'),
                                                icon: const Icon(Icons.photo, size: 12),
                                                label: const Text('+ Photo', style: TextStyle(fontSize: 11)),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () => _addSimulatedExhibit(ref, activeCase.id, 'SIGNATURE'),
                                                icon: const Icon(Icons.draw, size: 12),
                                                label: const Text('+ Sign', style: TextStyle(fontSize: 11)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: exhibits.length,
                                    separatorBuilder: (context, _) => const SizedBox(height: 6),
                                    itemBuilder: (context, index) {
                                      final ex = exhibits[index];
                                      return Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardTheme.color,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Theme.of(context).dividerColor),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(Icons.image_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(ex.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  Text(
                                                    '${ex.slotType} • ${(ex.fileSizeBytes / 1024).toStringAsFixed(0)} KB',
                                                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('READY', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (err, _) => Text('Error loading exhibits: $err'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading cases: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}
