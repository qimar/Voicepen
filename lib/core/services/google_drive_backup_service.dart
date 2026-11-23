import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path/path.dart' as p;

final googleDriveBackupServiceProvider = Provider<GoogleDriveBackupService>((ref) {
  return GoogleDriveBackupService();
});

/// Service responsible for backing up audio recordings directly to the user's
/// private Google Drive ("VoicePen Audio Vault" folder).
/// This ensures 100% data ownership for the user and $0 cloud storage/egress cost.
class GoogleDriveBackupService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: const String.fromEnvironment(
      'GOOGLE_CLIENT_ID',
      defaultValue: 'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com',
    ),
    scopes: [
      drive.DriveApi.driveFileScope, // Only access files created by VoicePen
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  String? _vaultFolderId;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  GoogleDriveBackupService() {
    _googleSignIn.onCurrentUserChanged.listen((account) async {
      _currentUser = account;
      if (account != null) {
        final client = await _googleSignIn.authenticatedClient();
        if (client != null) {
          _driveApi = drive.DriveApi(client);
        }
      } else {
        _driveApi = null;
        _vaultFolderId = null;
      }
    });
  }

  /// Attempts silent sign in if previously authorized
  Future<bool> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      _currentUser = account;
      if (account != null) {
        final client = await _googleSignIn.authenticatedClient();
        if (client != null) {
          _driveApi = drive.DriveApi(client);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[GoogleDrive] Silent sign-in error: $e');
    }
    return false;
  }

  /// Prompts the user to authenticate with Google
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      if (account != null) {
        final client = await _googleSignIn.authenticatedClient();
        if (client != null) {
          _driveApi = drive.DriveApi(client);
          debugPrint('[GoogleDrive] Signed in as ${account.email}');
          // Pre-fetch or create vault folder
          await _getOrCreateVaultFolder();
        }
      }
      return account;
    } catch (e) {
      debugPrint('[GoogleDrive] Sign-in error: $e');
      rethrow;
    }
  }

  /// Disconnects Google account
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      _driveApi = null;
      _vaultFolderId = null;
      debugPrint('[GoogleDrive] Signed out.');
    } catch (e) {
      debugPrint('[GoogleDrive] Sign-out error: $e');
    }
  }

  /// Finds or creates the "VoicePen Audio Vault" folder in the user's Drive root
  Future<String> _getOrCreateVaultFolder() async {
    if (_vaultFolderId != null) return _vaultFolderId!;
    if (_driveApi == null) {
      throw Exception('Drive API client is not initialized. User not signed in.');
    }

    try {
      const folderName = 'VoicePen Audio Vault';
      // Search for existing folder created by this app
      final query = "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and trashed = false";
      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        _vaultFolderId = fileList.files!.first.id;
        debugPrint('[GoogleDrive] Found existing vault folder: $_vaultFolderId');
        return _vaultFolderId!;
      }

      // Create new folder
      final folderMetadata = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..description = 'VoicePen Voice Memos & Master Audio Backups';

      final createdFolder = await _driveApi!.files.create(
        folderMetadata,
        $fields: 'id',
      );

      _vaultFolderId = createdFolder.id;
      debugPrint('[GoogleDrive] Created new vault folder: $_vaultFolderId');
      return _vaultFolderId!;
    } catch (e) {
      debugPrint('[GoogleDrive] Error finding/creating vault folder: $e');
      rethrow;
    }
  }

  /// Uploads a local audio recording to the user's Google Drive vault.
  /// Returns the Google Drive File ID.
  Future<String?> uploadAudioFile({
    required String localPath,
    required String noteTitle,
    required String noteId,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      debugPrint('[GoogleDrive] Local audio file does not exist: $localPath');
      return null;
    }

    if (_driveApi == null) {
      final success = await signInSilently();
      if (!success) {
        debugPrint('[GoogleDrive] Cannot upload: user not signed in.');
        return null;
      }
    }

    try {
      final folderId = await _getOrCreateVaultFolder();
      final ext = p.extension(localPath).isNotEmpty ? p.extension(localPath) : '.m4a';
      final cleanTitle = noteTitle.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      final fileName = '${cleanTitle.isEmpty ? "voice_memo" : cleanTitle}_$noteId$ext';

      // Determine mime type
      String mimeType = 'audio/mp4';
      if (ext.contains('aac')) {
        mimeType = 'audio/aac';
      } else if (ext.contains('wav')) {
        mimeType = 'audio/wav';
      } else if (ext.contains('mp3')) {
        mimeType = 'audio/mpeg';
      }

      final fileLength = await file.length();
      final media = drive.Media(file.openRead(), fileLength, contentType: mimeType);

      final driveFile = drive.File()
        ..name = fileName
        ..mimeType = mimeType
        ..parents = [folderId]
        ..description = 'VoicePen Note ID: $noteId'
        ..properties = {'noteId': noteId};

      debugPrint('[GoogleDrive] Uploading $fileName ($fileLength bytes, $mimeType)...');
      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id, name, webViewLink',
      );

      debugPrint('[GoogleDrive] Audio uploaded successfully. Drive ID: ${result.id}');
      return result.id;
    } catch (e) {
      debugPrint('[GoogleDrive] Upload failed: $e');
      return null;
    }
  }

  /// Downloads an audio file from Google Drive into local sandboxed storage
  Future<File?> downloadAudioFile({
    required String fileId,
    required String targetLocalPath,
  }) async {
    if (_driveApi == null) {
      final success = await signInSilently();
      if (!success) return null;
    }

    try {
      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final targetFile = File(targetLocalPath);
      await targetFile.parent.create(recursive: true);

      final sink = targetFile.openWrite();
      await sink.addStream(media.stream);
      await sink.close();

      debugPrint('[GoogleDrive] Audio downloaded to $targetLocalPath');
      return targetFile;
    } catch (e) {
      debugPrint('[GoogleDrive] Download failed: $e');
      return null;
    }
  }

  /// Deletes an audio backup file from Google Drive
  Future<void> deleteAudioFile(String fileId) async {
    if (_driveApi == null) {
      final success = await signInSilently();
      if (!success) return;
    }

    try {
      await _driveApi!.files.delete(fileId);
      debugPrint('[GoogleDrive] Deleted file $fileId from Google Drive.');
    } catch (e) {
      debugPrint('[GoogleDrive] Error deleting file: $e');
    }
  }
}
