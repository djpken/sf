import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Provides real-time connectivity status and a stream of changes.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  late final Stream<bool> onConnectivityChanged;
  bool _isOnline = true;

  ConnectivityService() {
    onConnectivityChanged = _connectivity.onConnectivityChanged
        .map((result) => _isConnected(result))
        .distinct()
      ..listen((online) => _isOnline = online);
  }

  bool get isOnline => _isOnline;

  Future<void> init() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(result);
  }

  bool _isConnected(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }
}
