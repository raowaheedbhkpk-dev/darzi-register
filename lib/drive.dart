import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Adds the signed-in user's Google auth headers to every Drive request.
class _AuthClient extends http.BaseClient {
  final Map<String, String> headers;
  final http.Client _inner = http.Client();
  _AuthClient(this.headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return _inner.send(request);
  }
}

class RemoteBackup {
  final String json;
  final DateTime? modified;
  RemoteBackup(this.json, this.modified);
}

/// WhatsApp-style backup: one file in the hidden "app data" folder of the
/// user's Google Drive. Only this app can see it.
class DriveBackup {
  static const fileName = 'darzi_backup.json';
  final GoogleSignIn _gs = GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);
  GoogleSignInAccount? account;

  String? get email => account?.email;

  /// Interactive sign-in (shows the Google account chooser).
  Future<String?> signIn() async {
    account = await _gs.signIn();
    return account?.email;
  }

  /// Quiet sign-in using the account chosen before. Returns false if not possible.
  Future<bool> signInSilently() async {
    try {
      account ??= await _gs.signInSilently();
    } catch (_) {
      account = null;
    }
    return account != null;
  }

  Future<void> signOut() async {
    try {
      await _gs.disconnect();
    } catch (_) {
      await _gs.signOut();
    }
    account = null;
  }

  Future<drive.DriveApi> _api() async {
    if (!await signInSilently()) throw Exception('Google account juda hua nahi');
    final h = await account!.authHeaders;
    return drive.DriveApi(_AuthClient(h));
  }

  Future<drive.File?> _find(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$fileName' and trashed=false",
      orderBy: 'modifiedTime desc',
      $fields: 'files(id,modifiedTime,size)',
    );
    final files = list.files ?? const <drive.File>[];
    return files.isEmpty ? null : files.first;
  }

  Future<DateTime> upload(String json) async {
    final api = await _api();
    final bytes = utf8.encode(json);
    final media = drive.Media(Stream<List<int>>.value(bytes), bytes.length, contentType: 'application/json');
    final existing = await _find(api);
    if (existing?.id != null) {
      await api.files.update(drive.File(), existing!.id!, uploadMedia: media);
    } else {
      final meta = drive.File()
        ..name = fileName
        ..parents = ['appDataFolder'];
      await api.files.create(meta, uploadMedia: media);
    }
    return DateTime.now();
  }

  /// Info about the backup on Drive without downloading it.
  Future<DateTime?> remoteTime() async {
    final api = await _api();
    final f = await _find(api);
    return f?.modifiedTime;
  }

  Future<RemoteBackup?> download() async {
    final api = await _api();
    final f = await _find(api);
    if (f?.id == null) return null;
    final media = await api.files.get(f!.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final chunks = <int>[];
    await for (final c in media.stream) {
      chunks.addAll(c);
    }
    return RemoteBackup(utf8.decode(chunks), f.modifiedTime);
  }
}

/// Turns Google's error codes into something a shopkeeper can act on.
String friendlyDriveError(Object e) {
  final s = e.toString();
  if (s.contains('ApiException: 10') || s.contains('DEVELOPER_ERROR') || s.contains('sign_in_failed')) {
    return 'Google se judna nahi hua. Google Cloud setup (README ka Qadam "Auto backup") poora karein.';
  }
  if (s.contains('network') || s.contains('SocketException') || s.contains('ApiException: 7')) {
    return 'Internet nahi hai. Internet aane par backup khud ho jayega.';
  }
  if (s.contains('sign_in_canceled') || s.contains('ApiException: 12501')) {
    return 'Google account nahi chuna gaya.';
  }
  return 'Drive masla: $s';
}
