import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/app/theme.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/sync/providers/sync_provider.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/presentation/common_widgets/dossier_dialog.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';

/// Ambient hardware & cloud sync status pill for kiosk workstations.
/// Displays live cloud engine connection, outbox queue count, and ESC/POS thermal printer readiness.
class KioskStatusBar extends ConsumerWidget {
  final bool compact;
  final VoidCallback? onOpenSync;

  const KioskStatusBar({
    super.key,
    this.compact = false,
    this.onOpenSync,
  });

  void _showDiagnostics(BuildContext context, WidgetRef ref) {
    final syncState = ref.read(syncProvider);
    final pendingSync = ref.read(pendingSyncQueueStreamProvider).asData?.value ?? [];
    final settings = ref.read(kioskSettingsProvider);

    showDialog(
      context: context,
      builder: (ctx) => DossierDialog(
        title: 'Kiosk Hardware & Vault Diagnostics',
        icon: Icons.monitor_heart_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cloud Sync Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        syncState.isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: syncState.isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Cloud Vault Engine',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (syncState.isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          syncState.isConnected ? 'CONNECTED' : 'STANDBY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: syncState.isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Engine: ${syncState.activeTier.label}', style: const TextStyle(fontSize: 12)),
                  if (syncState.userEmail != null)
                    Text('Account: ${syncState.userEmail}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  Text('Pending Outbox Queue: ${pendingSync.length} items',
                      style: TextStyle(
                        fontSize: 11,
                        color: pendingSync.isEmpty ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Hardware ESC/POS Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.print_rounded, color: Color(0xFF6366F1), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'ESC/POS Thermal Printer',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DRIVER READY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Protocol: ESC/POS Direct Byte Buffer (58mm / 80mm)', style: TextStyle(fontSize: 12)),
                  Text('Store Header: ${settings.kioskName}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  Text('UPI Merchant: ${settings.merchantUpiVpa.isNotEmpty ? settings.merchantUpiVpa : 'Not configured'}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ],
              ),
            ),
          ],
        ),
        actions: [
          DossierButton(
            text: 'Trigger Sync',
            icon: Icons.sync_rounded,
            size: DossierButtonSize.sm,
            variant: DossierButtonVariant.secondary,
            isLoading: syncState.isSyncing,
            onPressed: () {
              ref.read(syncProvider.notifier).triggerSync();
              Navigator.of(ctx).pop();
            },
          ),
          DossierButton(
            text: 'Close',
            variant: DossierButtonVariant.outline,
            size: DossierButtonSize.sm,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final pendingSync = ref.watch(pendingSyncQueueStreamProvider).asData?.value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final syncColor = syncState.isSyncing
        ? const Color(0xFF6366F1)
        : (syncState.isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    final syncLabel = syncState.isSyncing
        ? 'Syncing...'
        : (syncState.isConnected ? 'Cloud Synced' : 'Offline Vault');

    if (compact) {
      return Tooltip(
        message: 'Diagnostics & Status: $syncLabel | ${pendingSync.length} queued',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDiagnostics(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: syncColor.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: syncColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (syncState.isSyncing)
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 2, color: syncColor),
                  )
                else
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: syncColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (pendingSync.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Text(
                    '${pendingSync.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: syncColor,
                      fontFeatures: AppThemes.tabularFigures,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Click for Hardware & Cloud Vault diagnostics',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDiagnostics(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cloud Sync Indicator
                if (syncState.isSyncing)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: syncColor),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: syncColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: syncColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 7),
                Text(
                  syncLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),

                // Pending Outbox Pill (if any)
                if (pendingSync.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${pendingSync.length} queued',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF59E0B),
                        fontFeatures: AppThemes.tabularFigures,
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 12,
                  color: Theme.of(context).dividerColor,
                ),
                const SizedBox(width: 8),

                // ESC/POS Ready icon
                const Icon(Icons.print_rounded, size: 13, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text(
                  'POS 58/80',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
