import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';
import 'orders.dart';
import 'store.dart';
import 'theme.dart';
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
        label: const Text('New customer'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, phone or serial no.'),
            onChanged: (v) => setState(() => q = v),
          ),
          SectionTitle(query.isEmpty ? 'All customers' : 'Results', trailing: '${list.length}'),
          if (list.isEmpty)
            EmptyNote(
              store.customers.isEmpty
                  ? 'No customers yet.\nTap "New customer" to record the first measurements.'
                  : 'No customer matches that name or number.',
              icon: Icons.person_search_outlined,
            )
          else
            ListCard(children: [
              for (final c in list)
                ListTile(
                  leading: Initials(c.name),
                  title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(c.phone.isEmpty ? 'No phone' : c.phone),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('#${c.serial}', style: mono(size: 13, color: muted(context))),
                    if (_openCount(c.id) > 0) ...[const SizedBox(height: 4), Pill('${_openCount(c.id)} open', 'silai')],
                  ]),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerScreen(customerId: c.id))),
                ),
            ]),
        ],
      ),
    );
  }

  int _openCount(String id) => store.orders.where((o) => o.customerId == id && o.status != 'done').length;
}

// ======================= CUSTOMER DETAIL =======================
/// Measurement slip as text (Urdu labels), for copy / WhatsApp.
String slipText(Customer c) {
  final lines = <String>[];
  if (store.shopName.isNotEmpty) lines.add(store.shopName);
  lines.add('ناپ — ${c.name} (سیریل ${c.serial})');
  for (final f in [...measFields, ...boxFields]) {
    final v = c.m[f.k];
    if (v != null && v.isNotEmpty) lines.add('${f.ur}: ${legacyUrdu[v] ?? v}');
  }
  if (c.notes.isNotEmpty) lines.add('اضافی تفصیل: ${c.notes}');
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
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Customer not found')));
        }
        final orders = store.orders.where((o) => o.customerId == c.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final paid = orders.fold<num>(0, (s, o) => s + o.advance);
        final due = orders.fold<num>(0, (s, o) => s + o.due);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Customer'),
            actions: [
              IconButton(
                tooltip: 'Edit measurements',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerFormScreen(customerId: c.id))),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              Row(children: [
                Initials(c.name, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 2),
                    Text([if (c.phone.isNotEmpty) c.phone, if (c.address.isNotEmpty) c.address].join(' · ').ifEmpty('No phone'),
                        style: GoogleFonts.manrope(fontSize: 14, color: muted(context), fontWeight: FontWeight.w500)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _MiniStat('${orders.length}', 'Orders')),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(rs(paid), 'Paid')),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(rs(due), 'Due', alert: due > 0)),
              ]),
              const SizedBox(height: 16),
              RegisterSlip(customer: c),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderFormScreen(customerId: c.id))),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('New order'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => copyText(context, slipText(c)),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                if (c.phone.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openWhatsApp(context, c.phone, slipText(c)),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ]),
              SectionTitle('Order history', trailing: '${orders.length}'),
              if (orders.isEmpty)
                const EmptyNote('No orders for this customer yet.', icon: Icons.receipt_long_outlined)
              else
                ListCard(children: [
                  for (final o in orders)
                    OrderTile(
                      order: o,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderFormScreen(orderId: o.id))),
                    ),
                ]),
              const SizedBox(height: 14),
              Text('Added ${fmtMillis(c.createdAt)} · Measurements updated ${fmtMillis(c.updatedAt)}',
                  textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 12, color: muted(context))),
            ],
          ),
        );
      },
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final bool alert;
  const _MiniStat(this.value, this.label, {this.alert = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: surface(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: line(context))),
      child: Column(children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: mono(size: 15, color: alert ? statusColors(context, 'late').$2 : null))),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.manrope(fontSize: 12, color: muted(context), fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Measurement card styled like the red-bordered register page, labels in Urdu.
class RegisterSlip extends StatelessWidget {
  final Customer customer;
  const RegisterSlip({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final red = wine(context);
    final ink = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: red, width: 2),
        boxShadow: [BoxShadow(color: AppColors.wine.withValues(alpha: isDark(context) ? 0 : .08), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: red,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(textDirection: TextDirection.rtl, children: [
            Text('ناپ', textDirection: TextDirection.rtl, style: urdu(size: 18, weight: FontWeight.w700, color: Theme.of(context).colorScheme.onPrimary, height: 1.7)),
            const Spacer(),
            Text('Serial #${c.serial}', style: mono(size: 13, color: Theme.of(context).colorScheme.onPrimary)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth > 480 ? 3 : 2;
              final w = (box.maxWidth - (cols - 1) * 18) / cols;
              return Wrap(
                spacing: 18,
                textDirection: TextDirection.rtl,
                children: [
                  for (final f in measFields) SizedBox(width: w, child: _slipLine(context, f, _show(c.m[f.k]), ink)),
                ],
              );
            }),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, box) {
              final w = (box.maxWidth - 2 * 8) / 3;
              return Wrap(spacing: 8, runSpacing: 8, textDirection: TextDirection.rtl, children: [
                for (final f in boxFields)
                  Container(
                    width: w,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(border: Border.all(color: line(context)), borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      Container(
                        width: double.infinity,
                        color: isDark(context) ? AppColors.wine.withValues(alpha: .4) : AppColors.goldSoft,
                        child: Text(f.ur, textAlign: TextAlign.center, textDirection: TextDirection.rtl,
                            style: urdu(size: 13.5, color: isDark(context) ? AppColors.goldSoft : AppColors.wineDeep, height: 1.6)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _show(c.m[f.k]).isEmpty ? '–' : _show(c.m[f.k]),
                            style: _hasUrdu(_show(c.m[f.k])) ? urdu(size: 14, color: ink, height: 1.5) : mono(size: 17, color: ink),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ]);
            }),
            if (c.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('اضافی تفصیل', textDirection: TextDirection.rtl, style: urdu(size: 13, color: muted(context), height: 1.7)),
                  Text(c.notes,
                      textDirection: _hasUrdu(c.notes) ? TextDirection.rtl : TextDirection.ltr,
                      textAlign: _hasUrdu(c.notes) ? TextAlign.right : TextAlign.left,
                      style: _hasUrdu(c.notes) ? urdu(size: 15, color: ink) : GoogleFonts.manrope(fontSize: 14, color: ink, height: 1.4)),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

bool _hasUrdu(String? s) => s != null && RegExp(r'[؀-ۿ]').hasMatch(s);

/// Value as shown on the slip (old Roman entries become Urdu).
String _show(String? v) => (v == null || v.isEmpty) ? '' : (legacyUrdu[v] ?? v);

Widget _slipLine(BuildContext context, MeasField f, String v, Color ink) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 2),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line(context)))),
    child: Row(textDirection: TextDirection.rtl, children: [
      Text(f.ur, textDirection: TextDirection.rtl, style: urdu(size: 16, color: muted(context))),
      const Spacer(),
      Flexible(
        child: Text(
          v.isEmpty ? '—' : v,
          textDirection: _hasUrdu(v) ? TextDirection.rtl : TextDirection.ltr,
          overflow: TextOverflow.ellipsis,
          style: _hasUrdu(v) ? urdu(size: 15, color: ink) : mono(size: 17, color: v.isEmpty ? line(context) : ink),
        ),
      ),
    ]),
  );
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
    ghera = legacyUrdu[c?.m['ghera']] ?? c?.m['ghera'] ?? '';
    collar = legacyUrdu[c?.m['collar']] ?? c?.m['collar'] ?? '';
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
      toast(context, 'Please enter the customer name');
      return;
    }
    final s = int.tryParse(serial.text.trim()) ?? store.nextSerial();
    if (store.serialTaken(s, existing?.id ?? '')) {
      toast(context, 'Serial $s already belongs to another customer');
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
    toast(context, 'Saved');
    if (existing != null) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CustomerScreen(customerId: c.id)));
    }
  }

  Future<void> _delete() async {
    final c = existing;
    if (c == null) return;
    final ok = await confirmDelete(context, 'Delete customer?', '${c.name} and all of their orders will be deleted.');
    if (!ok) return;
    await store.deleteCustomer(c.id);
    if (!mounted) return;
    toast(context, 'Customer deleted');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// One measurement box: Urdu label on top, big number input below.
  Widget _measField(MeasField f) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      UrduLabel(f.ur),
      TextField(
        controller: meas[f.k],
        focusNode: focus[f.k],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: mono(size: 19),
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 12)),
      ),
    ]);
  }

  Widget _grid(List<Widget> items) {
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth > 480 ? 4 : 3;
      final w = (box.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 6,
        textDirection: TextDirection.rtl,
        children: [for (final i in items) SizedBox(width: w, child: i)],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mainMeas = measFields.where((f) => _numeric.contains(f.k)).toList();
    final boxMeas = boxFields.where((f) => _numeric.contains(f.k)).toList();
    final ink = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'New customer' : 'Edit customer')),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              FormSection(title: 'Customer details', children: [
                Row(children: [
                  SizedBox(
                    width: 104,
                    child: TextField(
                      controller: serial,
                      keyboardType: TextInputType.number,
                      style: mono(size: 16),
                      decoration: const InputDecoration(labelText: 'Serial no.'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone', hintText: '03xx-xxxxxxx', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline, size: 20)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Area / address (optional)', prefixIcon: Icon(Icons.place_outlined, size: 20)),
                ),
              ]),
              FormSection(title: 'ناپ (انچ)', urduTitle: true, children: [
                _grid([for (final f in mainMeas) _measField(f)]),
                const SizedBox(height: 14),
                const UrduLabel('گھیرا'),
                const SizedBox(height: 4),
                ChoiceRow(options: gheraOptions, value: ghera, urduLabels: true, onChanged: (v) => setState(() => ghera = v)),
                const SizedBox(height: 14),
                const UrduLabel('پاکٹس'),
                TextField(
                  controller: pockets,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: urdu(size: 15, color: ink, height: 1.6),
                  decoration: InputDecoration(hintText: 'مثلاً: 2 سائیڈ، 1 فرنٹ', hintStyle: urdu(size: 14, color: muted(context), height: 1.6)),
                ),
              ]),
              FormSection(title: 'ڈیزائن', urduTitle: true, children: [
                _grid([for (final f in boxMeas) _measField(f)]),
                const SizedBox(height: 14),
                const UrduLabel('کالر / بین'),
                const SizedBox(height: 4),
                ChoiceRow(options: collarOptions, value: collar, urduLabels: true, onChanged: (v) => setState(() => collar = v)),
                const SizedBox(height: 14),
                const UrduLabel('اضافی تفصیل'),
                TextField(
                  controller: notes,
                  minLines: 3,
                  maxLines: 6,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: urdu(size: 15, color: ink, height: 1.8),
                  decoration: InputDecoration(hintText: 'مثلاً: سامنے پٹی، سوا 2 چوڑی بین', hintStyle: urdu(size: 14, color: muted(context), height: 1.6)),
                ),
              ]),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(existing == null ? 'Save customer' : 'Save changes'),
              ),
              if (existing != null) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: statusColors(context, 'late').$2),
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete customer'),
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
    return Material(
      color: AppColors.wineDeep,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final f in ['¼', '½', '¾', '⌫'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: SizedBox(
                width: 62,
                height: 44,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 44),
                    backgroundColor: f == '⌫' ? Colors.white.withValues(alpha: .14) : AppColors.gold,
                    foregroundColor: f == '⌫' ? Colors.white : AppColors.wineDeep,
                  ),
                  onPressed: () => onTap(f),
                  child: Text(f, style: mono(size: 21, weight: FontWeight.w800)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
