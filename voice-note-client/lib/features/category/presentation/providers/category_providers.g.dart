// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(categoryRepository)
final categoryRepositoryProvider = CategoryRepositoryProvider._();

final class CategoryRepositoryProvider
    extends
        $FunctionalProvider<
          CategoryRepository,
          CategoryRepository,
          CategoryRepository
        >
    with $Provider<CategoryRepository> {
  CategoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<CategoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CategoryRepository create(Ref ref) {
    return categoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryRepository>(value),
    );
  }
}

String _$categoryRepositoryHash() =>
    r'a7ed6d1e30cc96ebbd21c782f393ea82667819ae';

@ProviderFor(visibleCategories)
final visibleCategoriesProvider = VisibleCategoriesFamily._();

final class VisibleCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CategoryEntity>>,
          List<CategoryEntity>,
          FutureOr<List<CategoryEntity>>
        >
    with
        $FutureModifier<List<CategoryEntity>>,
        $FutureProvider<List<CategoryEntity>> {
  VisibleCategoriesProvider._({
    required VisibleCategoriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'visibleCategoriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$visibleCategoriesHash();

  @override
  String toString() {
    return r'visibleCategoriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CategoryEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CategoryEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return visibleCategories(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VisibleCategoriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$visibleCategoriesHash() => r'd1fe8940f724684e7b59fefc14652a72be4ef012';

final class VisibleCategoriesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<CategoryEntity>>, String> {
  VisibleCategoriesFamily._()
    : super(
        retry: null,
        name: r'visibleCategoriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  VisibleCategoriesProvider call(String type) =>
      VisibleCategoriesProvider._(argument: type, from: this);

  @override
  String toString() => r'visibleCategoriesProvider';
}

@ProviderFor(recentCategories)
final recentCategoriesProvider = RecentCategoriesProvider._();

final class RecentCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  RecentCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentCategoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentCategoriesHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return recentCategories(ref);
  }
}

String _$recentCategoriesHash() => r'8ee2dcece7d42a0d81b756e2bcee1648f664f6e0';

@ProviderFor(recommendedCategoryNames)
final recommendedCategoryNamesProvider = RecommendedCategoryNamesProvider._();

final class RecommendedCategoryNamesProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  RecommendedCategoryNamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recommendedCategoryNamesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recommendedCategoryNamesHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return recommendedCategoryNames(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$recommendedCategoryNamesHash() =>
    r'3c0869621d5e9ef5da4562bccf516b4229a5e615';
