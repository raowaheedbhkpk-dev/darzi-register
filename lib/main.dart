import 'dart:convert';

import 'package:flutter/material.dart';

import 'customers.dart';
import 'drive.dart';
import 'models.dart';
import 'orders.dart';
import 'store.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  store.load();
  runApp(const DarziApp());
}

class DarziApp extends StatelessWidget {
  const DarziApp({super.key});

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: b);
    final dark = b == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: dark ? const Color(0xFFE0566C) : brand),
      scaffoldBackgroundColor: dark ? const Color(0xFF12161C) : const Color(0xFFEEF1F4),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF1B2129) : brand,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF1B2129) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: dark ? const Color(0xFF323B47) : const Color(0xFFD3D9E1)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1B2129) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darzi Register',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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
    // Like WhatsApp: when the shop closes the app, send changes to Drive.
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
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ======================= HOME =======================
class HomeTab extends StatelessWidget {
  final void Function(String filter) onOpenOrders;
  const HomeTab({super.key, required this.onOpenOrders});

  @override
  Widget build(BuildContext context) {
    final open = store.orders.where((o) => o.status != 'done').toList();
    final todayDue = open.where((o) => daysFromToday(o.delivery) == 0 && o.status != 'ready').length;
    final late = open.where(store.isLate).length;
    final ready = open.where((o) => o.status == 'ready').length;
    final baqaya = store.orders.fold<num>(0, (s, o) => s + o.due);
    final upcoming = open.where((o) => o.status != 'ready').toList()
      ..sort((a, b) => (a.delivery.isEmpty ? '9' : a.delivery).compareTo(b.delivery.isEmpty ? '9' : b.delivery));

    return Scaffold(
      appBar: AppBar(
        title: Text(store.shopName.isEmpty ? 'Darzi Register' : store.shopName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  store.driveBusy
                      ? Icons.cloud_sync
                      : store.driveOn && store.driveError.isEmpty
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(store.lastBackup == 0 ? 'Backup nahi' : agoText(store.lastBackup),
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ]),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (store.needsBackup) ...[
            BackupBanner(),
            const SizedBox(height: 12),
          ],
          StatGrid([
            StatTile(value: '$todayDue', label: 'Aaj ki delivery', onTap: () => onOpenOrders('today')),
            StatTile(value: '$late', label: 'Late orders', alert: late > 0, onTap: () => onOpenOrders('late')),
            StatTile(value: '$ready', label: 'Tayyar, lene nahi aaye', onTap: () => onOpenOrders('ready')),
            StatTile(value: rs(baqaya), label: 'Baqaya raqam', onTap: () => onOpenOrders('due')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerFormScreen())),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Naya customer'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderFormScreen())),
                icon: const Icon(Icons.add),
                label: const Text('Naya order'),
              ),
            ),
          ]),
          SectionTitle('Aane wali deliveries', trailing: '${open.length} khule'),
          if (upcoming.isEmpty)
            const EmptyNote('Koi khula order nahi.\nCustomer kholein aur "Naya order" dabayein.')
          else
            ListCard(children: [
              for (final o in upcoming.take(10))
                OrderTile(
                  order: o,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderFormScreen(orderId: o.id))),
                ),
            ]),
        ],
      ),
    );
  }
}

class BackupBanner extends StatelessWidget {
  const BackupBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusColors(context, 'cutting');
    final text = store.driveOn
        ? 'Drive backup ruka hua hai: ${store.driveError}'
        : store.lastBackup == 0
            ? 'Google Drive auto backup band hai. Phone kho gaya to data bhi chala jayega.'
            : 'Aakhri backup ${agoText(store.lastBackup)} pehle. ${store.changes} nayi tabdeeliyan abhi Drive par nahi hain.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: TextStyle(color: fg, fontSize: 14)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: fg, side: BorderSide(color: fg)),
          onPressed: () => store.driveOn ? driveBackupNow(context) : connectDriveFlow(context),
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: Text(store.driveOn ? 'Dobara koshish karein' : 'Google Drive auto backup chalu karein'),
        ),
      ]),
    );
  }
}

Future<void> driveBackupNow(BuildContext context) async {
  try {
    await store.backupToDrive();
    if (context.mounted) toast(context, 'Drive par backup ho gaya');
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
      toast(context, store.driveError.isEmpty ? 'Drive jud gaya. Ab backup khud hota rahega.' : store.driveError);
      return;
    }
    int count = 0;
    try {
      final j = jsonDecode(remote.json);
      if (j is Map && j['customers'] is List) count = (j['customers'] as List).length;
    } catch (_) {}
    final when = remote.modified == null ? '' : ' (${fmtMillis(remote.modified!.millisecondsSinceEpoch)})';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Drive par backup mila'),
        content: Text('Is Google account mein $count customers ka backup hai$when.\n\nKya ye data is phone mein wapas laein? Phone ka mojooda data bhi saath rahega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abhi nahi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Haan, restore karein')),
        ],
      ),
    );
    if (ok == true) {
      final n = await store.restoreJson(remote.json);
      if (context.mounted) toast(context, '$n customers Drive se wapas aa gaye');
    } else if (store.customers.isNotEmpty) {
      await store.backupToDrive(silent: true);
    }
  } catch (e) {
    if (context.mounted) toast(context, friendlyDriveError(e));
  }
}

Future<void> doBackup(BuildContext context) async {
  try {
    final ok = await store.shareBackup();
    if (ok && context.mounted) toast(context, 'Backup bhej diya');
  } catch (e) {
    if (context.mounted) toast(context, 'Backup nahi hua: $e');
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
    final cs = Theme.of(context).colorScheme;
    final received = store.orders.fold<num>(0, (s, o) => s + o.advance);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const SectionTitle('Is mahine'),
          StatGrid([
            StatTile(value: '${month.length}', label: 'Naye orders'),
            StatTile(value: '${month.fold<int>(0, (s, o) => s + o.suits)}', label: 'Suits'),
            StatTile(value: rs(month.fold<num>(0, (s, o) => s + o.price)), label: 'Kul silai'),
            StatTile(value: '${store.customers.length}', label: 'Kul customers'),
          ]),
          const SectionTitle('Dukaan'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Dukaan ka naam', hintText: 'maslan: Bilal Tailors')),
                const SizedBox(height: 12),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Dukaan ka phone')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    await store.saveShop(name.text.trim(), phone.text.trim());
                    if (context.mounted) toast(context, 'Save ho gaya');
                  },
                  child: const Text('Save karein'),
                ),
                const SizedBox(height: 6),
                Text('Dukaan ka naam WhatsApp messages aur naap slip par aata hai.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ]),
            ),
          ),
          const SectionTitle('Google Drive auto backup'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(
                    store.driveOn ? (store.driveError.isEmpty ? Icons.cloud_done : Icons.cloud_off) : Icons.cloud_outlined,
                    color: store.driveOn && store.driveError.isEmpty ? statusColors(context, 'ready').$2 : cs.outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(store.driveOn ? 'Chalu hai' : 'Band hai', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      if (store.driveOn) Text(store.driveEmail, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                  if (store.driveBusy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
                const SizedBox(height: 10),
                Text(
                  store.driveOn
                      ? 'Har tabdeeli ke 10 second baad, aur app band karte waqt, data khud Google Drive par chala jata hai. '
                          'Aakhri backup: ${store.lastDrive == 0 ? 'abhi nahi hua' : '${agoText(store.lastDrive)} pehle'}.'
                      : 'Google account se jorein. Phir WhatsApp ki tarah saara data khud Drive par save hota rahega, aur naye phone par wapas aa jayega.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                if (store.driveError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(store.driveError, style: TextStyle(fontSize: 13, color: statusColors(context, 'late').$2)),
                ],
                const SizedBox(height: 12),
                if (!store.driveOn)
                  FilledButton.icon(
                    onPressed: () => connectDriveFlow(context),
                    icon: const Icon(Icons.add_to_drive),
                    label: const Text('Google Drive se jorein'),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: store.driveBusy ? null : () => driveBackupNow(context),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Abhi backup karein'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: store.driveBusy
                        ? null
                        : () async {
                            try {
                              final n = await store.restoreFromDrive();
                              if (!context.mounted) return;
                              toast(context, n == null ? 'Drive par koi backup nahi mila' : '$n customers Drive se wapas aa gaye');
                            } catch (e) {
                              if (context.mounted) toast(context, friendlyDriveError(e));
                            }
                          },
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Drive se restore karein'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await store.disconnectDrive();
                      if (context.mounted) toast(context, 'Drive alag kar diya');
                    },
                    child: const Text('Google account alag karein'),
                  ),
                ],
              ]),
            ),
          ),
          const SectionTitle('Backup file (extra)'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Backup ki file WhatsApp, email ya kisi aur jagah bhej sakte hain, ya file se data wapas la sakte hain.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => doBackup(context),
                  icon: const Icon(Icons.share),
                  label: const Text('Backup file share karein'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final n = await store.restoreBackup();
                      if (n != null && context.mounted) toast(context, '$n customers wapas aa gaye');
                    } catch (e) {
                      if (context.mounted) toast(context, 'Ye file sahi backup nahi hai');
                    }
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Backup file se wapas laein'),
                ),
                const SizedBox(height: 8),
                Text('${store.customers.length} customers · ${store.orders.length} orders · kul mila ${rs(received)}',
                    style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: cs.onSurfaceVariant)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
