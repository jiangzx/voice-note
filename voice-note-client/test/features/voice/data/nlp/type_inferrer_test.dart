import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/data/nlp/type_inferrer.dart';

void main() {
  group('TypeInferrer', () {
    test('defaults to EXPENSE', () {
      expect(TypeInferrer.infer('午饭35'), 'EXPENSE');
    });

    test('infers EXPENSE from 花了', () {
      expect(TypeInferrer.infer('花了35块'), 'EXPENSE');
    });

    test('infers INCOME from 工资', () {
      expect(TypeInferrer.infer('发工资了8000'), 'INCOME');
    });

    test('infers INCOME from 收到', () {
      expect(TypeInferrer.infer('收到红包200'), 'INCOME');
    });

    test('infers INCOME from 奖金', () {
      expect(TypeInferrer.infer('年终奖到了'), 'INCOME');
    });

    test('infers TRANSFER from 转账', () {
      expect(TypeInferrer.infer('转账给小明500'), 'TRANSFER');
    });

    test('infers TRANSFER from 还钱', () {
      expect(TypeInferrer.infer('还钱给老王'), 'TRANSFER');
    });
  });
}
