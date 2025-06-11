import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:math' show cos, sqrt, asin;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Add LocationData model
class LocationData {
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String locationName;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.locationName,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'radius_meters': radiusMeters,
    'location_name': locationName,
  };
}

// Add ActiveSessionData model
class ActiveSessionData {
  final String sessionId;
  final String unitId;
  final DateTime startTime;
  final Map<String, dynamic> sessionData;

  ActiveSessionData({
    required this.sessionId,
    required this.unitId,
    required this.startTime,
    required this.sessionData,
  });

  static ActiveSessionData fromJson(Map<String, dynamic> json) {
    return ActiveSessionData(
      sessionId: json['id'],
      unitId: json['unit_id'],
      startTime: DateTime.parse(json['start_time']),
      sessionData: json['session_data'] ?? {},
    );
  }
}

class PinLocationPage extends StatefulWidget {
  const PinLocationPage({super.key});

  @override
  State<PinLocationPage> createState() => _PinLocationPageState();
}

class _PinLocationPageState extends State<PinLocationPage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  String _currentAddress = "Fetching location...";
  bool _isLoading = false;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {}; // Add circles set for radius visualization
  MapType _currentMapType = MapType.hybrid;
  final String _googleMapsApiKey = 'AIzaSyAIrirIBZFkSNWhUn-M8x8N15gemIv2Pm8';
  int _selectedRadius = 100; // Default radius
  bool _isOnline = true;
  bool _isLocationEnabled = false;
  bool _hasLocationPermission = false;
  String _locationStatus = "Initializing...";
  String? _errorMessage;

  // Tharaka University center coordinates
  final LatLng _tharakaUniversityCenter = const LatLng(-0.0907236, 37.9890077);

  // University area bounds - expanded to include Science Complex
  final LatLngBounds _universityBounds = LatLngBounds(
    southwest: LatLng(-0.0940, 37.9885), // Southwest corner
    northeast: LatLng(-0.0900, 37.9920), // Northeast corner - expanded to include Science Complex
  );

  // Add radius selection options
  final List<int> _radiusOptions = [10, 20, 50, 100, 150, 200];

  // Add Supabase client
  final _supabase = Supabase.instance.client;

  // Add new variables for session selection
  String? selectedSessionId;
  List<ActiveSessionData> activeSessions = [];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadActiveSessions();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _locationStatus = "Checking location services...";
      _errorMessage = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLocationEnabled = false;
          _locationStatus = "Location services are disabled";
          _errorMessage = "Please enable location services to continue";
        });
        return;
      }

      setState(() {
        _isLocationEnabled = true;
        _locationStatus = "Checking location permission...";
      });

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _hasLocationPermission = false;
            _locationStatus = "Location permission denied";
            _errorMessage = "Location permission is required to continue";
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _hasLocationPermission = false;
          _locationStatus = "Location permission permanently denied";
          _errorMessage = "Please enable location permission in app settings";
        });
        return;
      }

      setState(() {
        _hasLocationPermission = true;
        _locationStatus = "Getting your location...";
      });

      await _getCurrentLocation();

    } catch (e) {
      setState(() {
        _locationStatus = "Error initializing location";
        _errorMessage = "Please try again later";
      });
      print("Error initializing location: $e");
    }
  }

  bool _isWithinUniversityBounds(LatLng position) {
    return _universityBounds.contains(position);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // Set initial camera position to Tharaka University area with higher zoom
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _tharakaUniversityCenter,
          zoom: 18.5, // Increased zoom level for better detail
          tilt: 0,
        ),
      ),
    );
  }

  // Update location info display
  String _getLocationDescription(LatLng position) {
    if (_isWithinUniversityBounds(position)) {
      return 'Within Tharaka University Campus';
    }
    return 'Outside Tharaka University Campus';
  }

  void _updateLocationMarker(LatLng position, String title) {
    setState(() {
      // Clear previous markers and circles
      _markers.clear();
      _circles.clear();
      
      // Add the selected location marker
      _markers.add(
        Marker(
          markerId: MarkerId(title),
          position: position,
          infoWindow: InfoWindow(
            title: 'Selected Location',
            snippet: _isWithinUniversityBounds(position) 
                ? 'Within Tharaka University Campus'
                : 'Outside Tharaka University Campus',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      // Add radius circle
      _circles.add(
        Circle(
          circleId: CircleId('radius'),
          center: position,
          radius: _selectedRadius.toDouble(),
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
    });
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.hybrid
          : MapType.normal;
    });
  }

  Future<void> _getCurrentLocation() async {
    if (!_isLocationEnabled || !_hasLocationPermission) {
      return;
    }

    setState(() {
      _isLoading = true;
      _locationStatus = "Getting your location...";
      _errorMessage = null;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );

      setState(() {
        _currentPosition = position;
        _locationStatus = "Location found";
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 19,
              tilt: 0,
            ),
          ),
        );
      }

      // Update location marker
      _updateLocationMarker(
        LatLng(position.latitude, position.longitude),
        'current_location'
      );

      await _getAddressFromCoordinates(position);

    } catch (e) {
      setState(() {
        _locationStatus = "Error getting location";
        _errorMessage = "Please check your GPS signal and try again";
      });
      print("Error getting location: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getAddressFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Placemark place = placemarks[0];
      setState(() {
        if (_isWithinUniversityBounds(LatLng(position.latitude, position.longitude))) {
          _currentAddress = 'Tharaka University Campus\n${place.street ?? ''}, ${place.subLocality ?? ''}, Gatunga, Kenya';
        } else {
          _currentAddress = '${place.name ?? ''} ${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.postalCode ?? ''}, ${place.country ?? ''}';
        }
      });
    } catch (e) {
      setState(() {
        _currentAddress = "Address lookup failed";
        _errorMessage = "Could not determine address";
      });
      print("Error getting address: $e");
    }
  }

  // Add function to load active sessions
  Future<void> _loadActiveSessions() async {
    try {
      final result = await _supabase
        .from('attendance_sessions')
        .select('''
          id,
          unit_id,
          start_time,
          end_time,
          session_data,
          is_active,
          units:unit_id (
            code,
            name
          )
        ''')
        .eq('is_active', true)
        .order('start_time');

      setState(() {
        activeSessions = (result as List)
          .where((session) => 
            session['is_active'] == true && 
            session['session_data'] != null)
          .map((session) => ActiveSessionData.fromJson(session))
          .toList();
      });
    } catch (e) {
      print('Error loading active sessions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading active sessions: $e')),
      );
    }
  }

  // Update save location function
  Future<void> _saveLocation() async {
    if (selectedSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a session first'))
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait for location to be fetched'))
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Fix linter error by using explicit Object type
      final Object sessionId = selectedSessionId!;
      
      await _supabase
        .from('attendance_sessions')
        .update({
          'class_latitude': _currentPosition!.latitude,
          'class_longitude': _currentPosition!.longitude,
          'radius_meters': _selectedRadius,
          'location_required': true
        })
        .eq('id', sessionId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location saved successfully'),
          backgroundColor: Colors.green,
        )
      );
    } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Error saving location: $e'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update session dropdown widget
  Widget _buildSessionDropdown() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(Icons.class_outlined, color: Colors.blue, size: 20),
        ),
        value: selectedSessionId,
        hint: Text('Select Active Unit'),
        isExpanded: true,
        icon: Icon(Icons.arrow_drop_down, color: Colors.blue),
        selectedItemBuilder: (BuildContext context) {
          return activeSessions.map<Widget>((session) {
            final sessionData = session.sessionData;
            final unitCode = sessionData['unit_code'] ?? '';
            return Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.only(left: 50),
              child: Text(
                unitCode,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList();
        },
        items: activeSessions.map((session) {
          final sessionData = session.sessionData;
          final unitCode = sessionData['unit_code'] ?? '';
          
          // Convert UTC time to EAT (UTC+3)
          final utcStartTime = session.startTime;
          final eatStartTime = utcStartTime.add(Duration(hours: 3));
          final startTimeStr = DateFormat('h:mm a').format(eatStartTime);
          
          // Get end time (assuming it's 2 hours after start time)
          final eatEndTime = eatStartTime.add(Duration(hours: 2));
          final endTimeStr = DateFormat('h:mm a').format(eatEndTime);
          
          final dateStr = DateFormat('dd/MM/yyyy').format(eatStartTime);
          
          return DropdownMenuItem<String>(
            value: session.sessionId,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    unitCode,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '$dateStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$startTimeStr - $endTimeStr EAT',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: (String? value) {
          if (value != null) {
            setState(() {
              selectedSessionId = value;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pin Location'),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildSessionDropdown(),
          if (_errorMessage != null)
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          if (_locationStatus != "Location found")
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(_locationStatus),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _tharakaUniversityCenter,
                    zoom: 19,
                    tilt: 0,
                  ),
                  markers: _markers,
                  circles: _circles,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapType: _currentMapType,
                  buildingsEnabled: false,
                  indoorViewEnabled: false,
                ),
                // Keep existing location info panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading)
                    Center(child: CircularProgressIndicator())
                  else if (_currentPosition != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Location:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _currentAddress,
                          style: TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Coordinates: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                              SizedBox(height: 8),
                              // Add radius slider
                              Row(
                                children: [
                            Icon(Icons.radio_button_checked, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Radius: $_selectedRadius m',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                                  Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: Colors.blue,
                                  inactiveTrackColor: Colors.blue.withOpacity(0.2),
                                  thumbColor: Colors.blue,
                                  overlayColor: Colors.blue.withOpacity(0.2),
                                  valueIndicatorColor: Colors.blue,
                                  valueIndicatorTextStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                    child: Slider(
                                      value: _selectedRadius.toDouble(),
                                      min: 20,
                                      max: 200,
                                      divisions: 18,
                                      label: '${_selectedRadius}m',
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedRadius = value.round();
                                          if (_currentPosition != null) {
                                            _updateLocationMarker(
                                              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                              'current_location',
                                            );
                                          }
                                        });
                                      },
                                ),
                                    ),
                                  ),
                                ],
                              ),
                        if (_isWithinUniversityBounds(
                          LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        ))
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              '📍 Within Tharaka University Campus',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    Text(
                      'Unable to get location',
                      style: TextStyle(fontSize: 16),
                    ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _getCurrentLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('Refresh Location'),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('Save Location'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 