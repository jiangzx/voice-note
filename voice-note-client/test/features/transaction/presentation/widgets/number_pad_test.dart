import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/transaction/presentation/widgets/number_pad.dart';

void main() {
  late AmountInputController controller;

  setUp(() {
    controller = AmountInputController();
  });

  group('AmountInputController', () {
    test('initial value is 0', () {
      expect(controller.value, '0');
    });

    test('appending digits builds number', () {
      controller.append('3');
      controller.append('5');
      expect(controller.value, '35');
    });

    test('leading zero is replaced by digit', () {
      controller.append('5');
      expect(controller.value, '5');
    });

    test('decimal point works', () {
      controller.append('1');
      controller.append('2');
      controller.append('.');
      controller.append('5');
      expect(controller.value, '12.5');
    });

    test('ignores second decimal point', () {
      controller.append('1');
      controller.append('.');
      controller.append('.');
      expect(controller.value, '1.');
    });

    test('limits to 2 decimal places', () {
      controller.append('1');
      controller.append('.');
      controller.append('5');
      controller.append('5');
      controller.append('9');
      expect(controller.value, '1.55');
    });

    test('enforces max amount', () {
      controller.clear();
      // Set near max
      for (final c in '99999999'.split('')) {
        controller.append(c);
      }
      expect(controller.value, '99999999');
      controller.append('.');
      controller.append('9');
      controller.append('9');
      expect(controller.value, '99999999.99');

      // Further digit should be rejected
      controller.append('9');
      expect(controller.value, '99999999.99');
    });

    test('backspace removes last character', () {
      controller.append('3');
      controller.append('5');
      controller.backspace();
      expect(controller.value, '3');
    });

    test('backspace on single digit resets to 0', () {
      controller.append('5');
      controller.backspace();
      expect(controller.value, '0');
    });

    test('backspace on 0 stays 0', () {
      controller.backspace();
      expect(controller.value, '0');
    });

    test('clear resets to 0', () {
      controller.append('1');
      controller.append('2');
      controller.append('3');
      controller.clear();
      expect(controller.value, '0');
    });

    test('toDouble parses correctly', () {
      controller.append('4');
      controller.append('2');
      controller.append('.');
      controller.append('5');
      expect(controller.toDouble(), 42.5);
    });

    test('setFromDouble integer', () {
      controller.setFromDouble(100);
      expect(controller.value, '100');
    });

    test('setFromDouble with decimals', () {
      controller.setFromDouble(12.50);
      expect(controller.value, '12.5');
    });

    test('setFromDouble with two decimal places', () {
      controller.setFromDouble(99.99);
      expect(controller.value, '99.99');
    });

    test('setFromDouble zero', () {
      controller.setFromDouble(0);
      expect(controller.value, '0');
    });
  });
}
