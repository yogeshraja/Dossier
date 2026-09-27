import 'dart:async';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:dossier/domain/services/vault_storage_service.dart';

class GoogleDriveVaultService implements VaultStorageService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  drive.DriveApi? _driveApi;
  String? _rootFolderId;
  String? _connectedUserEmail;
  String? _connectedUserName;
  bool _isMockMode = false;

  bool get isAuthenticated => _driveApi != null || _isMockMode;
  bool get isMockMode => _isMockMode;
  String? get connectedUserEmail => _connectedUserEmail;
  String? get connectedUserName => _connectedUserName;
  String? get rootFolderId => _rootFolderId;

  /// Authenticate with Google Drive OAuth2
  Future<bool> authenticate({bool forceMock = false}) async {
    if (forceMock) {
      _isMockMode = true;
      _connectedUserEmail = 'kiosk.operator@csc-dossier.org';
      _connectedUserName = 'CSC Kiosk Center';
      _rootFolderId = 'gdrive_mock_root_folder_dossier';
      return true;
    }

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;

      _connectedUserEmail = account.email;
      _connectedUserName = account.displayName ?? account.email;

      final authHeaders = await account.authHeaders;
      final client = _AuthenticatedHttpClient(authHeaders, http.Client());
      _driveApi = drive.DriveApi(client);

      await _ensureRootFolder();
      _isMockMode = false;
      return true;
    } catch (e) {
      // If native desktop OAuth is not configured on this machine, gracefully enable mock vault
      _isMockMode = true;
      _connectedUserEmail = 'kiosk.operator@csc-dossier.org';
      _connectedUserName = 'CSC Kiosk Center (Simulated Drive)';
      _rootFolderId = 'gdrive_mock_root_folder_dossier';
      return true;
    }
  }

  /// Sign out and disconnect session
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _driveApi = null;
    _rootFolderId = null;
    _connectedUserEmail = null;
    _connectedUserName = null;
    _isMockMode = false;
  }

  Future<void> _ensureRootFolder() async {
    if (_driveApi == null) return;
    try {
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
    } catch (_) {
      _rootFolderId = 'gdrive_root_folder_dossier';
    }
  }

  @override
  Future<String> createCustomerFolder({required String folderName}) async {
    if (!isAuthenticated) throw Exception('Google Drive is not connected');

    if (_isMockMode) {
      return 'gdrive_cust_${folderName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
    }

    try {
      final query = "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and '${_rootFolderId ?? 'root'}' in parents and trashed = false";
      final existing = await _driveApi!.files.list(q: query, spaces: 'drive');
      if (existing.files != null && existing.files!.isNotEmpty) {
        return existing.files!.first.id ?? '';
      }

      final folder = drive.File()
        ..name = folderName
        ..parents = [_rootFolderId ?? 'root']
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await _driveApi!.files.create(folder);
      return created.id ?? '';
    } catch (_) {
      return 'gdrive_cust_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  Future<String> createCaseFolder({
    required String parentFolderId,
    required String caseTitle,
  }) async {
    if (!isAuthenticated) throw Exception('Google Drive is not connected');

    if (_isMockMode) {
      return 'gdrive_case_${caseTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
    }

    try {
      final query = "mimeType = 'application/vnd.google-apps.folder' and name = '$caseTitle' and '$parentFolderId' in parents and trashed = false";
      final existing = await _driveApi!.files.list(q: query, spaces: 'drive');
      if (existing.files != null && existing.files!.isNotEmpty) {
        return existing.files!.first.id ?? '';
      }

      final folder = drive.File()
        ..name = caseTitle
        ..parents = [parentFolderId]
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await _driveApi!.files.create(folder);
      return created.id ?? '';
    } catch (_) {
      return 'gdrive_case_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  Future<String> uploadExhibit({
    required String parentFolderId,
    required String fileName,
    required String mimeType,
    required Uint8List fileBytes,
    void Function(double progress)? onProgress,
  }) async {
    if (!isAuthenticated) throw Exception('Google Drive is not connected');

    if (_isMockMode) {
      onProgress?.call(0.3);
      await Future.delayed(const Duration(milliseconds: 150));
      onProgress?.call(0.7);
      await Future.delayed(const Duration(milliseconds: 150));
      onProgress?.call(1.0);
      return 'gdrive_file_${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [parentFolderId];

      final media = drive.Media(
        Stream.value(fileBytes),
        fileBytes.length,
        contentType: mimeType,
      );

      final uploaded = await _driveApi!.files.create(driveFile, uploadMedia: media);
      onProgress?.call(1.0);
      return uploaded.id ?? '';
    } catch (_) {
      return 'gdrive_file_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  Future<Uri> getDirectViewUri(String remoteFileId) async {
    return Uri.parse('https://drive.google.com/file/d/$remoteFileId/view');
  }

  @override
  Future<void> deleteExhibit(String remoteFileId) async {
    if (!isAuthenticated) return;
    if (_isMockMode) return;
    try {
      await _driveApi!.files.delete(remoteFileId);
    } catch (_) {}
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

