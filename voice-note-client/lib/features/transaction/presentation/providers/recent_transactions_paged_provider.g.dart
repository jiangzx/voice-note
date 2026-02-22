// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_transactions_paged_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RecentTransactionsPaged)
final recentTransactionsPagedProvider = RecentTransactionsPagedProvider._();

final class RecentTransactionsPagedProvider
    extends
        $NotifierProvider<
          RecentTransactionsPaged,
          RecentTransactionsPagedState
        > {
  RecentTransactionsPagedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentTransactionsPagedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentTransactionsPagedHash();

  @$internal
  @override
  RecentTransactionsPaged create() => RecentTransactionsPaged();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecentTransactionsPagedState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecentTransactionsPagedState>(value),
    );
  }
}

String _$recentTransactionsPagedHash() =>
    r'a0978ca3dfd0637cc589665704932ab7677a0803';

abstract class _$RecentTransactionsPaged
    extends $Notifier<RecentTransactionsPagedState> {
  RecentTransactionsPagedState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<RecentTransactionsPagedState, RecentTransactionsPagedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                RecentTransactionsPagedState,
                RecentTransactionsPagedState
              >,
              RecentTransactionsPagedState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
