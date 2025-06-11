import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

enum NetworkStatus {
  online,
  offline,
  slow,
  noData
}

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivity = Connectivity();
  final _internetChecker = InternetConnectionChecker();
  final _controller = StreamController<NetworkStatus>.broadcast();
  Timer? _timer;
  bool _isInitialized = false;

  Stream<NetworkStatus> get statusStream => _controller.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen(_checkStatus);
    
    // Initial check
    await _checkStatus(await _connectivity.checkConnectivity());

    // Periodic check for internet quality
    _timer = Timer.periodic(Duration(seconds: 30), (_) => _checkInternetQuality());
  }

  Future<void> _checkStatus(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      _controller.add(NetworkStatus.offline);
      return;
    }

    // Check actual internet connectivity
    bool hasInternet = await _internetChecker.hasConnection;
    if (!hasInternet) {
      _controller.add(NetworkStatus.noData);
      return;
    }

    await _checkInternetQuality();
  }

  Future<void> _checkInternetQuality() async {
    try {
      // Check connection speed by timing a simple request
      final stopwatch = Stopwatch()..start();
      final result = await InternetConnectionChecker().hasConnection;
      stopwatch.stop();

      if (!result) {
        _controller.add(NetworkStatus.offline);
        return;
      }

      // If request takes more than 2 seconds, consider it slow
      if (stopwatch.elapsedMilliseconds > 2000) {
        _controller.add(NetworkStatus.slow);
      } else {
        _controller.add(NetworkStatus.online);
      }
    } catch (e) {
      _controller.add(NetworkStatus.offline);
    }
  }

  Future<NetworkStatus> checkCurrentStatus() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return NetworkStatus.offline;
    }

    bool hasInternet = await _internetChecker.hasConnection;
    if (!hasInternet) {
      return NetworkStatus.noData;
    }

    return NetworkStatus.online;
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
} 