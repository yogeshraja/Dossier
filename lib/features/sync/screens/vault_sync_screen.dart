import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';

class VaultSyncScreen extends ConsumerStatefulWidget {
  const VaultSyncScreen({super.key});

  @override
  ConsumerState<VaultSyncScreen> createState() => _VaultSyncScreenState();
}

class _VaultSyncScreenState extends ConsumerState<VaultSyncScreen> {
  bool _isProTier = false;
  bool _isSyncing = false;

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All local exhibits synchronized with cloud vault successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingSyncAsync = ref.watch(pendingSyncQueueStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive Header
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 600;

                if (isCompact) {
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Cloud Vault & Sync',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DossierButton(
                        text: 'Sync',
                        icon: Icons.sync_rounded,
                        isLoading: _isSyncing,
                        size: DossierButtonSize.sm,
                        variant: DossierButtonVariant.primary,
                        onPressed: _isSyncing ? null : _triggerManualSync,
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
                      child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cloud Vault & Sync Outbox', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          SizedBox(height: 2),
                          Text('Monitor local-to-cloud replication and storage tiers', style: TextStyle(color: Colors.grey, fontSize: 11.5), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    DossierButton(
                      text: 'Sync Now',
                      icon: Icons.sync_rounded,
                      isLoading: _isSyncing,
                      size: DossierButtonSize.sm,
                      variant: DossierButtonVariant.primary,
                      onPressed: _isSyncing ? null : _triggerManualSync,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Storage Tier Selector Card
            DossierCard(
              variant: DossierCardVariant.glass,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isProTier ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isProTier ? Icons.diamond_rounded : Icons.folder_shared_rounded,
                      color: _isProTier ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _isProTier ? 'Dossier Pro (Managed Cloudflare R2)' : 'Free Tier (BYO Google Drive)',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            DossierBadge(
                              text: _isProTier ? '₹249/mo' : 'FREE',
                              variant: _isProTier ? DossierBadgeVariant.success : DossierBadgeVariant.info,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isProTier
                              ? 'Zero-setup instant cloud backup, multi-device real-time sync across 2-4 counter PCs, \$0 egress fees.'
                              : 'Artifacts uploaded directly to personal Google Drive account (/Dossier_Workspace) via API v3.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isProTier,
                    onChanged: (val) => setState(() => _isProTier = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Outbox Sync Queue Section
            const Text('Outbox Synchronization Queue (Drift SQLite SyncQueue):', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Expanded(
              child: DossierCard(
                variant: DossierCardVariant.outlined,
                padding: const EdgeInsets.all(12),
                child: pendingSyncAsync.when(
                  data: (queue) {
                    if (queue.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_done_rounded, size: 48, color: Color(0xFF10B981)),
                            const SizedBox(height: 10),
                            const Text('Outbox is 100% Synced!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                              'All local mutations and customer documents are securely synchronized.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: queue.length,
                      separatorBuilder: (context, _) => Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                      itemBuilder: (context, index) {
                        final item = queue[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            child: Icon(Icons.sync_problem_rounded, color: Theme.of(context).colorScheme.primary, size: 16),
                          ),
                          title: Text('${item.operation} ${item.entityType} #${item.entityId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('Status: ${item.syncStatus} • Retries: ${item.retryCount}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          trailing: const DossierBadge(text: 'Pending', variant: DossierBadgeVariant.warning),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading queue: $err')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
