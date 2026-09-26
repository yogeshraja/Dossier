import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:dossier/domain/services/vault_storage_service.dart';

class GoogleDriveVaultService implements VaultStorageService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  drive.DriveApi? _driveApi;
  String? _rootFolderId;

  Future<bool> authenticate() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return false;

    final authHeaders = await account.authHeaders;
    final client = _AuthenticatedHttpClient(authHeaders, http.Client());
    _driveApi = drive.DriveApi(client);

    await _ensureRootFolder();
    return true;
  }

  Future<void> _ensureRootFolder() async {
    if (_driveApi == null) return;
    final query = "mimeType = 'application/vnd.google-apps.folder' and name = 'Dossier_Workspace' and trashed = false";
    final result = await _driveApi!.files.list(q: query, spaces: 'drive');
    if (result.files != null && result.files!.isNotEmpty) {
      _rootFolderId = result.files!.first.id;
    } else {
      final folder = drive.File()
        ..name = 'Dossier_Workspace'
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await _driveApi!.files.create(folder);
      _rootFolderId = created.id;
    }
  }

  @override
  Future<String> createCustomerFolder({required String folderName}) async {
    if (_driveApi == null || _rootFolderId == null) throw Exception('Drive not initialized');
    final folder = drive.File()
      ..name = folderName
      ..parents = [_rootFolderId!]
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await _driveApi!.files.create(folder);
    return created.id ?? '';
  }

  @override
  Future<String> createCaseFolder({
    required String parentFolderId,
    required String caseTitle,
  }) async {
    if (_driveApi == null) throw Exception('Drive not initialized');
    final folder = drive.File()
      ..name = caseTitle
      ..parents = [parentFolderId]
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await _driveApi!.files.create(folder);
    return created.id ?? '';
  }

  @override
  Future<String> uploadExhibit({
    required String parentFolderId,
    required String fileName,
    required String mimeType,
    required Uint8List fileBytes,
    void Function(double progress)? onProgress,
  }) async {
    if (_driveApi == null) throw Exception('Drive not initialized');
    final driveFile = drive.File()
      ..name = fileName
      ..parents = [parentFolderId];

    final media = drive.Media(
      Stream.value(fileBytes),
      fileBytes.length,
      contentType: mimeType,
    );

    final uploaded = await _driveApi!.files.create(driveFile, uploadMedia: media);
    return uploaded.id ?? '';
  }

  @override
  Future<Uri> getDirectViewUri(String remoteFileId) async {
    return Uri.parse('https://drive.google.com/file/d/$remoteFileId/view');
  }

  @override
  Future<void> deleteExhibit(String remoteFileId) async {
    if (_driveApi == null) throw Exception('Drive not initialized');
    await _driveApi!.files.delete(remoteFileId);
  }
}

class _AuthenticatedHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner;

  _AuthenticatedHttpClient(this._headers, this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
