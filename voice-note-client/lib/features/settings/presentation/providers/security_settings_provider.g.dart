// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(secureStorage)
final secureStorageProvider = SecureStorageProvider._();

final class SecureStorageProvider
    extends
        $FunctionalProvider<
          FlutterSecureStorage,
          FlutterSecureStorage,
          FlutterSecureStorage
        >
    with $Provider<FlutterSecureStorage> {
  SecureStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureStorageHash();

  @$internal
  @override
  $ProviderElement<FlutterSecureStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FlutterSecureStorage create(Ref ref) {
    return secureStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlutterSecureStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlutterSecureStorage>(value),
    );
  }
}

String _$secureStorageHash() => r'97f21970d5a31566856cff3edf2185f36a625602';

@ProviderFor(SecuritySettings)
final securitySettingsProvider = SecuritySettingsProvider._();

final class SecuritySettingsProvider
    extends $NotifierProvider<SecuritySettings, SecuritySettingsState> {
  SecuritySettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'securitySettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$securitySettingsHash();

  @$internal
  @override
  SecuritySettings create() => SecuritySettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecuritySettingsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecuritySettingsState>(value),
    );
  }
}

String _$securitySettingsHash() => r'bb007618ef07ae08232938d0af9a5ec9e0e05e4b';

abstract class _$SecuritySettings extends $Notifier<SecuritySettingsState> {
  SecuritySettingsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SecuritySettingsState, SecuritySettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SecuritySettingsState, SecuritySettingsState>,
              SecuritySettingsState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
