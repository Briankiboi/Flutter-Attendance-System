import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:math' show cos, sqrt, asin, sin;
import 'dart:io';

class DeviceSecurityService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<bool> checkNetworkConnectivity() async {
    return await InternetConnectionChecker().hasConnection;
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final deviceInfo = await _deviceInfo.deviceInfo;
      final packageInfo = await PackageInfo.fromPlatform();
      
      String deviceModel = 'unknown';
      String deviceId = 'unknown';
      String platform = Platform.operatingSystem;
      String osVersion = Platform.operatingSystemVersion;
      
      if (Platform.isAndroid) {
        final androidInfo = deviceInfo as AndroidDeviceInfo;
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        deviceId = androidInfo.id;
        platform = 'Android';
        osVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = deviceInfo as IosDeviceInfo;
        deviceModel = iosInfo.model;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
        platform = 'iOS';
        osVersion = iosInfo.systemVersion;
      }
      
      print('DEBUG: Device Model: $deviceModel'); // Debug log
      
      return {
        'device_id': deviceId,
        'device_model': deviceModel,
        'platform': platform,
        'os_version': osVersion,
        'app_version': packageInfo.version,
      };
    } catch (e) {
      print('Error getting device info: $e');
      return {
        'device_id': 'unknown',
        'device_model': 'unknown',
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'app_version': 'unknown',
      };
    }
  }

  Future<Map<String, dynamic>> getLocationInfo() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions permanently denied');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
    );

    final isMockLocation = await Geolocator.getCurrentPosition(
      forceAndroidLocationManager: true
    ).then((_) => false).catchError((_) => true);

    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'is_mock_location': isMockLocation,
    };
  }

  Future<Map<String, dynamic>> getNetworkInfo() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return {
      'type': connectivityResult.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Check for mock locations
  Future<bool> checkMockLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      return position.isMocked;
    } catch (e) {
      print('Error checking mock location: $e');
      return false;
    }
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Calculate distance between two points in meters
  double calculateDistance(
    double lat1, 
    double lon1, 
    double lat2, 
    double lon2
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    // Convert latitude and longitude to radians
    final double phi1 = lat1 * (3.141592653589793 / 180);
    final double phi2 = lat2 * (3.141592653589793 / 180);
    final double deltaPhi = (lat2 - lat1) * (3.141592653589793 / 180);
    final double deltaLambda = (lon2 - lon1) * (3.141592653589793 / 180);

    final double a = sin(deltaPhi/2) * sin(deltaPhi/2) +
        cos(phi1) * cos(phi2) *
        sin(deltaLambda/2) * sin(deltaLambda/2);
    
    final double c = 2 * asin(sqrt(a));
    return earthRadius * c; // Distance in meters
  }

  Future<Map<String, dynamic>> getDeviceSecurityInfo() async {
    try {
      // Get device info
      String deviceId;
      bool isEmulator = false;

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        isEmulator = !androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
        isEmulator = !iosInfo.isPhysicalDevice;
      } else {
        deviceId = 'unsupported_platform';
        isEmulator = false;
      }

      // Get network info
      final wifiName = await _networkInfo.getWifiName() ?? 'unknown';
      final wifiBSSID = await _networkInfo.getWifiBSSID() ?? 'unknown';
      final wifiIP = await _networkInfo.getWifiIP() ?? 'unknown';

      // Get location accuracy and mock status
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      return {
        'device_id': deviceId,
        'is_emulator': isEmulator,
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'location_accuracy': position.accuracy,
        'is_mock_location': position.isMocked ?? false,
        'network_info': {
          'wifi_name': wifiName,
          'wifi_bssid': wifiBSSID,
          'wifi_ip': wifiIP,
          'connection_type': 'wifi', // You can expand this with cellular detection
        },
      };
    } catch (e) {
      return {
        'device_id': 'error',
        'is_emulator': false,
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'location_accuracy': 0.0,
        'is_mock_location': false,
        'network_info': {
          'wifi_name': 'unknown',
          'wifi_bssid': 'unknown',
          'wifi_ip': 'unknown',
          'connection_type': 'unknown',
        },
      };
    }
  }
} 