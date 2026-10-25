import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'store.dart';

const Color brand = Color(0xFFA3172F);

/// Status colours (background, text) that work in light and dark.
(Color, Color) statusColors(BuildContext context, String status) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (status) {
    case 'cutting':
      return dark ? (const Color(0xFF3A2C14), const Color(0xFFF0B04E)) : (const Color(0xFFFBECD2), const Color(0xFFA56200));
    case 'silai':
      return dark ? (const Color(0xFF3A1E24), const Color(0xFFE0566C)) : (const Color(0xFFF6E3E6), brand);
    case 'ready':
      return dark ? (const Color(0xFF173326), const Color(0xFF5CC98F)) : (const Color(0xFFDCF1E5), const Color(0xFF1D7A4C));
    case 'done':
      return dark ? (const Color(0xFF232A34), const Color(0xFF9AA5B4)) : (const Color(0xFFE4E8ED), const Color(0xFF5D6878));
    case 'late':
      return dark ? (const Color(0xFF3C1C1F), const Color(0xFFF07A80)) : (const Color(0xFFFBE0E1), const Color(0xFFB4232C));
    default:
      return dark ? (const Color(0xFF1A2A40), const Color(0xFF7FB0F5)) : (const Color(0xFFE0EAF8), const Color(0xFF2A5EA8));
  }
}

class Pill extends StatelessWidget {
  final String text;
  final String kind;
  const Pill(this.text, this.kind, {super.key});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusColors(context, kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

Widget dueLabel(BuildContext context, Order o) {
  if (o.status == 'done') return const Pill('Delivered', 'done');
  final n = daysFromToday(o.delivery);
  if (n == null) return const SizedBox.shrink();
  if (n < 0) return Pill('${-n} din late', 'late');
  if (n == 0) return const Pill('Aaj', 'cutting');
  if (n == 1) return const Pill('Kal', 'new');
  return Text(fmtDate(o.delivery), style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant));
}

class OrderTile extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const OrderTile({super.key, required this.order, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = store.customerById(order.customerId);
    final name = c?.name ?? (order.customerName.isEmpty ? 'Customer' : order.customerName);
    final sub = StringBuffer('${order.suits} suit${order.suits > 1 ? 's' : ''}');
    if (order.type.isNotEmpty) sub.write(' · ${order.type}');
    if (order.due > 0) sub.write(' · baqaya ${rs(order.due)}');
    return ListTile(
      onTap: onTap,
      leading: SerialBadge(c?.serial),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(sub.toString()),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Pill(statusLabel[order.status] ?? 'Naya', order.status),
          const SizedBox(height: 4),
          dueLabel(context, order),
        ],
      ),
    );
  }
}

class SerialBadge extends StatelessWidget {
  final int? serial;
  const SerialBadge(this.serial, {super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text('#${serial ?? '–'}',
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

/// White card with a thin border — used to group list rows.
class ListCard extends StatelessWidget {
  final List<Widget> children;
  const ListCard({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, color: cs.outlineVariant));
      items.add(children[i]);
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String text;
  final Widget? action;
  const EmptyNote(this.text, {super.key, this.action});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ]),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontSize: 13,
        letterSpacing: .8,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(children: [
        Expanded(child: Text(text.toUpperCase(), style: style)),
        if (trailing != null) Text(trailing!, style: style),
      ]),
    );
  }
}

class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final bool alert;
  final VoidCallback? onTap;
  const StatTile({super.key, required this.value, required this.label, this.alert = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: alert ? statusColors(context, 'late').$2 : cs.onSurface)),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

/// Two-column grid of stat tiles.
class StatGrid extends StatelessWidget {
  final List<Widget> tiles;
  const StatGrid(this.tiles, {super.key});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(Row(children: [
        Expanded(child: tiles[i]),
        const SizedBox(width: 10),
        Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
      ]));
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, 'Copy ho gaya');
}

Future<void> openWhatsApp(BuildContext context, String phone, String text) async {
  final n = waNumber(phone);
  if (n.isEmpty) {
    toast(context, 'Is customer ka phone number nahi hai');
    return;
  }
  final uri = Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(text)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) toast(context, 'WhatsApp nahi khula');
}

Future<bool> confirmDelete(BuildContext context, String title, String body) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nahi')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: statusColors(context, 'late').$2),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Haan, delete'),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Choice chips that can be un-selected (tap again to clear).
class ChoiceRow extends StatelessWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool allowClear;
  const ChoiceRow({super.key, required this.options, required this.value, required this.onChanged, this.allowClear = true});
  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final o in options)
        ChoiceChip(
          label: Text(o),
          selected: o == value,
          onSelected: (sel) => onChanged(sel ? o : (allowClear ? '' : o)),
        ),
    ]);
  }
}
