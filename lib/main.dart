import 'package:flutter/material.dart';

import 'customers.dart';
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

class _ShellState extends State<Shell> {
  int tab = 0;
  String orderFilter = 'open';

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
          const CustomersTab(),
          OrdersTab(filter: orderFilter, onFilter: (f) => setState(() => orderFilter = f)),
          const SettingsTab(),
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
              child: Text(store.lastBackup == 0 ? 'Backup nahi' : 'Backup: ${agoText(store.lastBackup)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
    final text = store.lastBackup == 0
        ? 'Abhi tak Google Drive par backup nahi liya. Phone kho gaya to data bhi chala jayega.'
        : 'Aakhri backup ${agoText(store.lastBackup)} pehle. ${store.changes} nayi tabdeeliyan abhi Drive par nahi hain.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: TextStyle(color: fg, fontSize: 14)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: fg, side: BorderSide(color: fg)),
          onPressed: () => doBackup(context),
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: const Text('Abhi Drive par backup lein'),
        ),
      ]),
    );
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
          const SectionTitle('Google Drive backup'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(Icons.circle, size: 12, color: store.lastBackup == 0 ? cs.outline : statusColors(context, 'ready').$2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      store.lastBackup == 0 ? 'Abhi tak backup nahi liya' : 'Aakhri backup: ${agoText(store.lastBackup)} pehle',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('"Drive par backup" dabayein, phir list mein Drive chunein aur Save dabayein. Hafte mein ek dafa zaroor karein.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => doBackup(context),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Drive par backup'),
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
                Text('Naye phone par: app install karein, phir "Backup file se wapas laein" dabayein aur Drive se apni backup file chunein.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
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
