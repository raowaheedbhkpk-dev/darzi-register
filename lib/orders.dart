import 'package:flutter/material.dart';

import 'customers.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

// ======================= ORDERS LIST =======================
const _filters = [
  ('open', 'Khule'),
  ('today', 'Aaj'),
  ('late', 'Late'),
  ('ready', 'Tayyar'),
  ('due', 'Baqaya'),
  ('done', 'Delivered'),
  ('all', 'Sab'),
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Naya order'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in _filters)
              ChoiceChip(label: Text(f.$2), selected: filter == f.$1, onSelected: (_) => onFilter(f.$1)),
          ]),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const EmptyNote('Is list mein koi order nahi.')
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('${list.length} order${list.length > 1 ? 's' : ''}${total > 0 ? ' · baqaya ${rs(total)}' : ''}',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ),
            ListCard(children: [
              for (final o in list)
                OrderTile(
                  order: o,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderFormScreen(orderId: o.id))),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ======================= ORDER FORM =======================
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
      toast(context, 'Pehle customer chunein');
      return;
    }
    await store.putOrder(_build());
    if (!mounted) return;
    toast(context, 'Order save ho gaya');
    Navigator.pop(context);
  }

  Future<void> _advanceStatus() async {
    final i = statusKeys.indexOf(status);
    final next = statusKeys[(i + 1).clamp(0, statusKeys.length - 1).toInt()];
    setState(() => status = next);
    await store.putOrder(_build());
    if (!mounted) return;
    setState(() => existing = store.orderById(existing!.id));
    toast(context, '${statusLabel[next]} ho gaya');
  }

  Future<void> _fullPaid() async {
    advance.text = price.text;
    await store.putOrder(_build());
    if (!mounted) return;
    setState(() => existing = store.orderById(existing!.id));
    toast(context, 'Payment poori');
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(context, 'Order delete karein?', 'Ye order hamesha ke liye mit jayega.');
    if (!ok) return;
    await store.deleteOrder(existing!.id);
    if (!mounted) return;
    toast(context, 'Order delete ho gaya');
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
    final cs = Theme.of(context).colorScheme;
    final label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant);
    final c = store.customerById(customerId);
    final o = existing;
    final remaining = (_price - _advance) < 0 ? 0 : _price - _advance;

    if (store.customers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Naya order')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyNote(
            'Order se pehle customer ka naap save karein.',
            action: FilledButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CustomerFormScreen())),
              child: const Text('Naya customer'),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(o == null ? 'Naya order' : 'Order')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (o != null && c != null) ...[
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (o.status != 'done')
                FilledButton.icon(
                  style: o.status == 'ready'
                      ? FilledButton.styleFrom(backgroundColor: statusColors(context, 'ready').$2)
                      : null,
                  onPressed: _advanceStatus,
                  icon: Icon(o.status == 'ready' ? Icons.check_circle : Icons.arrow_forward),
                  label: Text(o.status == 'ready'
                      ? 'Customer le gaya'
                      : 'Agla qadam: ${statusLabel[statusKeys[statusKeys.indexOf(o.status) + 1]]}'),
                ),
              if (c.phone.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => openWhatsApp(context, c.phone, readyMessage(_build(), c)),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('WhatsApp: suit tayyar'),
                ),
            ]),
            const SizedBox(height: 14),
          ],
          _section('Customer', [
            InkWell(
              onTap: _pickCustomer,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Customer', suffixIcon: Icon(Icons.arrow_drop_down)),
                child: Text(c == null ? '— chunein —' : '#${c.serial} · ${c.name}${c.phone.isNotEmpty ? ' · ${c.phone}' : ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (c != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerScreen(customerId: c.id))),
                  icon: const Icon(Icons.straighten, size: 18),
                  label: const Text('Naap dekhein'),
                ),
              ),
          ]),
          _section('Kaam', [
            Row(children: [
              SizedBox(
                width: 100,
                child: TextField(controller: suits, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Suits')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Delivery date', suffixIcon: Icon(Icons.event)),
                    child: Text(delivery.isEmpty ? '—' : '${fmtDate(delivery)} ${parseIso(delivery)?.year ?? ''}'),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Text('Kapra / kism', style: label),
            const SizedBox(height: 6),
            ChoiceRow(options: orderTypes, value: type, onChanged: (v) => setState(() => type = v)),
            const SizedBox(height: 14),
            Text('Status', style: label),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in statusKeys)
                ChoiceChip(label: Text(statusLabel[s]!), selected: status == s, onSelected: (_) => setState(() => status = s)),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Is order ki tafseel', hintText: 'maslan: kapra customer ka, 2 jori butt…'),
            ),
          ]),
          _section('Paisay', [
            Row(children: [
              Expanded(
                child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kul silai (Rs)')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(controller: advance, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Advance / mila (Rs)')),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _money(context, rs(_price), 'Kul'),
              const SizedBox(width: 8),
              _money(context, rs(_advance), 'Mila'),
              const SizedBox(width: 8),
              _money(context, rs(remaining), 'Baqaya',
                  color: remaining > 0 ? statusColors(context, 'late').$2 : statusColors(context, 'ready').$2),
            ]),
            if (o != null && o.due > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _fullPaid,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Poori payment mil gayi'),
                ),
              ),
            ],
          ]),
          FilledButton(onPressed: _save, child: Text(o == null ? 'Order save karein' : 'Save karein')),
          if (o != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: statusColors(context, 'late').$2),
              onPressed: _delete,
              child: const Text('Order delete karein'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _money(BuildContext context, String v, String l, {Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(v, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 16, color: color)),
          ),
          Text(l, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
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
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Naam, phone ya serial'),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                return ListTile(
                  leading: SerialBadge(c.serial),
                  title: Text(c.name),
                  subtitle: c.phone.isEmpty ? null : Text(c.phone),
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
