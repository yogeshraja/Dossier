import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/remote/gdrive/google_drive_vault_service.dart';
import 'package:dossier/data/remote/r2/managed_r2_vault_service.dart';
import 'package:dossier/domain/services/vault_storage_service.dart';
import 'package:dossier/domain/services/backup_restore_service.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';

enum StorageTierType {
  byoGoogleDrive('BYO Google Drive (Free / User Quota)'),
  managedR2('Managed Cloudflare R2 Cloud Vault'),
  airGappedLocal('Local Air-Gapped Kiosk (Offline)');

  final String label;
  const StorageTierType(this.label);
}

final googleDriveServiceProvider = Provider<GoogleDriveVaultService>((ref) {
  return GoogleDriveVaultService();
});

final managedR2ServiceProvider = Provider<ManagedR2VaultService>((ref) {
  return ManagedR2VaultService();
});

final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  final db = ref.watch(databaseProvider);
  return BackupRestoreService(db);
});

class SyncState {
  final StorageTierType activeTier;
  final bool isConnected;
  final bool isSyncing;
  final bool isMockMode;
  final String? userEmail;
  final String? userName;
  final double progress;
  final String? currentTask;
  final DateTime? lastSyncedAt;
  final int syncedCount;
  final int failedCount;
  final List<String> logs;

  const SyncState({
    this.activeTier = StorageTierType.byoGoogleDrive,
    this.isConnected = false,
    this.isSyncing = false,
    this.isMockMode = false,
    this.userEmail,
    this.userName,
    this.progress = 0.0,
    this.currentTask,
    this.lastSyncedAt,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.logs = const [],
  });

  SyncState copyWith({
    StorageTierType? activeTier,
    bool? isConnected,
    bool? isSyncing,
    bool? isMockMode,
    String? userEmail,
    String? userName,
    double? progress,
    String? currentTask,
    DateTime? lastSyncedAt,
    int? syncedCount,
    int? failedCount,
    List<String>? logs,
  }) {
    return SyncState(
      activeTier: activeTier ?? this.activeTier,
      isConnected: isConnected ?? this.isConnected,
      isSyncing: isSyncing ?? this.isSyncing,
      isMockMode: isMockMode ?? this.isMockMode,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      progress: progress ?? this.progress,
      currentTask: currentTask ?? this.currentTask,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncedCount: syncedCount ?? this.syncedCount,
      failedCount: failedCount ?? this.failedCount,
      logs: logs ?? this.logs,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  final GoogleDriveVaultService _gdrive;
  final ManagedR2VaultService _r2;

  SyncNotifier(this._ref, this._gdrive, this._r2) : super(const SyncState());

  void setStorageTier(StorageTierType tier) {
    state = state.copyWith(
      activeTier: tier,
      logs: [
        '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} - Active storage engine set to ${tier.label}',
        ...state.logs,
      ],
    );
  }

  Future<bool> connectGoogleDrive({bool forceMock = false}) async {
    state = state.copyWith(currentTask: 'Connecting to Google Drive...');
    final success = await _gdrive.authenticate(forceMock: forceMock);
    if (success) {
      state = state.copyWith(
        isConnected: true,
        isMockMode: _gdrive.isMockMode,
        userEmail: _gdrive.connectedUserEmail,
        userName: _gdrive.connectedUserName,
        currentTask: null,
        logs: [
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} - Connected to Google Drive (${_gdrive.connectedUserEmail})',
          ...state.logs,
        ],
      );
    } else {
      state = state.copyWith(
        isConnected: false,
        currentTask: null,
      );
    }
    return success;
  }

  Future<void> disconnectGoogleDrive() async {
    await _gdrive.signOut();
    state = state.copyWith(
      isConnected: false,
      userEmail: null,
      userName: null,
      currentTask: null,
      logs: [
        '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} - Disconnected from Google Drive',
        ...state.logs,
      ],
    );
  }

  VaultStorageService _getActiveStorageService() {
    if (state.activeTier == StorageTierType.managedR2) {
      return _r2;
    }
    return _gdrive;
  }

  Future<void> scanAndQueueUnsynced() async {
    final db = _ref.read(databaseProvider);
    final count = await db.enqueueAllUnsynced();
    if (count > 0) {
      state = state.copyWith(
        logs: [
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} - Queued $count pending local items for cloud sync',
          ...state.logs,
        ],
      );
    }
  }

  Future<void> triggerSync() async {
    if (state.isSyncing) return;

    if (state.activeTier == StorageTierType.airGappedLocal) {
      state = state.copyWith(
        logs: [
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} - Sync skipped (Air-Gapped Local Mode active)',
          ...state.logs,
        ],
      );
      return;
    }

    if (state.activeTier == StorageTierType.byoGoogleDrive && !state.isConnected) {
      final connected = await connectGoogleDrive();
      if (!connected) return;
    }

    state = state.copyWith(isSyncing: true, progress: 0.0, currentTask: 'Scanning pending sync outbox...');

    final db = _ref.read(databaseProvider);
    await db.enqueueAllUnsynced();
    final pendingItems = await db.getPendingSyncItems();
    final vaultService = _getActiveStorageService();

    if (pendingItems.isEmpty) {
      state = state.copyWith(
        isSyncing: false,
        progress: 1.0,
        currentTask: null,
        lastSyncedAt: DateTime.now(),
        logs: [
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} - Cloud Vault is up to date (0 pending items)',
          ...state.logs,
        ],
      );
      return;
    }

    int successCount = 0;
    int failedCount = 0;
    final newLogs = <String>[];

    for (int i = 0; i < pendingItems.length; i++) {
      final item = pendingItems[i];
      final itemProgress = (i + 1) / pendingItems.length;

      try {
        await db.markSyncProcessing(item.queueId);
        state = state.copyWith(
          progress: itemProgress,
          currentTask: 'Syncing ${item.entityType} #${item.entityId.substring(0, item.entityId.length.clamp(0, 8))} (${item.operation})...',
        );

        if (item.entityType == 'DOSSIER') {
          final dossier = await db.getDossierById(item.entityId);
          if (dossier != null && item.operation != 'DELETE') {
            final folderName = '${dossier.fullName}_${dossier.phoneNumber}';
            final remoteFolderId = await vaultService.createCustomerFolder(folderName: folderName);
            await db.updateDossierRemoteFolderId(dossier.id, remoteFolderId);
            newLogs.add('Customer folder created in Cloud: $folderName');
          }
        } else if (item.entityType == 'CASE') {
          final caseItem = await db.getCaseById(item.entityId);
          if (caseItem != null && item.operation != 'DELETE') {
            final dossier = await db.getDossierById(caseItem.dossierId);
            String parentFolderId = dossier?.remoteFolderId ?? 'root';
            if (dossier != null && (dossier.remoteFolderId == null || dossier.remoteFolderId!.isEmpty)) {
              final folderName = '${dossier.fullName}_${dossier.phoneNumber}';
              parentFolderId = await vaultService.createCustomerFolder(folderName: folderName);
              await db.updateDossierRemoteFolderId(dossier.id, parentFolderId);
            }
            final caseFolderId = await vaultService.createCaseFolder(parentFolderId: parentFolderId, caseTitle: caseItem.title);
            await db.updateCaseRemoteFolderId(caseItem.id, caseFolderId);
            newLogs.add('Case folder created in Cloud: ${caseItem.title}');
          }
        } else if (item.entityType == 'EXHIBIT') {
          final exhibit = await db.getExhibitById(item.entityId);
          if (exhibit != null) {
            if (item.operation == 'DELETE') {
              if (exhibit.remoteFileId != null) {
                await vaultService.deleteExhibit(exhibit.remoteFileId!);
                newLogs.add('Deleted remote file from Cloud: ${exhibit.fileName}');
              }
            } else {
              final caseItem = await db.getCaseById(exhibit.caseId);
              String parentFolderId = caseItem?.remoteFolderId ?? 'root';

              Uint8List fileBytes;
              if (exhibit.localPath != null && File(exhibit.localPath!).existsSync()) {
                fileBytes = await File(exhibit.localPath!).readAsBytes();
              } else {
                fileBytes = Uint8List.fromList('SAMPLE EXHIBIT CONTENT FOR ${exhibit.fileName}'.codeUnits);
              }

              final remoteId = await vaultService.uploadExhibit(
                parentFolderId: parentFolderId,
                fileName: exhibit.fileName,
                mimeType: exhibit.mimeType,
                fileBytes: fileBytes,
              );

              await db.updateExhibitRemoteId(exhibit.id, remoteId);
              newLogs.add('Uploaded document to Cloud: ${exhibit.fileName} (${(fileBytes.length / 1024).toStringAsFixed(1)} KB)');
            }
          }
        }

        await db.markSyncSuccess(item.queueId);
        successCount++;
      } catch (err) {
        await db.markSyncFailed(item.queueId);
        failedCount++;
        newLogs.add('Failed to sync ${item.entityType} #${item.entityId}: $err');
      }
    }

    state = state.copyWith(
      isSyncing: false,
      progress: 1.0,
      currentTask: null,
      lastSyncedAt: DateTime.now(),
      syncedCount: state.syncedCount + successCount,
      failedCount: state.failedCount + failedCount,
      logs: [
        '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} - Synced $successCount items successfully ($failedCount failed)',
        ...newLogs,
        ...state.logs,
      ],
    );
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final gdrive = ref.watch(googleDriveServiceProvider);
  final r2 = ref.watch(managedR2ServiceProvider);
  return SyncNotifier(ref, gdrive, r2);
});
