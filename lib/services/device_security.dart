import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:io';
import 'dart:convert';

class DeviceSecurityService {
  static final DeviceSecurityService _instance = DeviceSecurityService._internal();
  factory DeviceSecurityService() => _instance;
  DeviceSecurityService._internal();

  Future<Map<String, dynamic>> getDeviceSecurityInfo() async {
    try {
      // Get location with accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Check for mock location
      bool isMockLocation = false;
      if (Platform.isAndroid) {
        isMockLocation = await Geolocator.isLocationServiceEnabled() &&
            position.isMocked;
      }

      // Get device info
      final deviceInfo = await DeviceInfoPlugin().deviceInfo;
      final deviceId = Platform.isAndroid
          ? (deviceInfo as AndroidDeviceInfo).id
          : (deviceInfo as IosDeviceInfo).identifierForVendor;

      // Get network info
      final networkInfo = NetworkInfo();
      final wifiName = await networkInfo.getWifiName();
      final wifiBSSID = await networkInfo.getWifiBSSID();
      
      return {
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': position.timestamp?.toIso8601String(),
        },
        'device': {
          'id': deviceId,
          'is_mock_location': isMockLocation,
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        },
        'network': {
          'wifi_name': wifiName,
          'wifi_bssid': wifiBSSID,
        }
      };
    } catch (e) {
      print('Error getting device security info: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<bool> validateLocation(double classLat, double classLon, double maxDistanceMeters) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        classLat,
        classLon,
      );

      return distanceInMeters <= maxDistanceMeters;
    } catch (e) {
      print('Error validating location: $e');
      return false;
    }
  }
} 