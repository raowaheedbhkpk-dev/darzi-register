import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'drive.dart';
import 'models.dart';

/// All app data, saved as one JSON file inside the phone.
/// Backup format is the same as the web version, so files move both ways.
class Store extends ChangeNotifier {
  List<Customer> customers = [];
  List<Order> orders = [];
  String shopName = '';
  String shopPhone = '';
  int lastBackup = 0;
  int changes = 0;
  bool loaded = false;
  File? _file;

  // Google Drive auto backup (like WhatsApp)
  final DriveBackup drive = DriveBackup();
  bool driveOn = false; // user turned it on
  String driveEmail = '';
  int lastDrive = 0; // last successful Drive upload
  String driveError = '';
  bool driveBusy = false;
  Timer? _autoTimer;

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/darzi_data.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString());
        if (j is Map<String, dynamic>) {
          _apply(j, merge: false);
          final meta = j['meta'];
          if (meta is Map) {
            lastBackup = (meta['lastBackup'] as num?)?.toInt() ?? 0;
            changes = (meta['changes'] as num?)?.toInt() ?? 0;
            driveOn = meta['driveOn'] == true;
            driveEmail = (meta['driveEmail'] ?? '').toString();
            lastDrive = (meta['lastDrive'] as num?)?.toInt() ?? 0;
          }
        }
      }
    } catch (e) {
      debugPrint('load error: $e');
    }
    loaded = true;
    notifyListeners();
    if (driveOn) {
      // quietly reconnect, then send anything not yet on Drive
      if (await drive.signInSilently()) {
        if (changes > 0) scheduleAutoBackup(delay: const Duration(seconds: 3));
      }
    }
  }

  /// Returns number of customers in [j].
  int _apply(Map<String, dynamic> j, {required bool merge}) {
    final cs = (j['customers'] is List ? j['customers'] as List : const [])
        .whereType<Map>()
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.id.isNotEmpty)
        .toList();
    final os = (j['orders'] is List ? j['orders'] as List : const [])
        .whereType<Map>()
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
        .where((o) => o.id.isNotEmpty)
        .toList();
    if (!merge) {
      customers = cs;
      orders = os;
    } else {
      for (final c in cs) {
        final i = customers.indexWhere((x) => x.id == c.id);
        if (i >= 0) {
          customers[i] = c;
        } else {
          customers.add(c);
        }
      }
      for (final o in os) {
        final i = orders.indexWhere((x) => x.id == o.id);
        if (i >= 0) {
          orders[i] = o;
        } else {
          orders.add(o);
        }
      }
    }
    final shop = j['shop'];
    if (shop is Map && (!merge || shopName.isEmpty)) {
      shopName = (shop['name'] ?? '').toString();
      shopPhone = (shop['phone'] ?? '').toString();
    }
    return cs.length;
  }

  Map<String, dynamic> _toJson({bool withMeta = false}) => {
        'app': 'darzi-register',
        'v': 1,
        'at': DateTime.now().toIso8601String(),
        'shop': {'name': shopName, 'phone': shopPhone},
        'customers': customers.map((c) => c.toJson()).toList(),
        'orders': orders.map((o) => o.toJson()).toList(),
        if (withMeta)
          'meta': {
            'lastBackup': lastBackup,
            'changes': changes,
            'driveOn': driveOn,
            'driveEmail': driveEmail,
            'lastDrive': lastDrive,
          },
      };

  Future<void> _save() async {
    final f = _file;
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(_toJson(withMeta: true)), flush: true);
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('save error: $e');
    }
  }

  Future<void> _changed() async {
    changes++;
    notifyListeners();
    await _save();
    scheduleAutoBackup();
  }

  // ---------- Google Drive auto backup ----------
  /// Waits a little so several quick edits go up as one backup.
  void scheduleAutoBackup({Duration delay = const Duration(seconds: 10)}) {
    if (!driveOn) return;
    _autoTimer?.cancel();
    _autoTimer = Timer(delay, () => backupToDrive(silent: true));
  }

  /// Called when the app goes to background: back up right away if needed.
  Future<void> flushBackup() async {
    if (!driveOn || changes == 0) return;
    _autoTimer?.cancel();
    await backupToDrive(silent: true);
  }

  Future<bool> backupToDrive({bool silent = false}) async {
    if (driveBusy) return false;
    // Never overwrite a Drive backup with an empty phone (new phone before restore).
    if (customers.isEmpty && orders.isEmpty) return false;
    driveBusy = true;
    notifyListeners();
    try {
      await drive.upload(jsonEncode(_toJson()));
      lastDrive = DateTime.now().millisecondsSinceEpoch;
      lastBackup = lastDrive;
      changes = 0;
      driveError = '';
      return true;
    } catch (e) {
      driveError = friendlyDriveError(e);
      if (!silent) rethrow;
      return false;
    } finally {
      driveBusy = false;
      notifyListeners();
      await _save();
    }
  }

  /// Connects a Google account. Returns the backup found on Drive (if any)
  /// so the screen can offer to restore it.
  Future<RemoteBackup?> connectDrive() async {
    final email = await drive.signIn();
    if (email == null) throw Exception('sign_in_canceled');
    driveOn = true;
    driveEmail = email;
    driveError = '';
    await _save();
    notifyListeners();
    RemoteBackup? remote;
    try {
      remote = await drive.download();
    } catch (e) {
      driveError = friendlyDriveError(e);
    }
    if (remote == null && (customers.isNotEmpty || orders.isNotEmpty)) {
      await backupToDrive(silent: true);
    }
    return remote;
  }

  Future<void> disconnectDrive() async {
    _autoTimer?.cancel();
    await drive.signOut();
    driveOn = false;
    driveEmail = '';
    await _save();
    notifyListeners();
  }

  /// Merges a backup's JSON into the phone. Returns number of customers in it.
  Future<int> restoreJson(String json) async {
    final j = jsonDecode(json);
    if (j is! Map<String, dynamic> || j['customers'] is! List) {
      throw const FormatException('bad');
    }
    final n = _apply(j, merge: true);
    changes++;
    notifyListeners();
    await _save();
    scheduleAutoBackup(); // send the merged data back up
    return n;
  }

  Future<int?> restoreFromDrive() async {
    final r = await drive.download();
    if (r == null) return null;
    return restoreJson(r.json);
  }

  // ---------- customers ----------
  Customer? customerById(String id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  int nextSerial() => customers.fold<int>(0, (m, c) => c.serial > m ? c.serial : m) + 1;

  bool serialTaken(int serial, String exceptId) =>
      customers.any((c) => c.serial == serial && c.id != exceptId);

  Future<void> putCustomer(Customer c) async {
    final i = customers.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      customers[i] = c;
    } else {
      customers.add(c);
    }
    for (final o in orders) {
      if (o.customerId == c.id) o.customerName = c.name;
    }
    await _changed();
  }

  Future<void> deleteCustomer(String id) async {
    customers.removeWhere((c) => c.id == id);
    orders.removeWhere((o) => o.customerId == id);
    await _changed();
  }

  // ---------- orders ----------
  Order? orderById(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<void> putOrder(Order o) async {
    final i = orders.indexWhere((x) => x.id == o.id);
    if (i >= 0) {
      orders[i] = o;
    } else {
      orders.add(o);
    }
    await _changed();
  }

  Future<void> deleteOrder(String id) async {
    orders.removeWhere((o) => o.id == id);
    await _changed();
  }

  bool isLate(Order o) {
    if (o.status == 'done' || o.status == 'ready') return false;
    final d = daysFromToday(o.delivery);
    return d != null && d < 0;
  }

  Future<void> saveShop(String name, String phone) async {
    shopName = name;
    shopPhone = phone;
    await _changed();
  }

  // ---------- backup ----------
  bool get needsBackup {
    if (customers.isEmpty) return false;
    if (driveOn) return driveError.isNotEmpty && changes > 0;
    if (lastBackup == 0) return true;
    final old = DateTime.now().millisecondsSinceEpoch - lastBackup > 3 * 86400000;
    return changes > 0 && (old || changes >= 15);
  }

  /// Opens the Android share sheet with a backup file. Choose "Drive" -> Save.
  /// Returns true when the user picked an app.
  Future<bool> shareBackup() async {
    final dir = await getTemporaryDirectory();
    final name = 'darzi-backup-${isoDate(DateTime.now())}.json';
    final f = File('${dir.path}/$name');
    await f.writeAsString(jsonEncode(_toJson()), flush: true);
    final r = await Share.shareXFiles(
      [XFile(f.path, mimeType: 'application/json', name: name)],
      subject: 'Darzi Register backup',
    );
    final ok = r.status != ShareResultStatus.dismissed;
    if (ok) {
      lastBackup = DateTime.now().millisecondsSinceEpoch;
      changes = 0;
      notifyListeners();
      await _save();
    }
    return ok;
  }

  /// Lets the user pick a backup file (Drive appears in the picker) and merges it.
  /// Returns number of customers restored, or null if cancelled.
  Future<int?> restoreBackup() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (res == null || res.files.isEmpty) return null;
    final pf = res.files.single;
    List<int>? bytes = pf.bytes;
    if (bytes == null && pf.path != null) bytes = await File(pf.path!).readAsBytes();
    if (bytes == null) throw const FormatException('file');
    final j = jsonDecode(utf8.decode(bytes));
    if (j is! Map<String, dynamic> || j['customers'] is! List) {
      throw const FormatException('bad');
    }
    final n = _apply(j, merge: true);
    await _changed();
    return n;
  }
}

final store = Store();
