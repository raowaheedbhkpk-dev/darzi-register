import 'dart:math' as math;

/// One measurement line of the register (Urdu label + Roman label).
class MeasField {
  final String k;
  final String ur;
  final String en;
  const MeasField(this.k, this.ur, this.en);
}

/// Same order as the paper register.
const List<MeasField> measFields = [
  MeasField('qameez', 'قمیض', 'Qameez'),
  MeasField('shirt', 'شرٹ', 'Shirt'),
  MeasField('waistcoat', 'ویس کوٹ', 'Waistcoat'),
  MeasField('bazoo', 'بازو', 'Bazoo'),
  MeasField('teera', 'تیرا', 'Teera'),
  MeasField('gala', 'گلہ', 'Gala'),
  MeasField('chhati', 'چھاتی', 'Chhati'),
  MeasField('kamar', 'کمر', 'Kamar'),
  MeasField('ghera', 'گھیرا', 'Ghera'),
  MeasField('pockets', 'پاکٹس', 'Pockets'),
  MeasField('shalwar', 'شلوار', 'Shalwar'),
  MeasField('paincha', 'پائنچہ', 'Paincha'),
];

/// The small red boxes at the bottom of the register slip.
const List<MeasField> boxFields = [
  MeasField('front', 'فرنٹ', 'Front'),
  MeasField('side', 'سائیڈ', 'Side'),
  MeasField('hip', 'ہپ', 'Hip'),
  MeasField('collar', 'کالر/بین', 'Collar'),
  MeasField('cuff', 'کف', 'Cuff'),
  MeasField('plate', 'پلیٹ', 'Plate'),
];

const List<String> gheraOptions = ['Gol', 'Seedha'];
const List<String> collarOptions = ['Collar', 'Bain', 'Sherwani'];
const List<String> orderTypes = ['Shalwar Qameez', 'Kurta', 'Waistcoat', 'Pant Shirt', 'Sherwani'];

const List<String> statusKeys = ['new', 'cutting', 'silai', 'ready', 'done'];
const Map<String, String> statusLabel = {
  'new': 'Naya',
  'cutting': 'Cutting',
  'silai': 'Silai',
  'ready': 'Tayyar',
  'done': 'Delivered',
};

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? 0;
num _n(dynamic v) => v is num ? v : num.tryParse(_s(v)) ?? 0;

class Customer {
  String id;
  int serial;
  String name;
  String phone;
  String address;
  String notes;
  Map<String, String> m;
  int createdAt;
  int updatedAt;

  Customer({
    required this.id,
    required this.serial,
    required this.name,
    this.phone = '',
    this.address = '',
    this.notes = '',
    Map<String, String>? m,
    int? createdAt,
    int? updatedAt,
  })  : m = m ?? {},
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory Customer.fromJson(Map<String, dynamic> j) {
    final raw = j['m'];
    final mm = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final s = _s(v).trim();
        if (s.isNotEmpty) mm[k.toString()] = s;
      });
    }
    return Customer(
      id: _s(j['id']),
      serial: _i(j['serial']),
      name: _s(j['name']),
      phone: _s(j['phone']),
      address: _s(j['address']),
      notes: _s(j['notes']),
      m: mm,
      createdAt: _i(j['createdAt']),
      updatedAt: _i(j['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'serial': serial,
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
        'm': m,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

class Order {
  String id;
  String customerId;
  String customerName;
  int suits;
  String delivery; // yyyy-mm-dd or ''
  String type;
  String status;
  String notes;
  num price;
  num advance;
  int createdAt;
  int? deliveredAt;

  Order({
    required this.id,
    required this.customerId,
    this.customerName = '',
    this.suits = 1,
    this.delivery = '',
    this.type = '',
    this.status = 'new',
    this.notes = '',
    this.price = 0,
    this.advance = 0,
    int? createdAt,
    this.deliveredAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  num get due => math.max(0, price - advance);

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: _s(j['id']),
        customerId: _s(j['customerId']),
        customerName: _s(j['customerName']),
        suits: _i(j['suits']) < 1 ? 1 : _i(j['suits']),
        delivery: _s(j['delivery']),
        type: _s(j['type']),
        status: statusKeys.contains(_s(j['status'])) ? _s(j['status']) : 'new',
        notes: _s(j['notes']),
        price: _n(j['price']),
        advance: _n(j['advance']),
        createdAt: _i(j['createdAt']),
        deliveredAt: j['deliveredAt'] == null ? null : _i(j['deliveredAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'suits': suits,
        'delivery': delivery,
        'type': type,
        'status': status,
        'notes': notes,
        'price': price,
        'advance': advance,
        'createdAt': createdAt,
        'deliveredAt': deliveredAt,
      };
}

// ---------- small helpers ----------
String newId() {
  final r = math.Random();
  return DateTime.now().millisecondsSinceEpoch.toRadixString(36) + r.nextInt(1 << 30).toRadixString(36);
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseIso(String s) {
  if (s.isEmpty) return null;
  try {
    final p = s.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  } catch (_) {
    return null;
  }
}

/// Days from today (0 = today, 1 = tomorrow, -2 = two days ago). null if no date.
int? daysFromToday(String s) {
  final d = parseIso(s);
  if (d == null) return null;
  final now = DateTime.now();
  final t = DateTime(now.year, now.month, now.day);
  return d.difference(t).inDays;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String fmtDate(String s) {
  final d = parseIso(s);
  if (d == null) return '—';
  return '${d.day} ${_months[d.month - 1]}';
}

String fmtMillis(int ms) {
  if (ms <= 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String rs(num n) {
  final v = n.round();
  final neg = v < 0;
  var s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return 'Rs ${neg ? '-' : ''}$buf';
}

String agoText(int ms) {
  final m = (DateTime.now().millisecondsSinceEpoch - ms) ~/ 60000;
  if (m < 1) return 'abhi';
  if (m < 60) return '$m min';
  final h = (m / 60).round();
  if (h < 24) return '$h ghante';
  return '${(h / 24).round()} din';
}

/// 0300-1234567 -> 923001234567 for wa.me links.
String waNumber(String p) {
  var d = p.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0')) d = '92${d.substring(1)}';
  if (d.length == 10 && d.startsWith('3')) d = '92$d';
  return d;
}
