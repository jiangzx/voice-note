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

String _$periodSummaryHash() => r'1f51491fb722abc6ffc4f4abe168d4a92301c2a8';

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

String _$categorySummaryHash() => r'81431beb11c7506a8d803d83c293ead00df5b069';

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

String _$trendDataHash() => r'3a356d829d81f2c89c545948ad87e07aff4c1d80';
