import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_attendance/services/supabase_service.dart';
import 'package:qr_attendance/services/attendance_service.dart';
import 'package:qr_attendance/services/device_security_service.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';

class QRScannerScreen extends StatefulWidget {
  final Function(String) onQRCodeScanned;
  final bool isWithinRadius;
  final Map<String, dynamic> activeSession;
  final Position currentPosition;

  const QRScannerScreen({
    Key? key,
    required this.onQRCodeScanned,
    required this.isWithinRadius,
    required this.activeSession,
    required this.currentPosition,
  }) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final AttendanceService _attendanceService = AttendanceService();
  final DeviceSecurityService _deviceSecurity = DeviceSecurityService();
  
  late final MobileScannerController _scannerController;
  bool _isTorchOn = false;
  bool _isScanning = false;
  String? _errorMessage;
  bool _isProcessing = false;
  double _zoomLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _processQRCode(String qrData) async {
    try {
      // Get device security info
      final deviceSecurityInfo = await _deviceSecurity.getDeviceSecurityInfo();
      final deviceInfo = await _deviceSecurity.getDeviceInfo();
      
      final completeDeviceInfo = {
        ...deviceSecurityInfo,
        'app_version': deviceInfo['app_version'],
        'device_model': deviceInfo['device_model'] ?? 'unknown',
        'model': deviceInfo['device_model'] ?? 'unknown',
        'device_id': deviceInfo['device_id'] ?? deviceSecurityInfo['device_id'] ?? 'unknown',
        'platform': deviceInfo['platform'] ?? Platform.operatingSystem,
        'os_version': deviceInfo['os_version'] ?? Platform.operatingSystemVersion,
      };

      // Mark attendance
      final result = await _attendanceService.markAttendance(
        sessionId: widget.activeSession['id'],
        studentId: _supabaseService.getCurrentUser()!['student_id'],
        latitude: widget.currentPosition.latitude,
        longitude: widget.currentPosition.longitude,
        markMethod: 'QR_CODE',
        markValue: qrData,
        deviceInfo: completeDeviceInfo,
      );

      if (result['success']) {
        widget.onQRCodeScanned(qrData);
      } else {
        setState(() {
          _errorMessage = result['message'];
          _isProcessing = false;
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing QR code: ${e.toString()}';
        _isProcessing = false;
        _isScanning = false;
      });
    }
  }

  void _onQRCodeDetected(BarcodeCapture capture) async {
    if (_isProcessing || _isScanning) return;

    try {
      setState(() {
        _isProcessing = true;
        _isScanning = true;
        _errorMessage = null;
      });

      final List<Barcode> barcodes = capture.barcodes;
      if (barcodes.isEmpty || barcodes[0].rawValue == null) {
        setState(() {
          _errorMessage = 'Invalid QR code';
          _isProcessing = false;
          _isScanning = false;
        });
        return;
      }

      final qrData = barcodes[0].rawValue!;
      await _processQRCode(qrData);

    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing QR code: ${e.toString()}';
        _isProcessing = false;
        _isScanning = false;
      });
    }
  }

  void _handleZoomChanged(double value) {
    setState(() {
      _zoomLevel = value;
    });
    _scannerController.setZoomScale(value);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isProcessing) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Processing in Progress'),
              content: Text('Are you sure you want to cancel the scanning process?'),
              actions: [
                TextButton(
                  child: Text('No'),
                  onPressed: () => Navigator.pop(context, false),
                ),
                TextButton(
                  child: Text('Yes'),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Scan QR Code'),
          backgroundColor: Colors.blue,
        ),
        body: Stack(
          children: [
            // QR Scanner
            Container(
              color: Colors.black,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onQRCodeDetected,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isScanning ? Colors.green : Colors.white,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Stack(
                              children: [
                                Positioned(top: 0, left: 0, child: _buildCorner(true, true)),
                                Positioned(top: 0, right: 0, child: _buildCorner(true, false)),
                                Positioned(bottom: 0, left: 0, child: _buildCorner(false, true)),
                                Positioned(bottom: 0, right: 0, child: _buildCorner(false, false)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Top Status Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _isProcessing 
                                  ? Colors.blue 
                                  : _isScanning 
                                      ? Colors.green 
                                      : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            _isProcessing 
                                ? 'Processing...' 
                                : _isScanning 
                                    ? 'Scanning' 
                                    : 'Ready',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        _scannerController.toggleTorch();
                        setState(() => _isTorchOn = !_isTorchOn);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Section with Zoom Slider
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom Slider
                    Row(
                      children: [
                        Icon(Icons.zoom_out, color: Colors.white),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white.withOpacity(0.3),
                              thumbColor: Colors.white,
                              trackHeight: 3,
                              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                            ),
                            child: Slider(
                              value: _zoomLevel,
                              min: 0.0,
                              max: 1.0,
                              onChanged: _handleZoomChanged,
                            ),
                          ),
                        ),
                        Icon(Icons.zoom_in, color: Colors.white),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Guide Text
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner, color: Colors.white70),
                          SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Position QR code within frame',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(bool isTop, bool isLeft) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          left: isLeft ? BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          right: !isLeft ? BorderSide(color: Colors.white, width: 3) : BorderSide.none,
        ),
      ),
    );
  }
} 