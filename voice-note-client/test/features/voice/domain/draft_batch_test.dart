import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/domain/draft_batch.dart';
import 'package:suikouji/features/voice/domain/parse_result.dart';

const _meal = ParseResult(
  amount: 60,
  category: '餐饮',
  description: '吃饭',
  source: ParseSource.llm,
  confidence: 0.9,
);

const _taxi = ParseResult(
  amount: 30,
  category: '交通',
  description: '打车',
  source: ParseSource.llm,
  confidence: 0.9,
);

const _hongbao = ParseResult(
  amount: 30,
  category: '红包',
  type: 'INCOME',
  description: '红包',
  source: ParseSource.llm,
  confidence: 0.9,
);

DraftBatch _twoBatch() => DraftBatch.fromResults([_meal, _taxi]);

void main() {
  group('DraftBatch.fromResults', () {
    test('creates batch with correct indices', () {
      final batch = DraftBatch.fromResults([_meal, _taxi, _hongbao]);

      expect(batch.length, 3);
      expect(batch.items[0].index, 0);
      expect(batch.items[1].index, 1);
      expect(batch.items[2].index, 2);
    });

    test('all items start as pending', () {
      final batch = _twoBatch();

      expect(batch.pendingCount, 2);
      expect(batch.confirmedCount, 0);
      expect(batch.cancelledCount, 0);
      expect(batch.allResolved, isFalse);
    });

    test('single-item batch is compatible', () {
      final batch = DraftBatch.fromResults([_meal]);

      expect(batch.isSingleItem, isTrue);
      expect(batch.length, 1);
      expect(batch.pendingCount, 1);
    });
  });

  group('updateItem', () {
    test('updates ParseResult at given index', () {
      final batch = _twoBatch();
      const updated = ParseResult(
        amount: 50,
        category: '餐饮',
        description: '午饭',
        source: ParseSource.llm,
        confidence: 0.9,
      );

      final result = batch.updateItem(0, updated);

      expect(result.items[0].result.amount, 50);
      expect(result.items[0].result.description, '午饭');
      expect(result.items[1].result.amount, 30);
    });

    test('returns same batch for non-existent index', () {
      final batch = _twoBatch();
      final result = batch.updateItem(99, _meal);

      expect(identical(result, batch), isTrue);
    });

    test('is immutable — original unchanged', () {
      final original = _twoBatch();
      final updated = original.updateItem(0, _taxi);

      expect(original.items[0].result.amount, 60);
      expect(updated.items[0].result.amount, 30);
    });
  });

  group('confirmItem', () {
    test('marks item as confirmed', () {
      final batch = _twoBatch();
      final result = batch.confirmItem(0);

      expect(result.items[0].status, DraftStatus.confirmed);
      expect(result.items[1].status, DraftStatus.pending);
      expect(result.confirmedCount, 1);
      expect(result.pendingCount, 1);
    });

    test('does not resolve batch with remaining pending', () {
      final result = _twoBatch().confirmItem(0);
      expect(result.allResolved, isFalse);
    });
  });

  group('cancelItem', () {
    test('marks item as cancelled', () {
      final batch = _twoBatch();
      final result = batch.cancelItem(1);

      expect(result.items[1].status, DraftStatus.cancelled);
      expect(result.cancelledCount, 1);
      expect(result.pendingCount, 1);
    });
  });

  group('confirmAll', () {
    test('confirms all pending items', () {
      final batch = _twoBatch();
      final result = batch.confirmAll();

      expect(result.confirmedCount, 2);
      expect(result.pendingCount, 0);
      expect(result.allResolved, isTrue);
    });

    test('preserves already cancelled items', () {
      final batch = _twoBatch().cancelItem(0);
      final result = batch.confirmAll();

      expect(result.items[0].status, DraftStatus.cancelled);
      expect(result.items[1].status, DraftStatus.confirmed);
      expect(result.allResolved, isTrue);
    });
  });

  group('cancelAll', () {
    test('cancels all pending items', () {
      final batch = _twoBatch();
      final result = batch.cancelAll();

      expect(result.cancelledCount, 2);
      expect(result.pendingCount, 0);
      expect(result.allResolved, isTrue);
    });

    test('preserves already confirmed items', () {
      final batch = _twoBatch().confirmItem(0);
      final result = batch.cancelAll();

      expect(result.items[0].status, DraftStatus.confirmed);
      expect(result.items[1].status, DraftStatus.cancelled);
      expect(result.allResolved, isTrue);
    });
  });

  group('allResolved', () {
    test('true when all confirmed', () {
      final batch = _twoBatch().confirmAll();
      expect(batch.allResolved, isTrue);
    });

    test('true when all cancelled', () {
      final batch = _twoBatch().cancelAll();
      expect(batch.allResolved, isTrue);
    });

    test('true when mixed confirm + cancel', () {
      final batch = _twoBatch().confirmItem(0).cancelItem(1);
      expect(batch.allResolved, isTrue);
    });

    test('false when any pending remains', () {
      final batch = _twoBatch().confirmItem(0);
      expect(batch.allResolved, isFalse);
    });
  });

  group('pendingItems / confirmedItems', () {
    test('filters correctly', () {
      final batch = _twoBatch().confirmItem(0);

      expect(batch.pendingItems.length, 1);
      expect(batch.pendingItems[0].index, 1);
      expect(batch.confirmedItems.length, 1);
      expect(batch.confirmedItems[0].index, 0);
    });
  });

  group('append', () {
    test('adds item at the end with next index', () {
      final batch = _twoBatch();
      final result = batch.append(_hongbao);

      expect(result, isNotNull);
      expect(result!.length, 3);
      expect(result.items[2].index, 2);
      expect(result.items[2].result.category, '红包');
      expect(result.items[2].status, DraftStatus.pending);
    });

    test('returns null when at max size', () {
      final results = List.generate(
        DraftBatch.maxSize,
        (i) => ParseResult(
          amount: i.toDouble(),
          category: 'cat$i',
          source: ParseSource.llm,
        ),
      );
      final batch = DraftBatch.fromResults(results);

      expect(batch.append(_meal), isNull);
    });

    test('preserves createdAt', () {
      final batch = _twoBatch();
      final result = batch.append(_hongbao);

      expect(result!.createdAt, batch.createdAt);
    });
  });

  group('immutability', () {
    test('items list is unmodifiable', () {
      final batch = _twoBatch();
      expect(
        () => (batch.items as List).add(
          const DraftTransaction(index: 3, result: _meal),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
