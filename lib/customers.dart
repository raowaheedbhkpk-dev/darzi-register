import 'package:flutter/material.dart';

import 'models.dart';
import 'orders.dart';
import 'store.dart';
import 'widgets.dart';

// ======================= CUSTOMERS LIST =======================
class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});
  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final query = q.trim().toLowerCase();
    final digits = query.replaceAll(RegExp(r'\D'), '');
    final list = store.customers.where((c) {
      if (query.isEmpty) return true;
      if (c.name.toLowerCase().contains(query)) return true;
      if (c.serial.toString() == query) return true;
      if (digits.length >= 3 && c.phone.replaceAll(RegExp(r'\D'), '').contains(digits)) return true;
      return false;
    }).toList()
      ..sort((a, b) => b.serial.compareTo(a.serial));

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerFormScreen())),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Naya'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Naam, phone ya serial number'),
            onChanged: (v) => setState(() => q = v),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            EmptyNote(store.customers.isEmpty
                ? 'Abhi koi customer nahi.\nPehle customer ka naap likhne ke liye "Naya" dabayein.'
                : 'Is naam ya number ka koi customer nahi mila.')
          else
            ListCard(children: [
              for (final c in list)
                ListTile(
                  leading: SerialBadge(c.serial),
                  title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(c.phone.isEmpty ? 'phone nahi' : c.phone),
                  trailing: _openCount(c.id) > 0 ? Pill('${_openCount(c.id)} order', 'silai') : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerScreen(customerId: c.id))),
                ),
            ]),
        ],
      ),
    );
  }

  int _openCount(String id) => store.orders.where((o) => o.customerId == id && o.status != 'done').length;
}

// ======================= CUSTOMER DETAIL (register slip) =======================
String slipText(Customer c) {
  final lines = <String>[];
  if (store.shopName.isNotEmpty) lines.add(store.shopName);
  lines.add('Naap — ${c.name} (Serial ${c.serial})');
  for (final f in [...measFields, ...boxFields]) {
    final v = c.m[f.k];
    if (v != null && v.isNotEmpty) lines.add('${f.en}: $v');
  }
  if (c.notes.isNotEmpty) lines.add('Tafseel: ${c.notes}');
  return lines.join('\n');
}

class CustomerScreen extends StatelessWidget {
  final String customerId;
  const CustomerScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final c = store.customerById(customerId);
        if (c == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Customer nahi mila')));
        }
        final orders = store.orders.where((o) => o.customerId == c.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(c.name, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'Naap badlein',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerFormScreen(customerId: c.id))),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              RegisterSlip(customer: c),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderFormScreen(customerId: c.id))),
                  icon: const Icon(Icons.add),
                  label: const Text('Naya order'),
                ),
                OutlinedButton.icon(
                  onPressed: () => copyText(context, slipText(c)),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Naap copy'),
                ),
                if (c.phone.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => openWhatsApp(context, c.phone, slipText(c)),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('WhatsApp par naap'),
                  ),
              ]),
              SectionTitle('Orders', trailing: '${orders.length}'),
              if (orders.isEmpty)
                const EmptyNote('Is customer ka abhi koi order nahi.')
              else
                ListCard(children: [
                  for (final o in orders)
                    OrderTile(
                      order: o,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderFormScreen(orderId: o.id))),
                    ),
                ]),
              const SizedBox(height: 12),
              Text('Customer bana: ${fmtMillis(c.createdAt)} · Naap update: ${fmtMillis(c.updatedAt)}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        );
      },
    );
  }
}

/// Measurement card styled like the red-bordered register page.
class RegisterSlip extends StatelessWidget {
  final Customer customer;
  const RegisterSlip({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final red = cs.primary;
    final c = customer;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: red, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              if (c.phone.isNotEmpty || c.address.isNotEmpty)
                Text([c.phone, c.address].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: red), borderRadius: BorderRadius.circular(4)),
            child: Text('Serial ${c.serial}', style: TextStyle(color: red, fontWeight: FontWeight.w700, fontFamily: 'monospace', fontSize: 13)),
          ),
        ]),
        const Divider(height: 20),
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth > 480 ? 3 : 2;
          final w = (box.maxWidth - (cols - 1) * 16) / cols;
          return Wrap(spacing: 16, children: [
            for (final f in measFields) SizedBox(width: w, child: _MeasLine(f: f, value: c.m[f.k] ?? '')),
          ]);
        }),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 2 * 8) / 3;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in boxFields)
              Container(
                width: w,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(6)),
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    color: red,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(f.ur, textAlign: TextAlign.center, textDirection: TextDirection.rtl,
                        style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text((c.m[f.k] ?? '').isEmpty ? '–' : c.m[f.k]!,
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 17)),
                  ),
                ]),
              ),
          ]);
        }),
        if (c.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('IZAFI TAFSEEL', style: TextStyle(fontSize: 11, letterSpacing: .6, color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(c.notes),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _MeasLine extends StatelessWidget {
  final MeasField f;
  final String value;
  const _MeasLine({required this.f, required this.value});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant, style: BorderStyle.solid))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.ur, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 15)),
            Text(f.en.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: .5, color: cs.onSurfaceVariant)),
          ]),
        ),
        Text(value.isEmpty ? '—' : value,
            style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: value.isEmpty ? cs.outlineVariant : cs.onSurface)),
      ]),
    );
  }
}

// ======================= CUSTOMER FORM =======================
class CustomerFormScreen extends StatefulWidget {
  final String? customerId;
  const CustomerFormScreen({super.key, this.customerId});
  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  Customer? existing;
  final serial = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final notes = TextEditingController();
  final pockets = TextEditingController();
  final Map<String, TextEditingController> meas = {};
  final Map<String, FocusNode> focus = {};
  String ghera = '';
  String collar = '';
  TextEditingController? activeMeas;

  static const _numeric = ['qameez', 'shirt', 'waistcoat', 'bazoo', 'teera', 'gala', 'chhati', 'kamar', 'shalwar', 'paincha', 'front', 'side', 'hip', 'cuff', 'plate'];

  @override
  void initState() {
    super.initState();
    existing = widget.customerId == null ? null : store.customerById(widget.customerId!);
    final c = existing;
    serial.text = '${c?.serial ?? store.nextSerial()}';
    name.text = c?.name ?? '';
    phone.text = c?.phone ?? '';
    address.text = c?.address ?? '';
    notes.text = c?.notes ?? '';
    pockets.text = c?.m['pockets'] ?? '';
    ghera = c?.m['ghera'] ?? '';
    collar = c?.m['collar'] ?? '';
    for (final k in _numeric) {
      final ctl = TextEditingController(text: c?.m[k] ?? '');
      final fn = FocusNode();
      fn.addListener(() {
        if (!mounted) return;
        setState(() {
          if (fn.hasFocus) {
            activeMeas = ctl;
          } else if (activeMeas == ctl) {
            activeMeas = null;
          }
        });
      });
      meas[k] = ctl;
      focus[k] = fn;
    }
  }

  @override
  void dispose() {
    for (final c in [serial, name, phone, address, notes, pockets, ...meas.values]) {
      c.dispose();
    }
    for (final f in focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _addFraction(String fr) {
    final ctl = activeMeas;
    if (ctl == null) return;
    var t = ctl.text;
    if (fr == '⌫') {
      t = t.isEmpty ? t : t.substring(0, t.length - 1);
    } else {
      t = t.replaceAll(RegExp(r'[¼½¾]$'), '') + fr;
    }
    ctl.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }

  Future<void> _save() async {
    final n = name.text.trim();
    if (n.isEmpty) {
      toast(context, 'Naam likhna zaroori hai');
      return;
    }
    final s = int.tryParse(serial.text.trim()) ?? store.nextSerial();
    if (store.serialTaken(s, existing?.id ?? '')) {
      toast(context, 'Serial $s pehle se kisi aur ka hai');
      return;
    }
    final m = <String, String>{};
    meas.forEach((k, ctl) {
      final v = ctl.text.trim();
      if (v.isNotEmpty) m[k] = v;
    });
    if (pockets.text.trim().isNotEmpty) m['pockets'] = pockets.text.trim();
    if (ghera.isNotEmpty) m['ghera'] = ghera;
    if (collar.isNotEmpty) m['collar'] = collar;
    final now = DateTime.now().millisecondsSinceEpoch;
    final c = Customer(
      id: existing?.id ?? newId(),
      serial: s,
      name: n,
      phone: phone.text.trim(),
      address: address.text.trim(),
      notes: notes.text.trim(),
      m: m,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await store.putCustomer(c);
    if (!mounted) return;
    toast(context, 'Save ho gaya');
    if (existing != null) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CustomerScreen(customerId: c.id)));
    }
  }

  Future<void> _delete() async {
    final c = existing;
    if (c == null) return;
    final ok = await confirmDelete(context, 'Customer delete karein?', '${c.name} aur iske saare orders mit jayenge.');
    if (!ok) return;
    await store.deleteCustomer(c.id);
    if (!mounted) return;
    toast(context, 'Delete ho gaya');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Widget _measField(MeasField f) {
    return TextField(
      controller: meas[f.k],
      focusNode: focus[f.k],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 17),
      decoration: InputDecoration(labelText: '${f.en}  ${f.ur}'),
    );
  }

  Widget _grid(List<Widget> items) {
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth > 480 ? 3 : 2;
      final w = (box.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final i in items) SizedBox(width: w, child: i)]);
    });
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: .8, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant);
    final mainMeas = measFields.where((f) => _numeric.contains(f.k)).toList();
    final boxMeas = boxFields.where((f) => _numeric.contains(f.k)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'Naya customer' : 'Naap badlein')),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _section('Customer', [
                Row(children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: serial,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Serial no.'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone', hintText: '03xx-xxxxxxx'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Naam  نام'),
                ),
                const SizedBox(height: 12),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Ilaqa / pata (optional)')),
              ]),
              _section('Naap (inch)', [
                _grid([for (final f in mainMeas) _measField(f)]),
                const SizedBox(height: 14),
                Text('Ghera  گھیرا', style: label),
                const SizedBox(height: 6),
                ChoiceRow(options: gheraOptions, value: ghera, onChanged: (v) => setState(() => ghera = v)),
                const SizedBox(height: 14),
                TextField(
                  controller: pockets,
                  decoration: const InputDecoration(labelText: 'Pockets  پاکٹس', hintText: 'maslan: 2 side, 1 front'),
                ),
              ]),
              _section('Design', [
                _grid([for (final f in boxMeas) _measField(f)]),
                const SizedBox(height: 14),
                Text('Collar / Bain  کالر/بین', style: label),
                const SizedBox(height: 6),
                ChoiceRow(options: collarOptions, value: collar, onChanged: (v) => setState(() => collar = v)),
                const SizedBox(height: 14),
                TextField(
                  controller: notes,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Izafi tafseel  اضافی تفصیل', hintText: 'maslan: saamne patti, sawa 2 chori bain'),
                ),
              ]),
              FilledButton(onPressed: _save, child: Text(existing == null ? 'Customer save karein' : 'Save karein')),
              if (existing != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: statusColors(context, 'late').$2),
                  onPressed: _delete,
                  child: const Text('Customer delete karein'),
                ),
              ],
            ],
          ),
        ),
        if (activeMeas != null) TextFieldTapRegion(child: _FractionBar(onTap: _addFraction)),
      ]),
    );
  }
}

/// Sits just above the keyboard while a measurement box is focused.
class _FractionBar extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _FractionBar({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.inverseSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Jorein:', style: TextStyle(color: cs.onInverseSurface, fontSize: 12)),
          const SizedBox(width: 8),
          for (final f in ['¼', '½', '¾', '⌫'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 54,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => onTap(f),
                  child: Text(f, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
