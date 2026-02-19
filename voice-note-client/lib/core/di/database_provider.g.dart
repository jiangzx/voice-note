// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';

@ProviderFor(accountDao)
final accountDaoProvider = AccountDaoProvider._();

final class AccountDaoProvider
    extends $FunctionalProvider<AccountDao, AccountDao, AccountDao>
    with $Provider<AccountDao> {
  AccountDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDaoHash();

  @$internal
  @override
  $ProviderElement<AccountDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountDao create(Ref ref) {
    return accountDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountDao>(value),
    );
  }
}

String _$accountDaoHash() => r'a5ff7cb5d017c2c037bba125bee114084e4bec9e';

@ProviderFor(budgetDao)
final budgetDaoProvider = BudgetDaoProvider._();

final class BudgetDaoProvider
    extends $FunctionalProvider<BudgetDao, BudgetDao, BudgetDao>
    with $Provider<BudgetDao> {
  BudgetDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'budgetDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetDaoHash();

  @$internal
  @override
  $ProviderElement<BudgetDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BudgetDao create(Ref ref) {
    return budgetDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BudgetDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BudgetDao>(value),
    );
  }
}

String _$budgetDaoHash() => r'244350bc6bf6ebc3a8c356974ca27d10a6b1fb56';

@ProviderFor(categoryDao)
final categoryDaoProvider = CategoryDaoProvider._();

final class CategoryDaoProvider
    extends $FunctionalProvider<CategoryDao, CategoryDao, CategoryDao>
    with $Provider<CategoryDao> {
  CategoryDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryDaoHash();

  @$internal
  @override
  $ProviderElement<CategoryDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CategoryDao create(Ref ref) {
    return categoryDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryDao>(value),
    );
  }
}

String _$categoryDaoHash() => r'ae9ffd694fad5bc697247969a2021a157605087b';

@ProviderFor(statisticsDao)
final statisticsDaoProvider = StatisticsDaoProvider._();

final class StatisticsDaoProvider
    extends $FunctionalProvider<StatisticsDao, StatisticsDao, StatisticsDao>
    with $Provider<StatisticsDao> {
  StatisticsDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'statisticsDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$statisticsDaoHash();

  @$internal
  @override
  $ProviderElement<StatisticsDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StatisticsDao create(Ref ref) {
    return statisticsDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StatisticsDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StatisticsDao>(value),
    );
  }
}

String _$statisticsDaoHash() => r'ebbb7bcc8d56b492e23ebf9eef87a834fbea39f7';

@ProviderFor(transactionDao)
final transactionDaoProvider = TransactionDaoProvider._();

final class TransactionDaoProvider
    extends $FunctionalProvider<TransactionDao, TransactionDao, TransactionDao>
    with $Provider<TransactionDao> {
  TransactionDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionDaoHash();

  @$internal
  @override
  $ProviderElement<TransactionDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TransactionDao create(Ref ref) {
    return transactionDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionDao>(value),
    );
  }
}

String _$transactionDaoHash() => r'219eb82d4f5ddd30cffc7d2073871c4eb8afc9f5';
