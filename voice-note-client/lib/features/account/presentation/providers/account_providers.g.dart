// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountRepository)
final accountRepositoryProvider = AccountRepositoryProvider._();

final class AccountRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountRepository>,
          AccountRepository,
          FutureOr<AccountRepository>
        >
    with
        $FutureModifier<AccountRepository>,
        $FutureProvider<AccountRepository> {
  AccountRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<AccountRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AccountRepository> create(Ref ref) {
    return accountRepository(ref);
  }
}

String _$accountRepositoryHash() => r'6e9a9b562bfa0e5fafab1edbbbf7f881375a85a5';

@ProviderFor(accountList)
final accountListProvider = AccountListProvider._();

final class AccountListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AccountEntity>>,
          List<AccountEntity>,
          FutureOr<List<AccountEntity>>
        >
    with
        $FutureModifier<List<AccountEntity>>,
        $FutureProvider<List<AccountEntity>> {
  AccountListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountListHash();

  @$internal
  @override
  $FutureProviderElement<List<AccountEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AccountEntity>> create(Ref ref) {
    return accountList(ref);
  }
}

String _$accountListHash() => r'4d752baa9b94db7112624c735bcb8cb41a7b69df';

@ProviderFor(defaultAccount)
final defaultAccountProvider = DefaultAccountProvider._();

final class DefaultAccountProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountEntity?>,
          AccountEntity?,
          FutureOr<AccountEntity?>
        >
    with $FutureModifier<AccountEntity?>, $FutureProvider<AccountEntity?> {
  DefaultAccountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultAccountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultAccountHash();

  @$internal
  @override
  $FutureProviderElement<AccountEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AccountEntity?> create(Ref ref) {
    return defaultAccount(ref);
  }
}

String _$defaultAccountHash() => r'01abc7f65b9968bb78c68b1eabd4e138d1b417af';

@ProviderFor(multiAccountEnabled)
final multiAccountEnabledProvider = MultiAccountEnabledProvider._();

final class MultiAccountEnabledProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  MultiAccountEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'multiAccountEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$multiAccountEnabledHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return multiAccountEnabled(ref);
  }
}

String _$multiAccountEnabledHash() =>
    r'110ec07ea5f92cd45f523036664dea47c6a57a6f';
