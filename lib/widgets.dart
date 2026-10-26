import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Status colours (background, text) for light and dark.
(Color, Color) statusColors(BuildContext context, String status) {
  final dark = isDark(context);
  switch (status) {
    case 'cutting':
      return dark ? (const Color(0xFF3A2C14), const Color(0xFFF0B04E)) : (const Color(0xFFFBEBCF), const Color(0xFF9A5B00));
    case 'silai':
      return dark ? (const Color(0xFF3A1E28), const Color(0xFFEB7F98)) : (const Color(0xFFF6E1E7), AppColors.wine);
    case 'ready':
      return dark ? (const Color(0xFF15332A), const Color(0xFF5CCB9A)) : (const Color(0xFFDDF2E8), const Color(0xFF1B7350));
    case 'done':
      return dark ? (const Color(0xFF2A2226), const Color(0xFFAE9FA5)) : (const Color(0xFFEDE7E9), const Color(0xFF75676C));
    case 'late':
      return dark ? (const Color(0xFF3F1A1E), const Color(0xFFFF8A8F)) : (const Color(0xFFFDE2E2), const Color(0xFFB3261E));
    default: // new
      return dark ? (const Color(0xFF1B2A40), const Color(0xFF8DB8F5)) : (const Color(0xFFE2ECFA), const Color(0xFF285CA8));
  }
}

IconData statusIcon(String s) => switch (s) {
      'cutting' => Icons.content_cut,
      'silai' => Icons.design_services_outlined,
      'ready' => Icons.checkroom,
      'done' => Icons.done_all,
      _ => Icons.fiber_new_outlined,
    };

class Pill extends StatelessWidget {
  final String text;
  final String kind;
  const Pill(this.text, this.kind, {super.key});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusColors(context, kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: GoogleFonts.manrope(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

Widget dueLabel(BuildContext context, Order o) {
  if (o.status == 'done') return const SizedBox.shrink();
  final n = daysFromToday(o.delivery);
  if (n == null) return const SizedBox.shrink();
  final (_, lateColor) = statusColors(context, 'late');
  final String t;
  Color c = muted(context);
  if (n < 0) {
    t = '${-n}d late';
    c = lateColor;
  } else if (n == 0) {
    t = 'Today';
    c = statusColors(context, 'cutting').$2;
  } else if (n == 1) {
    t = 'Tomorrow';
  } else {
    t = fmtDate(o.delivery);
  }
  return Text(t, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: c));
}

/// Round initials badge for a customer.
class Initials extends StatelessWidget {
  final String name;
  final double size;
  const Initials(this.name, {super.key, this.size = 42});
  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final ini = parts.isEmpty ? '?' : (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
    final dark = isDark(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? AppColors.wine.withValues(alpha: .35) : AppColors.goldSoft,
        shape: BoxShape.circle,
      ),
      child: Text(ini,
          style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800, fontSize: size * .36, color: dark ? AppColors.goldSoft : AppColors.wine)),
    );
  }
}

class OrderTile extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const OrderTile({super.key, required this.order, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = store.customerById(order.customerId);
    final name = c?.name ?? (order.customerName.isEmpty ? 'Customer' : order.customerName);
    final sub = <String>['${order.suits} suit${order.suits > 1 ? 's' : ''}'];
    if (order.type.isNotEmpty) sub.add(order.type);
    final (sbg, sfg) = statusColors(context, order.status);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: sbg, borderRadius: BorderRadius.circular(13)),
            child: Icon(statusIcon(order.status), color: sfg, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15.5)),
                ),
                if (c != null) ...[
                  const SizedBox(width: 6),
                  Text('#${c.serial}', style: mono(size: 12, weight: FontWeight.w600, color: muted(context))),
                ],
              ]),
              const SizedBox(height: 2),
              Text(sub.join(' · '), style: GoogleFonts.manrope(fontSize: 13, color: muted(context), fontWeight: FontWeight.w500)),
              if (order.due > 0)
                Text('Due ${rs(order.due)}', style: mono(size: 12.5, weight: FontWeight.w700, color: statusColors(context, 'late').$2)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Pill(statusLabel[order.status] ?? 'New', order.status),
            const SizedBox(height: 6),
            dueLabel(context, order),
          ]),
        ]),
      ),
    );
  }
}

/// Card that groups list rows with thin dividers.
class ListCard extends StatelessWidget {
  final List<Widget> children;
  const ListCard({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, indent: 68, color: line(context)));
      items.add(children[i]);
    }
    return Card(clipBehavior: Clip.antiAlias, child: Column(children: items));
  }
}

class EmptyNote extends StatelessWidget {
  final String text;
  final IconData icon;
  final Widget? action;
  const EmptyNote(this.text, {super.key, this.action, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(children: [
          Icon(icon, size: 34, color: muted(context).withValues(alpha: .6)),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: GoogleFonts.manrope(color: muted(context), fontSize: 14, height: 1.45)),
          if (action != null) ...[const SizedBox(height: 16), action!],
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
    final style = GoogleFonts.manrope(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: muted(context));
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(children: [
        Expanded(child: Text(text.toUpperCase(), style: style)),
        if (trailing != null) Text(trailing!, style: style.copyWith(letterSpacing: .3)),
      ]),
    );
  }
}

/// Section header inside forms: an English or Urdu title with a small gold tick mark.
class FormSection extends StatelessWidget {
  final String title;
  final bool urduTitle;
  final List<Widget> children;
  const FormSection({super.key, required this.title, required this.children, this.urduTitle = false});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(textDirection: urduTitle ? TextDirection.rtl : TextDirection.ltr, children: [
            Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            urduTitle
                ? Text(title, textDirection: TextDirection.rtl, style: urdu(size: 17, weight: FontWeight.w700, color: wine(context), height: 1.6))
                : Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16, color: wine(context))),
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool alert;
  final VoidCallback? onTap;
  const StatTile({super.key, required this.value, required this.label, required this.icon, this.alert = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final fg = alert ? statusColors(context, 'late').$2 : Theme.of(context).colorScheme.onSurface;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: alert ? fg : wine(context)),
            const SizedBox(height: 10),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: mono(size: 22, weight: FontWeight.w800, color: fg))),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.manrope(fontSize: 12.5, color: muted(context), fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// Two-column grid.
class Grid2 extends StatelessWidget {
  final List<Widget> tiles;
  final double gap;
  const Grid2(this.tiles, {super.key, this.gap = 10});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: tiles[i]),
          SizedBox(width: gap),
          Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
        ]),
      ));
      if (i + 2 < tiles.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, 'Copied');
}

Future<void> openWhatsApp(BuildContext context, String phone, String text) async {
  final n = waNumber(phone);
  if (n.isEmpty) {
    toast(context, 'This customer has no phone number');
    return;
  }
  final uri = Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(text)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) toast(context, 'Could not open WhatsApp');
}

Future<bool> confirmDelete(BuildContext context, String title, String body) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: statusColors(context, 'late').$2, minimumSize: const Size(0, 42)),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete'),
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
  final bool urduLabels;
  const ChoiceRow({super.key, required this.options, required this.value, required this.onChanged, this.urduLabels = false});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      textDirection: urduLabels ? TextDirection.rtl : TextDirection.ltr,
      children: [
        for (final o in options)
          ChoiceChip(
            label: urduLabels
                ? Text(o, style: urdu(size: 15, height: 1.5, color: o == value ? cs.onPrimary : cs.onSurface))
                : Text(o),
            selected: o == value,
            onSelected: (sel) => onChanged(sel ? o : ''),
          ),
      ],
    );
  }
}

/// Small Urdu label shown above an input.
class UrduLabel extends StatelessWidget {
  final String text;
  const UrduLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Text(text, textDirection: TextDirection.rtl, style: urdu(size: 15, color: muted(context), height: 1.7)),
      );
}
