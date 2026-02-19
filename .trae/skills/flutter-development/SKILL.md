---
name: flutter-development
description: Guide Flutter/Dart development with project structure, coding conventions, state management, widget patterns, testing, and performance optimization. Use when creating, modifying, or reviewing Flutter code, setting up new Flutter features, or building widgets and screens.
---

# Flutter Development

## Project Structure

Use feature-based organization:

```
lib/
├── app/                        # App-level config
│   ├── app.dart                # MaterialApp / root widget
│   ├── router.dart             # Route definitions
│   └── theme.dart              # ThemeData
├── core/                       # Cross-cutting concerns
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   └── utils/
├── features/                   # Feature modules
│   └── [feature_name]/
│       ├── data/               # Repositories impl, data sources, DTOs
│       ├── domain/             # Entities, repository interfaces, use-cases
│       └── presentation/       # Widgets, state (providers/blocs), screens
├── shared/                     # Shared UI components & services
│   ├── widgets/
│   └── services/
└── main.dart
```

**Rules:**
- One feature = one directory under `features/`
- Keep `core/` minimal — no business logic
- Mirror test structure to code structure: `test/features/auth/...`

## Dart Coding Conventions

### Naming

| Kind | Convention | Example |
|------|-----------|---------|
| Classes, enums, typedefs, extensions | `UpperCamelCase` | `HttpRequest`, `SliderMenu` |
| Files, packages, directories | `lowercase_with_underscores` | `transaction_list.dart` |
| Variables, parameters, functions | `lowerCamelCase` | `itemCount`, `fetchData()` |
| Constants | `lowerCamelCase` | `defaultTimeout`, `maxRetries` |
| Private members | `_` prefix | `_internalState` |

Acronyms longer than 2 letters → capitalize like words: `HttpClient` not `HTTPClient`.

### Import Ordering

```dart
// 1. dart: imports
import 'dart:async';

// 2. package: imports (alphabetical)
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';

// 3. Relative imports (alphabetical)
import '../core/utils/date_utils.dart';
import 'transaction_model.dart';
```

### Type Safety

```dart
// ✅ Explicit types for public APIs
String formatAmount(double amount, {String currency = 'CNY'}) { ... }

// ✅ final for locals, const where possible
final items = <Transaction>[];
const maxPageSize = 50;

// ❌ Avoid var/dynamic in public APIs
var x = getData(); // Bad
dynamic result;    // Bad
```

### Null Safety

```dart
// ✅ Use null-aware operators
final name = user?.name ?? 'Unknown';

// ✅ Late only when truly needed and initialization is guaranteed
late final Database _db;

// ❌ Avoid force-unwrap unless provably non-null
user!.name; // Dangerous if user can be null
```

### Error Handling

```dart
// ✅ Typed exceptions with context
class TransactionException implements Exception {
  final String message;
  final String? code;
  const TransactionException(this.message, {this.code});
}

// ✅ Handle errors at the right layer
Future<Result<T, E>> safeCall<T, E>(Future<T> Function() fn) async {
  try {
    return Result.success(await fn());
  } on E catch (e) {
    return Result.failure(e);
  }
}
```

### Code Quality

- Functions ≤ 50 lines; split if longer
- Max nesting depth: 3 levels; use early returns
- No magic numbers — use named constants
- Prefer `switch` expressions over `if`/`else` chains for enums
- Avoid `print()` — use `debugPrint()` or a logging package
- Format with `dart format`

## Widget Patterns

### Composition Over Inheritance

```dart
// ✅ Small, focused, composable widgets
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({super.key, required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Text(
      '¥${amount.toStringAsFixed(2)}',
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}
```

### const Constructors

Always use `const` constructors when possible — this is the single most impactful performance optimization:

```dart
// ✅ const constructor + const usage
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.label});
  final String label;
  // ...
}

// Usage
const CategoryChip(label: 'Food') // reused across rebuilds
```

### Localize setState

```dart
// ✅ setState only in the smallest subtree that needs it
class _CounterState extends State<Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Header(),        // never rebuilds
        CounterDisplay(count: _count), // only this rebuilds
        ElevatedButton(
          onPressed: () => setState(() => _count++),
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
```

### Widget vs Helper Function

```dart
// ✅ Prefer StatelessWidget for reusable UI (enables const, has its own BuildContext)
class ListTileContent extends StatelessWidget { ... }

// ❌ Avoid private build methods that return widget trees
Widget _buildContent() { ... } // loses optimization opportunities
```

## State Management

Use **Riverpod** as default. Follow these rules:

```dart
// ✅ keepAlive for services/repositories
@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) {
  return TransactionRepositoryImpl(ref.watch(databaseProvider));
}

// ✅ Auto-dispose for computed/UI state
@riverpod
Future<List<Transaction>> monthlyTransactions(Ref ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getByMonth(DateTime.now());
}

// ✅ Check mounted after await
Future<void> deleteTransaction(WidgetRef ref, String id) async {
  await ref.read(transactionRepositoryProvider).delete(id);
  if (!ref.context.mounted) return;
  // proceed with UI updates
}
```

**DO NOT:**
- Initialize providers inside widgets
- Use providers for ephemeral state (form input, animations, scroll position)
- Perform side effects during provider initialization
- Watch entire providers when only a field is needed — use `.select()`

## Navigation

Use declarative routing (`go_router` or equivalent):

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'transaction/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TransactionDetailScreen(id: id);
          },
        ),
      ],
    ),
  ],
);
```

## Testing Strategy

Follow the testing pyramid: 70% unit / 20% widget / 10% integration.

### Unit Tests (AAA Pattern)

```dart
test('calculates monthly total correctly', () {
  // Arrange
  final transactions = [
    Transaction(amount: 100),
    Transaction(amount: 250),
  ];

  // Act
  final total = calculateTotal(transactions);

  // Assert
  expect(total, 350.0);
});
```

### Widget Tests

```dart
testWidgets('displays transaction amount', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: AmountDisplay(amount: 42.5),
    ),
  );

  expect(find.text('¥42.50'), findsOneWidget);
});
```

### Test Naming

```dart
// ✅ Descriptive: describes scenario and expected outcome
test('returns empty list when no transactions match the date range', () {});
test('throws TransactionException when database is unavailable', () {});

// ❌ Vague
test('works', () {});
test('test query', () {});
```

### Key Rules
- Each test must be self-contained — no shared mutable state
- Avoid `pumpAndSettle` — use `pump()` with explicit durations
- Add `Key` to widgets that need interaction in integration tests

## Performance

| Practice | Why |
|----------|-----|
| Use `const` widgets everywhere possible | Prevents unnecessary rebuilds |
| Split large `build()` into small widgets | Enables granular rebuild |
| Use `ListView.builder` for long lists | Lazy rendering |
| Cache images with `CachedNetworkImage` | Avoids redundant downloads |
| Profile with DevTools | Find jank, memory leaks |
| Avoid `Opacity` widget — use color alpha | `Opacity` forces offscreen buffer |
| Use `RepaintBoundary` for complex subtrees | Isolates repaint |

Target: **60 FPS consistent, < 16ms per frame**.

## analysis_options.yaml

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    missing_return: error
    dead_code: warning

linter:
  rules:
    - always_declare_return_types
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_locals
    - avoid_print
    - avoid_unnecessary_containers
    - sized_box_for_whitespace
    - use_key_in_widget_constructors
    - prefer_single_quotes
```

## Additional Resources

- For detailed Dart/Flutter conventions reference, see [reference.md](reference.md)
