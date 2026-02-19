// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_form_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(transactionRepository)
final transactionRepositoryProvider = TransactionRepositoryProvider._();

final class TransactionRepositoryProvider
    extends
        $FunctionalProvider<
          TransactionRepository,
          TransactionRepository,
          TransactionRepository
        >
    with $Provider<TransactionRepository> {
  TransactionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionRepositoryHash();

  @$internal
  @override
  $ProviderElement<TransactionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionRepository create(Ref ref) {
    return transactionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionRepository>(value),
    );
  }
}

String _$transactionRepositoryHash() =>
    r'7dca9c87f69f55597a94bb08cea0ad0526d9cb99';

@ProviderFor(TransactionForm)
final transactionFormProvider = TransactionFormProvider._();

final class TransactionFormProvider
    extends $NotifierProvider<TransactionForm, TransactionFormState> {
  TransactionFormProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionFormProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionFormHash();

  @$internal
  @override
  TransactionForm create() => TransactionForm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionFormState>(value),
    );
  }
}

String _$transactionFormHash() => r'508aac8ff1bfa7d9032e2352f5d65eef42775789';

abstract class _$TransactionForm extends $Notifier<TransactionFormState> {
  TransactionFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TransactionFormState, TransactionFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TransactionFormState, TransactionFormState>,
              TransactionFormState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
