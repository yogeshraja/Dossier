import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/sync/providers/sync_provider.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';
import 'package:dossier/presentation/common_widgets/dossier_panel.dart';

class VaultSyncScreen extends ConsumerStatefulWidget {
  const VaultSyncScreen({super.key});

  @override
  ConsumerState<VaultSyncScreen> createState() => _VaultSyncScreenState();
}

class _VaultSyncScreenState extends ConsumerState<VaultSyncScreen> {
  bool _isProTier = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final syncState = ref.read(syncProvider);
      if (!syncState.isConnected) {
        ref.read(syncProvider.notifier).connectGoogleDrive(forceMock: true);
      }
    });
  }

  Future<void> _openGoogleDriveFolder() async {
    final syncState = ref.read(syncProvider);
    final url = Uri.parse('https://drive.google.com/drive/u/0/my-drive');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening Google Drive: /Dossier_Workspace (${syncState.userEmail ?? "Connected Account"})'),
            backgroundColor: const Color(0xFF6366F1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final pendingSyncAsync = ref.watch(pendingSyncQueueStreamProvider);
    final syncState = ref.watch(syncProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
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
                            child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    const Text(
                                      'Cloud Vault & Sync',
                                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                    ),
                                    DossierBadge(
                                      label: syncState.isConnected ? (syncState.isMockMode ? 'MOCK CONNECTED' : 'CONNECTED') : 'OFFLINE',
                                      variant: syncState.isConnected ? DossierBadgeVariant.success : DossierBadgeVariant.warning,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Google Drive Cloud Storage (/Dossier_Workspace)',
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
                      text: syncState.isSyncing ? 'Syncing...' : 'Sync Now',
                      icon: Icons.sync_rounded,
                      isLoading: syncState.isSyncing,
                      size: isNarrow ? DossierButtonSize.sm : DossierButtonSize.md,
                      variant: DossierButtonVariant.primary,
                      tooltip: 'Push all local pending documents and case changes to Google Drive',
                      onPressed: syncState.isSyncing ? null : () => ref.read(syncProvider.notifier).triggerSync(),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Live Sync Progress Bar (Active when syncing)
            if (syncState.isSyncing || syncState.currentTask != null) ...[
              DossierCard(
                variant: DossierCardVariant.glass,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  syncState.currentTask ?? 'Synchronizing with Google Drive...',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(syncState.progress * 100).toInt()}%',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: syncState.progress > 0 ? syncState.progress : null,
                        minHeight: 6,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Google Drive Connected Account Card
            DossierCard(
              variant: DossierCardVariant.glass,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add_to_drive_rounded, color: Color(0xFF4285F4), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    children: [
                                      const Text(
                                        'Google Drive Storage',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                      ),
                                      if (syncState.isConnected)
                                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    syncState.isConnected
                                        ? 'Connected: ${syncState.userEmail ?? "kiosk.operator@csc-dossier.org"}'
                                        : 'Connect Google account to sync documents',
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (syncState.isConnected) ...[
                            DossierButton(
                              text: 'Open in Drive',
                              icon: Icons.open_in_new_rounded,
                              size: DossierButtonSize.sm,
                              variant: DossierButtonVariant.outline,
                              tooltip: 'Open the /Dossier_Workspace folder in your browser',
                              onPressed: _openGoogleDriveFolder,
                            ),
                            DossierButton(
                              text: 'Disconnect',
                              size: DossierButtonSize.sm,
                              variant: DossierButtonVariant.danger,
                              tooltip: 'Disconnect current Google account session',
                              onPressed: () => ref.read(syncProvider.notifier).disconnectGoogleDrive(),
                            ),
                          ] else ...[
                            DossierButton(
                              text: 'Connect Google Drive',
                              icon: Icons.login_rounded,
                              size: DossierButtonSize.sm,
                              variant: DossierButtonVariant.primary,
                              tooltip: 'Sign in with Google OAuth2 to sync documents',
                              onPressed: () => ref.read(syncProvider.notifier).connectGoogleDrive(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _buildDetailBadge('Root Directory', '/Dossier_Workspace', Icons.folder_open_rounded),
                      _buildDetailBadge('Last Sync', syncState.lastSyncedAt != null ? '${syncState.lastSyncedAt!.hour.toString().padLeft(2, '0')}:${syncState.lastSyncedAt!.minute.toString().padLeft(2, '0')}' : 'Never', Icons.access_time_rounded),
                      _buildDetailBadge('Sync Protocol', 'Resilient SQLite Outbox', Icons.offline_pin_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Storage Tier Plan Selector Card
            DossierCard(
              variant: DossierCardVariant.outlined,
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
                      size: 24,
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
                                _isProTier ? 'Dossier Pro (Managed Cloudflare R2 Vault)' : 'Free Tier (Bring Your Own Google Drive)',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            DossierBadge(
                              label: _isProTier ? 'R2 ACTIVE' : 'DRIVE ACTIVE',
                              variant: _isProTier ? DossierBadgeVariant.success : DossierBadgeVariant.info,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isProTier
                              ? 'Instant zero-setup cloud backup via Cloudflare R2, multi-device counter PC sync, \$0 egress fees.'
                              : 'Artifacts uploaded directly to personal Google Drive account (/Dossier_Workspace) via official Drive API v3.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isProTier,
                    onChanged: (val) {
                      setState(() => _isProTier = val);
                      ref.read(syncProvider.notifier).setStorageTier(
                            val ? StorageTierType.managedR2 : StorageTierType.byoGoogleDrive,
                          );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Air-Gapped Disaster Recovery & Database Backup
            DossierCard(
              variant: DossierCardVariant.outlined,
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.security_rounded, color: Color(0xFFF59E0B), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Air-Gapped Backup & Restore',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Export full SQLite snapshot to USB or restore disaster recovery bundle (.dossier)',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          DossierButton(
                            text: 'Export Backup (.dossier)',
                            icon: Icons.download_rounded,
                            size: DossierButtonSize.sm,
                            variant: DossierButtonVariant.outline,
                            tooltip: 'Export complete database snapshot to encrypted .dossier JSON bundle',
                            onPressed: () async {
                              final backupService = ref.read(backupRestoreServiceProvider);
                              final bundle = await backupService.createBackup();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF10B981),
                                    content: Text('Database backup created successfully! (${bundle.totalDossiers} dossiers, ${bundle.totalCases} cases, ${bundle.totalInvoices} invoices)'),
                                  ),
                                );
                              }
                            },
                          ),
                          DossierButton(
                            text: 'Restore Backup',
                            icon: Icons.restore_rounded,
                            size: DossierButtonSize.sm,
                            variant: DossierButtonVariant.secondary,
                            tooltip: 'Restore customer dossiers and cases from an existing .dossier bundle',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Select .dossier backup bundle from storage to restore.')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Outbox Synchronization Queue
            DossierPanel(
              title: 'SQLite Outbox Sync Queue',
              subtitle: 'Pending mutations waiting for background upload',
              leading: const Icon(Icons.outbox_rounded, size: 18, color: Color(0xFF6366F1)),
              badge: pendingSyncAsync.maybeWhen(
                data: (queue) => DossierBadge(
                  label: '${queue.length} PENDING',
                  variant: queue.isEmpty ? DossierBadgeVariant.success : DossierBadgeVariant.warning,
                ),
                orElse: () => null,
              ),
              actions: [
                DossierButton(
                  text: 'Flush & Sync',
                  icon: Icons.sync_rounded,
                  size: DossierButtonSize.sm,
                  variant: DossierButtonVariant.outline,
                  isLoading: syncState.isSyncing,
                  tooltip: 'Immediately process and upload all pending queue items',
                  onPressed: syncState.isSyncing ? null : () => ref.read(syncProvider.notifier).triggerSync(),
                ),
              ],
              child: pendingSyncAsync.when(
                data: (queue) {
                  if (queue.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_done_rounded, size: 44, color: Color(0xFF10B981)),
                          const SizedBox(height: 10),
                          const Text('Outbox is 100% Synchronized!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            'All customer dossiers, cases, and scanned exhibits are backed up to Google Drive.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: queue.length,
                    separatorBuilder: (context, _) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          child: Icon(
                            item.entityType == 'EXHIBIT' ? Icons.attach_file_rounded : (item.entityType == 'CASE' ? Icons.folder_rounded : Icons.person_rounded),
                            color: Theme.of(context).colorScheme.primary,
                            size: 15,
                          ),
                        ),
                        title: Text(
                          '${item.operation} ${item.entityType} #${item.entityId.substring(0, item.entityId.length.clamp(0, 8)).toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        subtitle: Text(
                          'Status: ${item.syncStatus} • Retries: ${item.retryCount} • Scheduled: ${item.scheduledAt.hour.toString().padLeft(2, '0')}:${item.scheduledAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                        trailing: DossierBadge(
                          label: item.syncStatus,
                          variant: item.syncStatus == 'SUCCESS'
                              ? DossierBadgeVariant.success
                              : (item.syncStatus == 'PROCESSING' ? DossierBadgeVariant.primary : DossierBadgeVariant.warning),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading sync queue: $err')),
              ),
            ),
            const SizedBox(height: 18),

            // Live Sync Activity Console
            if (syncState.logs.isNotEmpty) ...[
              DossierPanel(
                title: 'Live Sync Activity Log',
                subtitle: 'Real-time audit log of file uploads and folder creations',
                leading: const Icon(Icons.terminal_rounded, size: 18, color: Color(0xFF10B981)),
                isCollapsible: true,
                initiallyExpanded: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: syncState.logs.take(8).map((log) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('› ', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            Expanded(
                              child: Text(
                                log,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBadge(String label, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
