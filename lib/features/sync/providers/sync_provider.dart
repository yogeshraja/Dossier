import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/remote/gdrive/google_drive_vault_service.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';

final googleDriveServiceProvider = Provider<GoogleDriveVaultService>((ref) {
  return GoogleDriveVaultService();
});

class SyncState {
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

  SyncNotifier(this._ref, this._gdrive) : super(const SyncState());

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

  Future<void> triggerSync() async {
    if (state.isSyncing) return;

    if (!state.isConnected) {
      final connected = await connectGoogleDrive(forceMock: true);
      if (!connected) return;
    }

    state = state.copyWith(isSyncing: true, progress: 0.0, currentTask: 'Scanning pending sync outbox...');

    final db = _ref.read(databaseProvider);
    final pendingItems = await db.getPendingSyncItems();

    if (pendingItems.isEmpty) {
      state = state.copyWith(
        isSyncing: false,
        progress: 1.0,
        currentTask: null,
        lastSyncedAt: DateTime.now(),
        logs: [
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} - Outbox is clean (0 items to sync)',
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
            final remoteFolderId = await _gdrive.createCustomerFolder(folderName: folderName);
            await db.updateDossierRemoteFolderId(dossier.id, remoteFolderId);
            newLogs.add('Customer folder created in Google Drive: $folderName');
          }
        } else if (item.entityType == 'CASE') {
          final caseItem = await db.getCaseById(item.entityId);
          if (caseItem != null && item.operation != 'DELETE') {
            final dossier = await db.getDossierById(caseItem.dossierId);
            String parentFolderId = dossier?.remoteFolderId ?? _gdrive.rootFolderId ?? 'root';
            if (dossier != null && (dossier.remoteFolderId == null || dossier.remoteFolderId!.isEmpty)) {
              final folderName = '${dossier.fullName}_${dossier.phoneNumber}';
              parentFolderId = await _gdrive.createCustomerFolder(folderName: folderName);
              await db.updateDossierRemoteFolderId(dossier.id, parentFolderId);
            }
            final caseFolderId = await _gdrive.createCaseFolder(parentFolderId: parentFolderId, caseTitle: caseItem.title);
            await db.updateCaseRemoteFolderId(caseItem.id, caseFolderId);
            newLogs.add('Case folder created in Google Drive: ${caseItem.title}');
          }
        } else if (item.entityType == 'EXHIBIT') {
          final exhibit = await db.getExhibitById(item.entityId);
          if (exhibit != null) {
            if (item.operation == 'DELETE') {
              if (exhibit.remoteFileId != null) {
                await _gdrive.deleteExhibit(exhibit.remoteFileId!);
                newLogs.add('Deleted remote file from Google Drive: ${exhibit.fileName}');
              }
            } else {
              final caseItem = await db.getCaseById(exhibit.caseId);
              String parentFolderId = caseItem?.remoteFolderId ?? _gdrive.rootFolderId ?? 'root';

              Uint8List fileBytes;
              if (exhibit.localPath != null && File(exhibit.localPath!).existsSync()) {
                fileBytes = await File(exhibit.localPath!).readAsBytes();
              } else {
                fileBytes = Uint8List.fromList('SAMPLE EXHIBIT CONTENT FOR ${exhibit.fileName}'.codeUnits);
              }

              final remoteId = await _gdrive.uploadExhibit(
                parentFolderId: parentFolderId,
                fileName: exhibit.fileName,
                mimeType: exhibit.mimeType,
                fileBytes: fileBytes,
              );

              await db.updateExhibitRemoteId(exhibit.id, remoteId);
              newLogs.add('Uploaded document to Google Drive: ${exhibit.fileName} (${(fileBytes.length / 1024).toStringAsFixed(1)} KB)');
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
  return SyncNotifier(ref, gdrive);
});
