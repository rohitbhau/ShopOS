// Connectivity manager - monitors network status and triggers auto-sync
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityManager extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  
  bool _isOnline = false;
  DateTime? _lastOnlineTime;
  DateTime? _lastOfflineTime;
  final List<Function()> _onlineCallbacks = [];

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  DateTime? get lastOnlineTime => _lastOnlineTime;
  DateTime? get lastOfflineTime => _lastOfflineTime;

  ConnectivityManager() {
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('Failed to check connectivity: $e');
      _isOnline = false;
      notifyListeners();
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    if (!wasOnline && _isOnline) {
      // Just came online
      _lastOnlineTime = DateTime.now();
      print('🟢 Network connected');
      
      // Trigger all registered callbacks
      for (final callback in _onlineCallbacks) {
        callback();
      }
    } else if (wasOnline && !_isOnline) {
      // Just went offline
      _lastOfflineTime = DateTime.now();
      print('🔴 Network disconnected');
    }

    notifyListeners();
  }

  // Register a callback to be called when network comes back online
  void registerOnlineCallback(Function() callback) {
    _onlineCallbacks.add(callback);
  }

  // Unregister a callback
  void unregisterOnlineCallback(Function() callback) {
    _onlineCallbacks.remove(callback);
  }

  // Check if we can perform network operations
  Future<bool> canPerformNetworkOperations() async {
    if (!_isOnline) return false;

    try {
      // Additional check: try to resolve a DNS
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  String getConnectionType() {
    // This is simplified; in real implementation, query actual connection type
    if (_isOnline) {
      return 'Connected';
    } else {
      return 'Offline';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _onlineCallbacks.clear();
    super.dispose();
  }
}
