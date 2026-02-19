# Flutter Development Reference

Detailed conventions and patterns beyond the main SKILL.md.

## Dart Language Patterns

### Immutability

Prefer immutable data models. Use `freezed` or manual `copyWith`:

```dart
@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required double amount,
    required DateTime date,
    required String categoryId,
    String? note,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}
```

Without code generation:

```dart
class Transaction {
  final String id;
  final double amount;
  final DateTime date;

  const Transaction({
    required this.id,
    required this.amount,
    required this.date,
  });

  Transaction copyWith({
    String? id,
    double? amount,
    DateTime? date,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

### Extension Methods

Use extensions for domain-specific utilities:

```dart
extension DateTimeX on DateTime {
  String toDisplayDate() => '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  bool isSameMonth(DateTime other) =>
      year == other.year && month == other.month;
}

extension DoubleX on double {
  String toCurrency({String symbol = '¥'}) =>
      '$symbol${toStringAsFixed(2)}';
}
```

### Sealed Classes for State

```dart
sealed class TransactionState {}
class TransactionInitial extends TransactionState {}
class TransactionLoading extends TransactionState {}
class TransactionLoaded extends TransactionState {
  final List<Transaction> transactions;
  const TransactionLoaded(this.transactions);
}
class TransactionError extends TransactionState {
  final String message;
  const TransactionError(this.message);
}
```

### Pattern Matching (Dart 3+)

```dart
// ✅ Exhaustive switch on sealed class
Widget buildContent(TransactionState state) {
  return switch (state) {
    TransactionInitial() => const SizedBox.shrink(),
    TransactionLoading() => const CircularProgressIndicator(),
    TransactionLoaded(:final transactions) => TransactionList(items: transactions),
    TransactionError(:final message) => ErrorDisplay(message: message),
  };
}

// ✅ Guard clauses with patterns
String categorize(double amount) => switch (amount) {
  < 0 => 'expense',
  == 0 => 'zero',
  _ => 'income',
};
```

## Widget Architecture

### Screen / Page Pattern

Each screen is a thin orchestrator:

```dart
class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: switch (state) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        AsyncData(:final value) => TransactionListView(transactions: value),
      },
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transaction/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### Reusable Widget Checklist

When creating a reusable widget:

1. Use `const` constructor with `super.key`
2. Accept callbacks (not provider refs) for actions
3. Document public parameters with dartdoc
4. Add widget test covering key states
5. Prefer composition — wrap existing widgets rather than reimplementing

### Theme & Styling

```dart
// ✅ Always use Theme tokens, never hardcode colors/sizes
Text(
  'Amount',
  style: Theme.of(context).textTheme.bodyMedium,
)

// ✅ Define app theme centrally
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: Colors.blue,
    // ...
  );
}

// ❌ Avoid
Text('Amount', style: TextStyle(fontSize: 14, color: Colors.black))
```

### Responsive & Adaptive

```dart
// Use LayoutBuilder or MediaQuery for responsive layouts
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 600) {
      return const WideLayout();
    }
    return const NarrowLayout();
  },
)
```

## Data Layer Patterns

### Repository Interface + Implementation

```dart
// domain/repositories/transaction_repository.dart
abstract class TransactionRepository {
  Future<List<Transaction>> getAll();
  Future<Transaction> getById(String id);
  Future<void> create(Transaction transaction);
  Future<void> update(Transaction transaction);
  Future<void> delete(String id);
}

// data/repositories/transaction_repository_impl.dart
class TransactionRepositoryImpl implements TransactionRepository {
  final Database _db;
  const TransactionRepositoryImpl(this._db);

  @override
  Future<List<Transaction>> getAll() async {
    final rows = await _db.query('transactions');
    return rows.map(Transaction.fromJson).toList();
  }
  // ...
}
```

### DTO Separation

```dart
// DTO for external data (API / DB)
class TransactionDto {
  final String id;
  final int amountCents;
  final String dateStr;

  const TransactionDto({
    required this.id,
    required this.amountCents,
    required this.dateStr,
  });

  factory TransactionDto.fromJson(Map<String, dynamic> json) => TransactionDto(
    id: json['id'] as String,
    amountCents: json['amount_cents'] as int,
    dateStr: json['date'] as String,
  );

  Transaction toDomain() => Transaction(
    id: id,
    amount: amountCents / 100.0,
    date: DateTime.parse(dateStr),
  );
}
```

## Error Handling Strategy

### Result Type

```dart
sealed class Result<T, E> {
  const Result();
}

class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);
}

class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}
```

### Error Boundaries in UI

```dart
// Catch async errors at screen level
ref.listen(transactionListProvider, (prev, next) {
  if (next is AsyncError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed: ${next.error}')),
    );
  }
});
```

## Documentation Standards

### When to Document

```dart
// ✅ Document WHY, not WHAT
/// Uses cents internally to avoid floating-point precision issues
/// when aggregating large numbers of transactions.
final int amountCents;

// ✅ Document public API with dartdoc
/// Fetches transactions within [start] and [end] date range.
///
/// Returns empty list if no transactions match.
/// Throws [DatabaseException] if connection fails.
Future<List<Transaction>> getByDateRange(DateTime start, DateTime end);

// ❌ Don't state the obvious
/// The transaction id.
final String id; // Useless comment
```

## Formatting

- Max line length: 80 characters
- Use trailing commas for multi-line parameters/arguments
- Use `dart format` for all files
- Prefer single quotes for strings
- Use curly braces for all control flow (except single-line `if` with no `else`)

```dart
// ✅ Trailing comma triggers multi-line formatting
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(12),
  ),
  child: const Text('Hello'),
)
```

## Common Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| God widget (500+ lines) | Split into composed smaller widgets |
| Business logic in widgets | Move to repository / use-case / provider |
| Hardcoded strings | Use constants or localization |
| Deep nesting (4+ levels) | Early returns, extract widgets |
| `setState` in root widget | Localize state or use state management |
| `BuildContext` across async gap | Check `mounted` before using context |
| Network calls in `build()` | Use providers or `FutureBuilder` with cache |
