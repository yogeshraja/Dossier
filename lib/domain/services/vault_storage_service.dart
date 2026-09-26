import 'dart:typed_data';

abstract class VaultStorageService {
  /// Create root customer profile folder
  Future<String> createCustomerFolder({required String folderName});

  /// Create child case folder under customer folder
  Future<String> createCaseFolder({
    required String parentFolderId,
    required String caseTitle,
  });

  /// Upload document artifact (PDF, JPG)
  Future<String> uploadExhibit({
    required String parentFolderId,
    required String fileName,
    required String mimeType,
    required Uint8List fileBytes,
    void Function(double progress)? onProgress,
  });

  /// Get direct view or download URI for remote artifact
  Future<Uri> getDirectViewUri(String remoteFileId);

  /// Delete artifact from remote vault
  Future<void> deleteExhibit(String remoteFileId);
}
