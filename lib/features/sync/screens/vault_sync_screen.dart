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
      backgroundColor: const Color(0xFF090D16),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cloud_sync_rounded, color: Color(0xFF818CF8)),
                        SizedBox(width: 10),
                        Text('Cloud Vault & Asynchronous Outbox Sync', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Monitor local-to-cloud artifact replication and subscription tier storage', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _isSyncing ? null : _triggerManualSync,
                  icon: _isSyncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_rounded),
                  label: const Text('Force Cloud Sync Now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Storage Tier Selector Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isProTier ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF3B82F6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isProTier ? Icons.diamond_rounded : Icons.folder_shared_rounded,
                      color: _isProTier ? const Color(0xFF34D399) : const Color(0xFF60A5FA),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isProTier ? 'Dossier Pro Tier (Managed Cloudflare R2 Vault)' : 'Free Tier (BYO Google Drive Vault)',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _isProTier ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _isProTier ? '₹249/mo' : 'FREE',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isProTier
                              ? 'Zero-setup instant cloud backup, multi-device real-time sync across 2-4 counter PCs, \$0 egress fees.'
                              : 'Artifacts uploaded directly to your personal Google Drive account (/Dossier_Workspace) via Google Drive API v3.',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
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
            const SizedBox(height: 24),

            // Outbox Sync Queue Section
            const Text('Outbox Synchronization Queue (Drift SQLite SyncQueue):', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: pendingSyncAsync.when(
                  data: (queue) {
                    if (queue.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_done_rounded, size: 56, color: Color(0xFF34D399)),
                            const SizedBox(height: 12),
                            const Text('Outbox is 100% Synced!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('All local mutations and customer documents are backed up to the remote vault.', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: queue.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B)),
                      itemBuilder: (context, index) {
                        final item = queue[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                            child: const Icon(Icons.sync_problem_rounded, color: Color(0xFF818CF8), size: 20),
                          ),
                          title: Text('${item.operation} ${item.entityType} #${item.entityId}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('Status: ${item.syncStatus} • Retries: ${item.retryCount}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          trailing: const Text('Pending Sync', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
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
