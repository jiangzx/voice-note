import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors network connectivity status.
///
/// Provides a reactive stream for connectivity changes and a synchronous
/// getter for the last known status.
class NetworkStatusService {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  NetworkStatusService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// Whether the device currently has network connectivity.
  bool get isOnline => _isOnline;

  /// Stream of connectivity changes (true = online, false = offline).
  Stream<bool> get onStatusChange => _controller.stream;

  /// Start monitoring connectivity. Call once at app startup.
  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(results);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(online);
      }
    });
  }

  /// Release resources.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }
}
