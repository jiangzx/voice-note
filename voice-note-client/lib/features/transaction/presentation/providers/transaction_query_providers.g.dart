// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_query_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(transactionList)
final transactionListProvider = TransactionListFamily._();

final class TransactionListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TransactionEntity>>,
          List<TransactionEntity>,
          FutureOr<List<TransactionEntity>>
        >
    with
        $FutureModifier<List<TransactionEntity>>,
        $FutureProvider<List<TransactionEntity>> {
  TransactionListProvider._({
    required TransactionListFamily super.from,
    required TransactionFilter super.argument,
  }) : super(
         retry: null,
         name: r'transactionListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transactionListHash();

  @override
  String toString() {
    return r'transactionListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TransactionEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TransactionEntity>> create(Ref ref) {
    final argument = this.argument as TransactionFilter;
    return transactionList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transactionListHash() => r'aba45a1218ac0d17c5f3055ce81dfc0a91088f87';

final class TransactionListFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<TransactionEntity>>,
          TransactionFilter
        > {
  TransactionListFamily._()
    : super(
        retry: null,
        name: r'transactionListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TransactionListProvider call(TransactionFilter filter) =>
      TransactionListProvider._(argument: filter, from: this);

  @override
  String toString() => r'transactionListProvider';
}

@ProviderFor(summary)
final summaryProvider = SummaryFamily._();

final class SummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TransactionSummary>,
          TransactionSummary,
          FutureOr<TransactionSummary>
        >
    with
        $FutureModifier<TransactionSummary>,
        $FutureProvider<TransactionSummary> {
  SummaryProvider._({
    required SummaryFamily super.from,
    required (DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'summaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$summaryHash();

  @override
  String toString() {
    return r'summaryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<TransactionSummary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TransactionSummary> create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime);
    return summary(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is SummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$summaryHash() => r'712de2ea48408ddcb9de8b40c8f11807e8c988ec';

final class SummaryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<TransactionSummary>,
          (DateTime, DateTime)
        > {
  SummaryFamily._()
    : super(
        retry: null,
        name: r'summaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SummaryProvider call(DateTime dateFrom, DateTime dateTo) =>
      SummaryProvider._(argument: (dateFrom, dateTo), from: this);

  @override
  String toString() => r'summaryProvider';
}

@ProviderFor(recentTransactions)
final recentTransactionsProvider = RecentTransactionsProvider._();

final class RecentTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TransactionEntity>>,
          List<TransactionEntity>,
          FutureOr<List<TransactionEntity>>
        >
    with
        $FutureModifier<List<TransactionEntity>>,
        $FutureProvider<List<TransactionEntity>> {
  RecentTransactionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentTransactionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentTransactionsHash();

  @$internal
  @override
  $FutureProviderElement<List<TransactionEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TransactionEntity>> create(Ref ref) {
    return recentTransactions(ref);
  }
}

String _$recentTransactionsHash() =>
    r'360eaa7632a7de97da6bdbcd61a002cc1cd13e62';

@ProviderFor(dailyGrouped)
final dailyGroupedProvider = DailyGroupedFamily._();

final class DailyGroupedProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DailyTransactionGroup>>,
          List<DailyTransactionGroup>,
          FutureOr<List<DailyTransactionGroup>>
        >
    with
        $FutureModifier<List<DailyTransactionGroup>>,
        $FutureProvider<List<DailyTransactionGroup>> {
  DailyGroupedProvider._({
    required DailyGroupedFamily super.from,
    required (DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'dailyGroupedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dailyGroupedHash();

  @override
  String toString() {
    return r'dailyGroupedProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<DailyTransactionGroup>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DailyTransactionGroup>> create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime);
    return dailyGrouped(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is DailyGroupedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dailyGroupedHash() => r'52fa20c8a08bada10801103c419cf721ac377a8b';

final class DailyGroupedFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<DailyTransactionGroup>>,
          (DateTime, DateTime)
        > {
  DailyGroupedFamily._()
    : super(
        retry: null,
        name: r'dailyGroupedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DailyGroupedProvider call(DateTime dateFrom, DateTime dateTo) =>
      DailyGroupedProvider._(argument: (dateFrom, dateTo), from: this);

  @override
  String toString() => r'dailyGroupedProvider';
}

/// Calendar grid data for the given month (date/dailyIncome/dailyExpense only).

@ProviderFor(calendarMonthGroups)
final calendarMonthGroupsProvider = CalendarMonthGroupsFamily._();

/// Calendar grid data for the given month (date/dailyIncome/dailyExpense only).

final class CalendarMonthGroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DailyTransactionGroup>>,
          List<DailyTransactionGroup>,
          FutureOr<List<DailyTransactionGroup>>
        >
    with
        $FutureModifier<List<DailyTransactionGroup>>,
        $FutureProvider<List<DailyTransactionGroup>> {
  /// Calendar grid data for the given month (date/dailyIncome/dailyExpense only).
  CalendarMonthGroupsProvider._({
    required CalendarMonthGroupsFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'calendarMonthGroupsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarMonthGroupsHash();

  @override
  String toString() {
    return r'calendarMonthGroupsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<DailyTransactionGroup>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DailyTransactionGroup>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return calendarMonthGroups(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarMonthGroupsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarMonthGroupsHash() =>
    r'bef3eeb8b4ce8d6deb96114ca432b7792eb7f8c0';

/// Calendar grid data for the given month (date/dailyIncome/dailyExpense only).

final class CalendarMonthGroupsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<DailyTransactionGroup>>,
          DateTime
        > {
  CalendarMonthGroupsFamily._()
    : super(
        retry: null,
        name: r'calendarMonthGroupsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Calendar grid data for the given month (date/dailyIncome/dailyExpense only).

  CalendarMonthGroupsProvider call(DateTime currentMonth) =>
      CalendarMonthGroupsProvider._(argument: currentMonth, from: this);

  @override
  String toString() => r'calendarMonthGroupsProvider';
}

/// Transactions for the selected day only (drives list below calendar).

@ProviderFor(selectedDateTransactions)
final selectedDateTransactionsProvider = SelectedDateTransactionsFamily._();

/// Transactions for the selected day only (drives list below calendar).

final class SelectedDateTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TransactionEntity>>,
          List<TransactionEntity>,
          FutureOr<List<TransactionEntity>>
        >
    with
        $FutureModifier<List<TransactionEntity>>,
        $FutureProvider<List<TransactionEntity>> {
  /// Transactions for the selected day only (drives list below calendar).
  SelectedDateTransactionsProvider._({
    required SelectedDateTransactionsFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'selectedDateTransactionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$selectedDateTransactionsHash();

  @override
  String toString() {
    return r'selectedDateTransactionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TransactionEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TransactionEntity>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return selectedDateTransactions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SelectedDateTransactionsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$selectedDateTransactionsHash() =>
    r'2006b63cfc43e41b491426f691a9f029d2850b23';

/// Transactions for the selected day only (drives list below calendar).

final class SelectedDateTransactionsFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<List<TransactionEntity>>, DateTime> {
  SelectedDateTransactionsFamily._()
    : super(
        retry: null,
        name: r'selectedDateTransactionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Transactions for the selected day only (drives list below calendar).

  SelectedDateTransactionsProvider call(DateTime selectedDate) =>
      SelectedDateTransactionsProvider._(argument: selectedDate, from: this);

  @override
  String toString() => r'selectedDateTransactionsProvider';
}
