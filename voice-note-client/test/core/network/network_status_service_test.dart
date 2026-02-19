import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/network/network_status_service.dart';

void main() {
  group('NetworkStatusService', () {
    test('isOnline defaults to true', () {
      final service = NetworkStatusService();
      expect(service.isOnline, isTrue);
    });

    test('init updates status from connectivity check', () async {
      final fake = _FakeConnectivity(
        initialResults: [ConnectivityResult.none],
      );
      final service = NetworkStatusService(connectivity: fake);

      await service.init();

      expect(service.isOnline, isFalse);
      await service.dispose();
    });

    test('detects wifi as online', () async {
      final fake = _FakeConnectivity(
        initialResults: [ConnectivityResult.wifi],
      );
      final service = NetworkStatusService(connectivity: fake);

      await service.init();

      expect(service.isOnline, isTrue);
      await service.dispose();
    });

    test('stream emits changes on connectivity transitions', () async {
      final fake = _FakeConnectivity(
        initialResults: [ConnectivityResult.wifi],
      );
      final service = NetworkStatusService(connectivity: fake);
      await service.init();

      final statuses = <bool>[];
      final sub = service.onStatusChange.listen(statuses.add);

      // Go offline
      fake.emitChange([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);

      expect(service.isOnline, isFalse);
      expect(statuses, [false]);

      // Go back online
      fake.emitChange([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);

      expect(service.isOnline, isTrue);
      expect(statuses, [false, true]);

      await sub.cancel();
      await service.dispose();
    });

    test('does not emit when status unchanged', () async {
      final fake = _FakeConnectivity(
        initialResults: [ConnectivityResult.wifi],
      );
      final service = NetworkStatusService(connectivity: fake);
      await service.init();

      final statuses = <bool>[];
      final sub = service.onStatusChange.listen(statuses.add);

      // Still online (wifi → mobile)
      fake.emitChange([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);

      expect(statuses, isEmpty);

      await sub.cancel();
      await service.dispose();
    });
  });
}

/// Fake Connectivity for testing.
class _FakeConnectivity implements Connectivity {
  final List<ConnectivityResult> initialResults;
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  _FakeConnectivity({required this.initialResults});

  void emitChange(List<ConnectivityResult> results) {
    _controller.add(results);
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => initialResults;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;
}
