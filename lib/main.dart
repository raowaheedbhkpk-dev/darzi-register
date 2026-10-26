import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'customers.dart';
import 'drive.dart';
import 'models.dart';
import 'orders.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  store.load();
  runApp(const DarziApp());
}

class DarziApp extends StatelessWidget {
  const DarziApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darzi Register',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;
  String orderFilter = 'open';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Like WhatsApp: when the app is closed or switched away, send changes to Drive.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      store.flushBackup();
    }
  }

  void openOrders(String filter) => setState(() {
        orderFilter = filter;
        tab = 2;
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.loaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final pages = [
          HomeTab(onOpenOrders: openOrders),
          CustomersTab(),
          OrdersTab(filter: orderFilter, onFilter: (f) => setState(() => orderFilter = f)),
          SettingsTab(),
        ];
        return PopScope(
          canPop: tab == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => tab = 0);
          },
          child: Scaffold(
            body: pages[tab],
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: 'Customers'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
                NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Settings'),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ======================= HOME =======================
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

class HomeTab extends StatelessWidget {
  final void Function(String filter) onOpenOrders;
  const HomeTab({super.key, required this.onOpenOrders});

  @override
  Widget build(BuildContext context) {
    final open = store.orders.where((o) => o.status != 'done').toList();
    final todayDue = open.where((o) => daysFromToday(o.delivery) == 0 && o.status != 'ready').length;
    final late = open.where(store.isLate).length;
    final ready = open.where((o) => o.status == 'ready').length;
    final dueTotal = store.orders.fold<num>(0, (s, o) => s + o.due);
    final upcoming = open.where((o) => o.status != 'ready').toList()
      ..sort((a, b) => (a.delivery.isEmpty ? '9' : a.delivery).compareTo(b.delivery.isEmpty ? '9' : b.delivery));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(open: open.length),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Grid2([
                StatTile(value: '$todayDue', label: 'Due today', icon: Icons.today_outlined, onTap: () => onOpenOrders('today')),
                StatTile(value: '$late', label: 'Late orders', icon: Icons.warning_amber_rounded, alert: late > 0, onTap: () => onOpenOrders('late')),
                StatTile(value: '$ready', label: 'Ready for pickup', icon: Icons.checkroom, onTap: () => onOpenOrders('ready')),
                StatTile(value: rs(dueTotal), label: 'Payments due', icon: Icons.account_balance_wallet_outlined, onTap: () => onOpenOrders('due')),
              ]),
              if (store.needsBackup) ...[const SizedBox(height: 14), const BackupBanner()],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerFormScreen())),
                    icon: const Icon(Icons.person_add_alt_1, size: 20),
                    label: const Text('New customer'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.wineDeep),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderFormScreen())),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('New order'),
                  ),
                ),
              ]),
              SectionTitle('Upcoming deliveries', trailing: '${upcoming.length}'),
              if (upcoming.isEmpty)
                const EmptyNote('No open orders.\nOpen a customer and tap "New order".', icon: Icons.event_available_outlined)
              else
                ListCard(children: [
                  for (final o in upcoming.take(10))
                    OrderTile(
                      order: o,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderFormScreen(orderId: o.id))),
                    ),
                ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final int open;
  const _Hero({required this.open});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final top = MediaQuery.of(context).padding.top;
    final ok = store.driveOn && store.driveError.isEmpty;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.wine, AppColors.wineDeep],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, top + 18, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${_weekdays[now.weekday - 1]}, ${fmtDate(isoDate(now))}'.toUpperCase(),
                style: GoogleFonts.manrope(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(store.driveBusy ? Icons.cloud_sync : (ok ? Icons.cloud_done : Icons.cloud_off), size: 15, color: ok ? AppColors.goldSoft : Colors.white70),
              const SizedBox(width: 5),
              Text(store.lastBackup == 0 ? 'No backup' : agoText(store.lastBackup),
                  style: GoogleFonts.manrope(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(store.shopName.isEmpty ? 'Darzi Register' : store.shopName,
            style: GoogleFonts.manrope(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.5, height: 1.15)),
        const SizedBox(height: 4),
        Text(
          open == 0 ? 'No open orders right now' : '$open open order${open == 1 ? '' : 's'} · ${store.customers.length} customers',
          style: GoogleFonts.manrope(color: Colors.white.withValues(alpha: .82), fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        const TapeStrip(),
        const SizedBox(height: 18),
      ]),
    );
  }
}

class BackupBanner extends StatelessWidget {
  const BackupBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusColors(context, 'cutting');
    final text = store.driveOn
        ? 'Drive backup paused: ${store.driveError}'
        : store.lastBackup == 0
            ? 'Google Drive backup is off. If this phone is lost, your data is lost too.'
            : 'Last backup was ${agoText(store.lastBackup)}. ${store.changes} changes are not backed up yet.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.cloud_off_outlined, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.manrope(color: fg, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.4))),
        ]),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: fg, side: BorderSide(color: fg), minimumSize: const Size(0, 40)),
          onPressed: () => store.driveOn ? driveBackupNow(context) : connectDriveFlow(context),
          child: Text(store.driveOn ? 'Try again' : 'Turn on Drive backup'),
        ),
      ]),
    );
  }
}

// ======================= BACKUP ACTIONS =======================
Future<void> driveBackupNow(BuildContext context) async {
  try {
    await store.backupToDrive();
    if (context.mounted) toast(context, 'Backed up to Google Drive');
  } catch (e) {
    if (context.mounted) toast(context, friendlyDriveError(e));
  }
}

/// Sign in with Google; if a backup already exists on Drive, offer to restore it.
Future<void> connectDriveFlow(BuildContext context) async {
  try {
    final remote = await store.connectDrive();
    if (!context.mounted) return;
    if (remote == null) {
      toast(context, store.driveError.isEmpty ? 'Google Drive connected. Backups now run automatically.' : store.driveError);
      return;
    }
    int count = 0;
    try {
      final j = jsonDecode(remote.json);
      if (j is Map && j['customers'] is List) count = (j['customers'] as List).length;
    } catch (_) {}
    final when = remote.modified == null ? '' : ' from ${fmtMillis(remote.modified!.millisecondsSinceEpoch)}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.cloud_download_outlined, color: wine(context), size: 32),
        title: Text('Backup found', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        content: Text('This Google account has a backup$when with $count customers.\n\n'
            'Restore it to this phone? Anything already on this phone is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: () => Navigator.pop(c, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok == true) {
      final n = await store.restoreJson(remote.json);
      if (context.mounted) toast(context, 'Restored $n customers from Drive');
    } else if (store.customers.isNotEmpty) {
      await store.backupToDrive(silent: true);
    }
  } catch (e) {
    if (context.mounted) toast(context, friendlyDriveError(e));
  }
}

Future<void> shareBackupFile(BuildContext context) async {
  try {
    final ok = await store.shareBackup();
    if (ok && context.mounted) toast(context, 'Backup file shared');
  } catch (e) {
    if (context.mounted) toast(context, 'Could not create backup: $e');
  }
}

// ======================= SETTINGS =======================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late final TextEditingController name = TextEditingController(text: store.shopName);
  late final TextEditingController phone = TextEditingController(text: store.shopPhone);

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = store.orders.where((o) {
      final d = DateTime.fromMillisecondsSinceEpoch(o.createdAt);
      return d.year == now.year && d.month == now.month;
    }).toList();
    final received = store.orders.fold<num>(0, (s, o) => s + o.advance);
    final ok = store.driveOn && store.driveError.isEmpty;
    final (okBg, okFg) = statusColors(context, ok ? 'ready' : (store.driveOn ? 'late' : 'done'));
    final small = GoogleFonts.manrope(fontSize: 13, color: muted(context), height: 1.45, fontWeight: FontWeight.w500);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          const SectionTitle('This month'),
          Grid2([
            StatTile(value: '${month.length}', label: 'New orders', icon: Icons.receipt_long_outlined),
            StatTile(value: '${month.fold<int>(0, (s, o) => s + o.suits)}', label: 'Suits', icon: Icons.checkroom),
            StatTile(value: rs(month.fold<num>(0, (s, o) => s + o.price)), label: 'Stitching total', icon: Icons.payments_outlined),
            StatTile(value: '${store.customers.length}', label: 'All customers', icon: Icons.people_alt_outlined),
          ]),

          const SectionTitle('Google Drive backup'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: okBg, borderRadius: BorderRadius.circular(14)),
                    child: Icon(ok ? Icons.cloud_done : (store.driveOn ? Icons.cloud_off : Icons.cloud_outlined), color: okFg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(store.driveOn ? (ok ? 'Auto backup is on' : 'Backup paused') : 'Auto backup is off',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(store.driveOn ? store.driveEmail : 'Not connected', style: small),
                    ]),
                  ),
                  if (store.driveBusy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                ]),
                const SizedBox(height: 12),
                Text(
                  store.driveOn
                      ? 'Every change is saved to your Google Drive about 10 seconds later, and again when you close the app. '
                          'Last backup: ${store.lastDrive == 0 ? 'not yet' : agoText(store.lastDrive)}.'
                      : 'Connect your Google account and everything is backed up automatically, just like WhatsApp. '
                          'On a new phone, connect the same account to get it all back.',
                  style: small,
                ),
                if (store.driveError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(store.driveError, style: small.copyWith(color: statusColors(context, 'late').$2, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 14),
                if (!store.driveOn)
                  FilledButton.icon(
                    onPressed: () => connectDriveFlow(context),
                    icon: const Icon(Icons.add_to_drive),
                    label: const Text('Connect Google Drive'),
                  )
                else ...[
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: store.driveBusy ? null : () => driveBackupNow(context),
                        icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                        label: const Text('Back up now'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: store.driveBusy
                            ? null
                            : () async {
                                try {
                                  final n = await store.restoreFromDrive();
                                  if (!context.mounted) return;
                                  toast(context, n == null ? 'No backup found on Drive' : 'Restored $n customers from Drive');
                                } catch (e) {
                                  if (context.mounted) toast(context, friendlyDriveError(e));
                                }
                              },
                        icon: const Icon(Icons.cloud_download_outlined, size: 20),
                        label: const Text('Restore'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () async {
                      await store.disconnectDrive();
                      if (context.mounted) toast(context, 'Google account disconnected');
                    },
                    child: const Text('Disconnect Google account'),
                  ),
                ],
              ]),
            ),
          ),

          const SectionTitle('Shop'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Shop name', hintText: 'e.g. Bilal Tailors')),
                const SizedBox(height: 12),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Shop phone')),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    await store.saveShop(name.text.trim(), phone.text.trim());
                    if (context.mounted) toast(context, 'Saved');
                  },
                  child: const Text('Save'),
                ),
                const SizedBox(height: 8),
                Text('The shop name appears on the home screen, measurement slips and WhatsApp messages.', style: small),
              ]),
            ),
          ),

          const SectionTitle('Backup file'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Send a copy of all data by WhatsApp or email, or load data from a backup file.', style: small),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => shareBackupFile(context),
                      icon: const Icon(Icons.ios_share, size: 20),
                      label: const Text('Share file'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final n = await store.restoreBackup();
                          if (n != null && context.mounted) toast(context, 'Restored $n customers');
                        } catch (e) {
                          if (context.mounted) toast(context, 'This is not a valid backup file');
                        }
                      },
                      icon: const Icon(Icons.upload_file, size: 20),
                      label: const Text('Load file'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text('${store.customers.length} customers · ${store.orders.length} orders · received ${rs(received)}',
                    style: mono(size: 12, weight: FontWeight.w600, color: muted(context))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
