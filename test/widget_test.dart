import 'package:flutter_test/flutter_test.dart';
import 'package:saribay/core/utils/money.dart';

void main() {
  group('Money formatting', () {
    test('peso formats correctly', () {
      expect(peso(100), contains('100'));
      expect(peso(0), contains('0'));
      expect(peso(-50), contains('50'));
    });

    test('peso handles null', () {
      expect(peso(null), contains('0'));
    });

    test('fmtQty formats integers', () {
      expect(fmtQty(5), '5');
    });

    test('fmtQty formats decimals', () {
      expect(fmtQty(2.5), '2.5');
    });

    test('parsePeso extracts number', () {
      expect(parsePeso('₱100.50'), 100.50);
      expect(parsePeso('100'), 100);
      expect(parsePeso('invalid'), 0);
    });
  });
}
