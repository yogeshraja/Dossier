import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:dossier/domain/services/vault_storage_service.dart';

class ManagedR2VaultService implements VaultStorageService {
  final String backendBaseUrl;
  final String authToken;
  final bool isMockMode;

  ManagedR2VaultService({
    this.backendBaseUrl = 'https://vault.csc-dossier.org',
    this.authToken = 'kiosk_managed_r2_token',
    this.isMockMode = true,
  });

  @override
  Future<String> createCustomerFolder({required String folderName}) async {
    // Cloudflare R2 is object-based with prefixes; return prefix path
    final cleanName = folderName.replaceAll(' ', '_');
    return 'customers/$cleanName';
  }

  @override
  Future<String> createCaseFolder({
    required String parentFolderId,
    required String caseTitle,
  }) async {
    final cleanTitle = caseTitle.replaceAll(' ', '_');
    return '$parentFolderId/cases/$cleanTitle';
  }

  @override
  Future<String> uploadExhibit({
    required String parentFolderId,
    required String fileName,
    required String mimeType,
    required Uint8List fileBytes,
    void Function(double progress)? onProgress,
  }) async {
    final key = '$parentFolderId/$fileName';

    if (isMockMode) {
      // Simulate R2 streaming chunks with progress
      for (int i = 0; i <= 5; i++) {
        await Future.delayed(const Duration(milliseconds: 30));
        onProgress?.call((i / 5.0).clamp(0.0, 1.0));
      }
      return 'r2_$key';
    }

    // Step 1: Request presigned S3 PUT URL from Dossier Worker API
    final presignUri = Uri.parse('$backendBaseUrl/api/v1/vault/presign-upload');
    final response = await http.post(
      presignUri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'key': key,
        'mimeType': mimeType,
        'sizeBytes': fileBytes.lengthInBytes,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get presigned upload URL: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final String uploadUrl = data['uploadUrl'];

    // Step 2: Stream binary data directly to Cloudflare R2
    final putResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': mimeType},
      body: fileBytes,
    );

    if (putResponse.statusCode != 200 && putResponse.statusCode != 204) {
      throw Exception('Failed to upload file to R2: ${putResponse.statusCode}');
    }

    return key;
  }

  @override
  Future<Uri> getDirectViewUri(String remoteFileId) async {
    if (isMockMode) {
      return Uri.parse('https://vault.csc-dossier.org/view/$remoteFileId');
    }

    final presignViewUri = Uri.parse('$backendBaseUrl/api/v1/vault/presign-view?key=$remoteFileId');
    final response = await http.get(
      presignViewUri,
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Uri.parse(data['viewUrl']);
    }
    return Uri.parse('https://vault.csc-dossier.org/view/$remoteFileId');
  }

  @override
  Future<void> deleteExhibit(String remoteFileId) async {
    if (isMockMode) return;
    final deleteUri = Uri.parse('$backendBaseUrl/api/v1/vault/delete?key=$remoteFileId');
    await http.delete(
      deleteUri,
      headers: {'Authorization': 'Bearer $authToken'},
    );
  }
}
