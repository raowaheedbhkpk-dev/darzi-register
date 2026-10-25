import 'package:flutter_test/flutter_test.dart';
import 'package:darzi_register/models.dart';

void main() {
  test('rupee format', () {
    expect(rs(1500), 'Rs 1,500');
    expect(waNumber('0300-1234567'), '923001234567');
  });
}
