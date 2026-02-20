import 'parse_result.dart';

enum DraftStatus { pending, confirmed, cancelled }

/// A single transaction draft within a batch. Immutable — all mutations
/// return a new instance.
class DraftTransaction {
  final int index;
  final ParseResult result;
  final DraftStatus status;

  const DraftTransaction({
    required this.index,
    required this.result,
    this.status = DraftStatus.pending,
  });

  DraftTransaction copyWith({ParseResult? result, DraftStatus? status}) {
    return DraftTransaction(
      index: index,
      result: result ?? this.result,
      status: status ?? this.status,
    );
  }
}

/// An ordered collection of draft transactions parsed from a single voice
/// input. Treats a single transaction as batch of size 1.
///
/// Immutable — every mutation method returns a new [DraftBatch].
class DraftBatch {
  final List<DraftTransaction> items;
  final DateTime createdAt;

  DraftBatch({required List<DraftTransaction> items, DateTime? createdAt})
      : items = List.unmodifiable(items),
        createdAt = createdAt ?? DateTime.now();

  /// Create from a list of parse results (e.g. after NLP parsing).
  factory DraftBatch.fromResults(List<ParseResult> results) {
    return DraftBatch(
      items: [
        for (var i = 0; i < results.length; i++)
          DraftTransaction(index: i, result: results[i]),
      ],
    );
  }

  /// Create an empty batch (used when no amount is detected).
  factory DraftBatch.empty() {
    return DraftBatch(items: []);
  }

  int get length => items.length;
  bool get isSingleItem => items.length == 1;

  int get pendingCount =>
      items.where((t) => t.status == DraftStatus.pending).length;
  int get confirmedCount =>
      items.where((t) => t.status == DraftStatus.confirmed).length;
  int get cancelledCount =>
      items.where((t) => t.status == DraftStatus.cancelled).length;

  bool get allResolved =>
      items.every((t) => t.status != DraftStatus.pending);

  List<DraftTransaction> get pendingItems =>
      items.where((t) => t.status == DraftStatus.pending).toList();
  List<DraftTransaction> get confirmedItems =>
      items.where((t) => t.status == DraftStatus.confirmed).toList();

  /// Update the [ParseResult] of the item at [index].
  DraftBatch updateItem(int index, ParseResult result) {
    return _replaceAt(index, (item) => item.copyWith(result: result));
  }

  /// Mark item at [index] as confirmed.
  DraftBatch confirmItem(int index) {
    return _replaceAt(
      index,
      (item) => item.copyWith(status: DraftStatus.confirmed),
    );
  }

  /// Mark item at [index] as cancelled.
  DraftBatch cancelItem(int index) {
    return _replaceAt(
      index,
      (item) => item.copyWith(status: DraftStatus.cancelled),
    );
  }

  /// Confirm all pending items.
  DraftBatch confirmAll() {
    return DraftBatch(
      items: items.map((t) {
        if (t.status == DraftStatus.pending) {
          return t.copyWith(status: DraftStatus.confirmed);
        }
        return t;
      }).toList(),
      createdAt: createdAt,
    );
  }

  /// Cancel all pending items.
  DraftBatch cancelAll() {
    return DraftBatch(
      items: items.map((t) {
        if (t.status == DraftStatus.pending) {
          return t.copyWith(status: DraftStatus.cancelled);
        }
        return t;
      }).toList(),
      createdAt: createdAt,
    );
  }

  /// Append a new draft transaction to the end.
  /// Returns null if batch would exceed [maxSize].
  static const int maxSize = 10;

  DraftBatch? append(ParseResult result) {
    if (items.length >= maxSize) return null;
    final newIndex = items.isEmpty ? 0 : items.last.index + 1;
    return DraftBatch(
      items: [
        ...items,
        DraftTransaction(index: newIndex, result: result),
      ],
      createdAt: createdAt,
    );
  }

  DraftBatch _replaceAt(
    int index,
    DraftTransaction Function(DraftTransaction) transform,
  ) {
    final idx = items.indexWhere((t) => t.index == index);
    if (idx == -1) return this;
    final updated = List<DraftTransaction>.of(items);
    updated[idx] = transform(items[idx]);
    return DraftBatch(items: updated, createdAt: createdAt);
  }
}
