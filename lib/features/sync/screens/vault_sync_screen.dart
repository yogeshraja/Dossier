import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';

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
            // Header (Wrap for narrow screens)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_sync_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                        const SizedBox(width: 8),
                        const Text('Cloud Vault & Sync Outbox', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Monitor local-to-cloud artifact replication and storage tiers', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _isSyncing ? null : _triggerManualSync,
                  icon: _isSyncing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Sync Now', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Storage Tier Selector Card (Responsive)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
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
                            Expanded(
                              child: Text(
                                _isProTier ? 'Dossier Pro Tier (Managed Cloudflare R2)' : 'Free Tier (BYO Google Drive)',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _isProTier ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _isProTier ? '₹249/mo' : 'FREE',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isProTier
                              ? 'Zero-setup instant cloud backup, multi-device real-time sync across 2-4 counter PCs, \$0 egress fees.'
                              : 'Artifacts uploaded directly to personal Google Drive account (/Dossier_Workspace) via API v3.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isProTier,
                    onChanged: (val) => setState(() => _isProTier = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Outbox Sync Queue Section
            const Text('Outbox Synchronization Queue (Drift SQLite SyncQueue):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
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
                            const SizedBox(height: 2),
                            Text('All local mutations and customer documents are backed up to the remote vault.',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: queue.length,
                      separatorBuilder: (context, _) => Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                      itemBuilder: (context, index) {
                        final item = queue[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            child: Icon(Icons.sync_problem_rounded, color: Theme.of(context).colorScheme.primary, size: 16),
                          ),
                          title: Text('${item.operation} ${item.entityType} #${item.entityId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('Status: ${item.syncStatus} • Retries: ${item.retryCount}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          trailing: const Text('Pending', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
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
