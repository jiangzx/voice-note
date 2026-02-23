// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statistics_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(statisticsRepository)
final statisticsRepositoryProvider = StatisticsRepositoryProvider._();

final class StatisticsRepositoryProvider
    extends
        $FunctionalProvider<
          StatisticsRepository,
          StatisticsRepository,
          StatisticsRepository
        >
    with $Provider<StatisticsRepository> {
  StatisticsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'statisticsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$statisticsRepositoryHash();

  @$internal
  @override
  $ProviderElement<StatisticsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StatisticsRepository create(Ref ref) {
    return statisticsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StatisticsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StatisticsRepository>(value),
    );
  }
}

String _$statisticsRepositoryHash() =>
    r'5041146a0d1ad733e9d194766c3bda7e64f926fd';

@ProviderFor(effectiveDateRange)
final effectiveDateRangeProvider = EffectiveDateRangeProvider._();

final class EffectiveDateRangeProvider
    extends
        $FunctionalProvider<
          EffectiveDateRange,
          EffectiveDateRange,
          EffectiveDateRange
        >
    with $Provider<EffectiveDateRange> {
  EffectiveDateRangeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'effectiveDateRangeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$effectiveDateRangeHash();

  @$internal
  @override
  $ProviderElement<EffectiveDateRange> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EffectiveDateRange create(Ref ref) {
    return effectiveDateRange(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EffectiveDateRange value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EffectiveDateRange>(value),
    );
  }
}

String _$effectiveDateRangeHash() =>
    r'e2032fcf12df7bec2a9e5898d9d5aad631a09b53';

@ProviderFor(periodSummary)
final periodSummaryProvider = PeriodSummaryProvider._();

final class PeriodSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<PeriodSummary>,
          PeriodSummary,
          FutureOr<PeriodSummary>
        >
    with $FutureModifier<PeriodSummary>, $FutureProvider<PeriodSummary> {
  PeriodSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'periodSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$periodSummaryHash();

  @$internal
  @override
  $FutureProviderElement<PeriodSummary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PeriodSummary> create(Ref ref) {
    return periodSummary(ref);
  }
}

String _$periodSummaryHash() => r'9e9736567bb764382e66206046d92336b53d849e';

@ProviderFor(previousPeriodSummary)
final previousPeriodSummaryProvider = PreviousPeriodSummaryProvider._();

final class PreviousPeriodSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<PeriodSummary>,
          PeriodSummary,
          FutureOr<PeriodSummary>
        >
    with $FutureModifier<PeriodSummary>, $FutureProvider<PeriodSummary> {
  PreviousPeriodSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'previousPeriodSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$previousPeriodSummaryHash();

  @$internal
  @override
  $FutureProviderElement<PeriodSummary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PeriodSummary> create(Ref ref) {
    return previousPeriodSummary(ref);
  }
}

String _$previousPeriodSummaryHash() =>
    r'cbeb2c097fd231d95a1eacbec5135d7e305c9f8f';

@ProviderFor(categorySummary)
final categorySummaryProvider = CategorySummaryProvider._();

final class CategorySummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CategorySummary>>,
          List<CategorySummary>,
          FutureOr<List<CategorySummary>>
        >
    with
        $FutureModifier<List<CategorySummary>>,
        $FutureProvider<List<CategorySummary>> {
  CategorySummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categorySummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categorySummaryHash();

  @$internal
  @override
  $FutureProviderElement<List<CategorySummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CategorySummary>> create(Ref ref) {
    return categorySummary(ref);
  }
}

String _$categorySummaryHash() => r'761b9fe308c0b2275caf1cfb09fd5c144b223769';

@ProviderFor(trendData)
final trendDataProvider = TrendDataProvider._();

final class TrendDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TrendPoint>>,
          List<TrendPoint>,
          FutureOr<List<TrendPoint>>
        >
    with $FutureModifier<List<TrendPoint>>, $FutureProvider<List<TrendPoint>> {
  TrendDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trendDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trendDataHash();

  @$internal
  @override
  $FutureProviderElement<List<TrendPoint>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TrendPoint>> create(Ref ref) {
    return trendData(ref);
  }
}

String _$trendDataHash() => r'db3c0a7a87c0b071dd4fb51848096d611c120f3c';

@ProviderFor(dailyBreakdown)
final dailyBreakdownProvider = DailyBreakdownProvider._();

final class DailyBreakdownProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DailyBreakdownRow>>,
          List<DailyBreakdownRow>,
          FutureOr<List<DailyBreakdownRow>>
        >
    with
        $FutureModifier<List<DailyBreakdownRow>>,
        $FutureProvider<List<DailyBreakdownRow>> {
  DailyBreakdownProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyBreakdownProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyBreakdownHash();

  @$internal
  @override
  $FutureProviderElement<List<DailyBreakdownRow>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DailyBreakdownRow>> create(Ref ref) {
    return dailyBreakdown(ref);
  }
}

String _$dailyBreakdownHash() => r'18095817a4d53900ca93e1c6d26d213895cee304';

@ProviderFor(topTransactionsByAmount)
final topTransactionsByAmountProvider = TopTransactionsByAmountProvider._();

final class TopTransactionsByAmountProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TopTransactionRankItem>>,
          List<TopTransactionRankItem>,
          FutureOr<List<TopTransactionRankItem>>
        >
    with
        $FutureModifier<List<TopTransactionRankItem>>,
        $FutureProvider<List<TopTransactionRankItem>> {
  TopTransactionsByAmountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'topTransactionsByAmountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$topTransactionsByAmountHash();

  @$internal
  @override
  $FutureProviderElement<List<TopTransactionRankItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TopTransactionRankItem>> create(Ref ref) {
    return topTransactionsByAmount(ref);
  }
}

String _$topTransactionsByAmountHash() =>
    r'0b979a3c90b8f986c309741b9bc1556bd87e41f1';
