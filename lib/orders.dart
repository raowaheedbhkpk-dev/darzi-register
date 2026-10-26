import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'customers.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

// ======================= ORDERS LIST =======================
const _filters = [
  ('open', 'Open'),
  ('today', 'Today'),
  ('late', 'Late'),
  ('ready', 'Ready'),
  ('due', 'Payment due'),
  ('done', 'Delivered'),
  ('all', 'All'),
];

class OrdersTab extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onFilter;
  const OrdersTab({super.key, required this.filter, required this.onFilter});

  bool _test(Order o) {
    switch (filter) {
      case 'today':
        return o.status != 'done' && daysFromToday(o.delivery) == 0;
      case 'late':
        return store.isLate(o);
      case 'ready':
        return o.status == 'ready';
      case 'due':
        return o.due > 0;
      case 'done':
        return o.status == 'done';
      case 'all':
        return true;
      default:
        return o.status != 'done';
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = store.orders.where(_test).toList();
    if (filter == 'done') {
      list.sort((a, b) => (b.deliveredAt ?? 0).compareTo(a.deliveredAt ?? 0));
    } else {
      list.sort((a, b) => (a.delivery.isEmpty ? '9' : a.delivery).compareTo(b.delivery.isEmpty ? '9' : b.delivery));
    }
    final total = list.fold<num>(0, (s, o) => s + o.due);

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New order'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                return ChoiceChip(label: Text(f.$2), selected: filter == f.$1, onSelected: (_) => onFilter(f.$1));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('${list.length} order${list.length == 1 ? '' : 's'}', trailing: total > 0 ? 'Due ${rs(total)}' : null),
              if (list.isEmpty)
                const EmptyNote('No orders in this list.', icon: Icons.receipt_long_outlined)
              else
                ListCard(children: [
                  for (final o in list)
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

// ======================= ORDER FORM =======================
/// WhatsApp message to the customer (kept in Roman Urdu for customers).
String readyMessage(Order o, Customer c) {
  final b = StringBuffer('Assalam o Alaikum ${c.name} sahib,\n');
  b.write('Aap ke ${o.suits} suit tayyar hain');
  if (store.shopName.isNotEmpty) b.write(' — ${store.shopName}');
  b.write('.');
  if (o.due > 0) b.write('\nBaqaya raqam: ${rs(o.due)}');
  b.write('\nShukriya!');
  return b.toString();
}

class OrderFormScreen extends StatefulWidget {
  final String? orderId;
  final String? customerId;
  const OrderFormScreen({super.key, this.orderId, this.customerId});
  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  Order? existing;
  String customerId = '';
  String type = '';
  String status = 'new';
  String delivery = '';
  final suits = TextEditingController(text: '1');
  final price = TextEditingController();
  final advance = TextEditingController();
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    existing = widget.orderId == null ? null : store.orderById(widget.orderId!);
    final o = existing;
    customerId = o?.customerId ?? widget.customerId ?? '';
    type = o?.type ?? '';
    status = o?.status ?? 'new';
    delivery = o?.delivery ?? isoDate(DateTime.now().add(const Duration(days: 7)));
    suits.text = '${o?.suits ?? 1}';
    price.text = o == null || o.price == 0 ? '' : '${o.price}';
    advance.text = o == null || o.advance == 0 ? '' : '${o.advance}';
    notes.text = o?.notes ?? '';
    price.addListener(_refresh);
    advance.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [suits, price, advance, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  num get _price => num.tryParse(price.text.trim()) ?? 0;
  num get _advance => num.tryParse(advance.text.trim()) ?? 0;

  Order _build() {
    final o = existing;
    final c = store.customerById(customerId);
    return Order(
      id: o?.id ?? newId(),
      customerId: customerId,
      customerName: c?.name ?? '',
      suits: (int.tryParse(suits.text.trim()) ?? 1).clamp(1, 999).toInt(),
      delivery: delivery,
      type: type,
      status: status,
      notes: notes.text.trim(),
      price: _price,
      advance: _advance,
      createdAt: o?.createdAt,
      deliveredAt: status == 'done' ? (o?.deliveredAt ?? DateTime.now().millisecondsSinceEpoch) : null,
    );
  }

  Future<void> _save() async {
    if (store.customerById(customerId) == null) {
      toast(context, 'Please choose a customer first');
      return;
    }
    await store.putOrder(_build());
    if (!mounted) return;
    toast(context, 'Order saved');
    Navigator.pop(context);
  }

  Future<void> _advanceStatus() async {
    final i = statusKeys.indexOf(status);
    final next = statusKeys[(i + 1).clamp(0, statusKeys.length - 1).toInt()];
    setState(() => status = next);
    await store.putOrder(_build());
    if (!mounted) return;
    setState(() => existing = store.orderById(existing!.id));
    toast(context, 'Marked as ${statusLabel[next]}');
  }

  Future<void> _fullPaid() async {
    advance.text = price.text;
    await store.putOrder(_build());
    if (!mounted) return;
    setState(() => existing = store.orderById(existing!.id));
    toast(context, 'Marked as fully paid');
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(context, 'Delete order?', 'This order will be removed permanently.');
    if (!ok) return;
    await store.deleteOrder(existing!.id);
    if (!mounted) return;
    toast(context, 'Order deleted');
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: parseIso(delivery) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      helpText: 'Delivery date',
    );
    if (d != null) setState(() => delivery = isoDate(d));
  }

  Future<void> _pickCustomer() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CustomerPicker(),
    );
    if (id != null) setState(() => customerId = id);
  }

  @override
  Widget build(BuildContext context) {
    final c = store.customerById(customerId);
    final o = existing;
    final remaining = (_price - _advance) < 0 ? 0 : _price - _advance;
    final label = GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: muted(context));

    if (store.customers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('New order')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyNote(
            'Save a customer\'s measurements before creating an order.',
            icon: Icons.straighten,
            action: FilledButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CustomerFormScreen())),
              child: const Text('New customer'),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(o == null ? 'New order' : 'Order')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          if (o != null) ...[
            _StatusTrack(status: o.status),
            const SizedBox(height: 12),
            if (o.status != 'done')
              FilledButton.icon(
                style: o.status == 'ready'
                    ? FilledButton.styleFrom(backgroundColor: statusColors(context, 'ready').$2, foregroundColor: Colors.white)
                    : null,
                onPressed: _advanceStatus,
                icon: Icon(o.status == 'ready' ? Icons.handshake_outlined : Icons.arrow_forward_rounded),
                label: Text(o.status == 'ready'
                    ? 'Customer collected it'
                    : 'Move to ${statusLabel[statusKeys[statusKeys.indexOf(o.status) + 1]]}'),
              ),
            if (c != null && c.phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => openWhatsApp(context, c.phone, readyMessage(_build(), c)),
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('WhatsApp: suit is ready'),
              ),
            ],
            const SizedBox(height: 16),
          ],
          FormSection(title: 'Customer', children: [
            InkWell(
              onTap: _pickCustomer,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: line(context)), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  c == null
                      ? Icon(Icons.person_search_outlined, color: muted(context))
                      : Initials(c.name, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: c == null
                        ? Text('Choose customer', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: muted(context)))
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15)),
                            Text('#${c.serial}${c.phone.isNotEmpty ? ' · ${c.phone}' : ''}', style: GoogleFonts.manrope(fontSize: 13, color: muted(context))),
                          ]),
                  ),
                  Icon(Icons.unfold_more, color: muted(context)),
                ]),
              ),
            ),
            if (c != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerScreen(customerId: c.id))),
                  icon: const Icon(Icons.straighten, size: 18),
                  label: const Text('View measurements'),
                ),
              ),
          ]),
          FormSection(title: 'Work', children: [
            Row(children: [
              SizedBox(
                width: 96,
                child: TextField(controller: suits, keyboardType: TextInputType.number, style: mono(size: 16), decoration: const InputDecoration(labelText: 'Suits')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Delivery date', suffixIcon: Icon(Icons.event_outlined)),
                    child: Text(delivery.isEmpty ? '—' : '${fmtDate(delivery)} ${parseIso(delivery)?.year ?? ''}',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text('Garment', style: label),
            const SizedBox(height: 8),
            ChoiceRow(options: orderTypes, value: type, onChanged: (v) => setState(() => type = v)),
            const SizedBox(height: 16),
            Text('Status', style: label),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in statusKeys)
                ChoiceChip(label: Text(statusLabel[s]!), selected: status == s, onSelected: (_) => setState(() => status = s)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Order notes', hintText: 'e.g. customer\'s own fabric, extra buttons…'),
            ),
          ]),
          FormSection(title: 'Payment', children: [
            Row(children: [
              Expanded(
                child: TextField(controller: price, keyboardType: TextInputType.number, style: mono(size: 16), decoration: const InputDecoration(labelText: 'Total (Rs)')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(controller: advance, keyboardType: TextInputType.number, style: mono(size: 16), decoration: const InputDecoration(labelText: 'Paid (Rs)')),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _money(context, rs(_price), 'Total'),
              const SizedBox(width: 8),
              _money(context, rs(_advance), 'Paid'),
              const SizedBox(width: 8),
              _money(context, rs(remaining), 'Due', color: remaining > 0 ? statusColors(context, 'late').$2 : statusColors(context, 'ready').$2),
            ]),
            if (o != null && o.due > 0) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _fullPaid,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Mark fully paid'),
              ),
            ],
          ]),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(o == null ? 'Save order' : 'Save changes'),
          ),
          if (o != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: statusColors(context, 'late').$2),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete order'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _money(BuildContext context, String v, String l, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: mono(size: 15, color: color))),
          const SizedBox(height: 2),
          Text(l, style: GoogleFonts.manrope(fontSize: 12, color: muted(context), fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Progress through New → Cutting → Stitching → Ready → Delivered.
class _StatusTrack extends StatelessWidget {
  final String status;
  const _StatusTrack({required this.status});
  @override
  Widget build(BuildContext context) {
    final idx = statusKeys.indexOf(status);
    final on = wine(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Row(children: [
          for (var i = 0; i < statusKeys.length; i++) ...[
            Expanded(
              child: Column(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: i <= idx ? on : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: i <= idx ? on : line(context), width: 2),
                  ),
                  child: Icon(statusIcon(statusKeys[i]), size: 15, color: i <= idx ? Theme.of(context).colorScheme.onPrimary : muted(context)),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(statusLabel[statusKeys[i]]!,
                      style: GoogleFonts.manrope(
                          fontSize: 11, fontWeight: i == idx ? FontWeight.w800 : FontWeight.w600, color: i <= idx ? on : muted(context))),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker();
  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final query = q.trim().toLowerCase();
    final list = store.customers
        .where((c) => query.isEmpty || c.name.toLowerCase().contains(query) || c.phone.contains(query) || '${c.serial}' == query)
        .toList()
      ..sort((a, b) => b.serial.compareTo(a.serial));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, phone or serial'),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                return ListTile(
                  leading: Initials(c.name, size: 38),
                  title: Text(c.name),
                  subtitle: Text('#${c.serial}${c.phone.isEmpty ? '' : ' · ${c.phone}'}'),
                  onTap: () => Navigator.pop(context, c.id),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
