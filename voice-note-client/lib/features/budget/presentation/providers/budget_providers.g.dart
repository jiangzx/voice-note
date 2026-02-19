// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(budgetRepository)
final budgetRepositoryProvider = BudgetRepositoryProvider._();

final class BudgetRepositoryProvider
    extends
        $FunctionalProvider<
          BudgetRepository,
          BudgetRepository,
          BudgetRepository
        >
    with $Provider<BudgetRepository> {
  BudgetRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'budgetRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetRepositoryHash();

  @$internal
  @override
  $ProviderElement<BudgetRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BudgetRepository create(Ref ref) {
    return budgetRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BudgetRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BudgetRepository>(value),
    );
  }
}

String _$budgetRepositoryHash() => r'378d8fcf4d5cbe8aaa326cae92cdad15870cd54f';

@ProviderFor(budgetService)
final budgetServiceProvider = BudgetServiceProvider._();

final class BudgetServiceProvider
    extends $FunctionalProvider<BudgetService, BudgetService, BudgetService>
    with $Provider<BudgetService> {
  BudgetServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'budgetServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetServiceHash();

  @$internal
  @override
  $ProviderElement<BudgetService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BudgetService create(Ref ref) {
    return budgetService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BudgetService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BudgetService>(value),
    );
  }
}

String _$budgetServiceHash() => r'6640c6d4c0abd9abf6de4329a0ea111b1b193955';

@ProviderFor(currentMonthBudgetStatuses)
final currentMonthBudgetStatusesProvider =
    CurrentMonthBudgetStatusesProvider._();

final class CurrentMonthBudgetStatusesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BudgetStatusWithCategory>>,
          List<BudgetStatusWithCategory>,
          FutureOr<List<BudgetStatusWithCategory>>
        >
    with
        $FutureModifier<List<BudgetStatusWithCategory>>,
        $FutureProvider<List<BudgetStatusWithCategory>> {
  CurrentMonthBudgetStatusesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentMonthBudgetStatusesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentMonthBudgetStatusesHash();

  @$internal
  @override
  $FutureProviderElement<List<BudgetStatusWithCategory>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BudgetStatusWithCategory>> create(Ref ref) {
    return currentMonthBudgetStatuses(ref);
  }
}

String _$currentMonthBudgetStatusesHash() =>
    r'20831fc175b6021b7622bb3462c496f265d1c72c';

/// Existing budget amounts by category for current month (for edit form).

@ProviderFor(currentMonthBudgetAmounts)
final currentMonthBudgetAmountsProvider = CurrentMonthBudgetAmountsProvider._();

/// Existing budget amounts by category for current month (for edit form).

final class CurrentMonthBudgetAmountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, double>>,
          Map<String, double>,
          FutureOr<Map<String, double>>
        >
    with
        $FutureModifier<Map<String, double>>,
        $FutureProvider<Map<String, double>> {
  /// Existing budget amounts by category for current month (for edit form).
  CurrentMonthBudgetAmountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentMonthBudgetAmountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentMonthBudgetAmountsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, double>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, double>> create(Ref ref) {
    return currentMonthBudgetAmounts(ref);
  }
}

String _$currentMonthBudgetAmountsHash() =>
    r'bea8f8b787f2c5878ee95cf0444494c70f0303c3';

/// Summary: total budget, total spent, total remaining for current month.

@ProviderFor(budgetSummary)
final budgetSummaryProvider = BudgetSummaryProvider._();

/// Summary: total budget, total spent, total remaining for current month.

final class BudgetSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<
            ({double totalBudget, double totalRemaining, double totalSpent})
          >,
          ({double totalBudget, double totalRemaining, double totalSpent}),
          FutureOr<
            ({double totalBudget, double totalRemaining, double totalSpent})
          >
        >
    with
        $FutureModifier<
          ({double totalBudget, double totalRemaining, double totalSpent})
        >,
        $FutureProvider<
          ({double totalBudget, double totalRemaining, double totalSpent})
        > {
  /// Summary: total budget, total spent, total remaining for current month.
  BudgetSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'budgetSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetSummaryHash();

  @$internal
  @override
  $FutureProviderElement<
    ({double totalBudget, double totalRemaining, double totalSpent})
  >
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({double totalBudget, double totalRemaining, double totalSpent})>
  create(Ref ref) {
    return budgetSummary(ref);
  }
}

String _$budgetSummaryHash() => r'60da70997d665ed45bf1983625d165d32f4153f7';
