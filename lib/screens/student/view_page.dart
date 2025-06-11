import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class ViewPage extends StatefulWidget {
  const ViewPage({super.key});

  @override
  _ViewPageState createState() => _ViewPageState();
}

class _ViewPageState extends State<ViewPage> {
  File? _selectedImage;
  String? _storedImagePath;
  String? _userEmail;
  String? _userName;
  bool _isLoading = false;
  bool _isFullScreen = false;
  Orientation? _forcedOrientation;
  
  @override
  void initState() {
    super.initState();
    // Delay to allow context to be available
    Future.microtask(() {
      _getUserInfo();
      _loadSavedImage();
    });
  }
  
  @override
  void dispose() {
    // Reset to portrait orientation when leaving the page
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }
  
  Future<void> _getUserInfo() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        _userEmail = args['email'] ?? args['lectureNumber'];
        _userName = args['name'];
      });
    }
  }
  
  Future<void> _loadSavedImage() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get user-specific key
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final String userKey = args?['email'] ?? args?['lectureNumber'] ?? 'default_user';
      
      final savedImagePath = prefs.getString('timetable_image_$userKey');
      
      if (savedImagePath != null) {
        final file = File(savedImagePath);
        if (await file.exists()) {
          setState(() {
            _storedImagePath = savedImagePath;
          });
        } else {
          // If file doesn't exist anymore, clear the reference
          prefs.remove('timetable_image_$userKey');
        }
      }
    } catch (e) {
      print('Error loading saved image: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    
    // Set orientation based on fullscreen state
    if (_isFullScreen) {
      // Allow all orientations in fullscreen
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Reset orientation when exiting fullscreen
      _resetOrientation();
    }
  }
  
  void _rotateToLandscape() {
    setState(() {
      _forcedOrientation = Orientation.landscape;
      _isFullScreen = true;
    });
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Show a tip to the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rotated to landscape mode. Tap image to exit fullscreen.'),
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  void _rotateToPortrait() {
    setState(() {
      _forcedOrientation = Orientation.portrait;
      _isFullScreen = true;
    });
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  
  void _resetOrientation() {
    setState(() {
      _forcedOrientation = null;
    });
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
  
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (pickedImage != null) {
        // Get user-specific key
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final String userKey = args?['email'] ?? args?['lectureNumber'] ?? 'default_user';
        
        setState(() {
          _selectedImage = File(pickedImage.path);
          _storedImagePath = pickedImage.path;
        });
        
        // Save the image path to SharedPreferences with user-specific key
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('timetable_image_$userKey', pickedImage.path);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timetable image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildImageView(Orientation orientation) {
    if (_selectedImage != null || (_storedImagePath != null && File(_storedImagePath!).existsSync())) {
      final imageFile = _selectedImage ?? File(_storedImagePath!);
      
      // Determine if image should be shown in a smaller preview or fullscreen
      final isSmallPreview = !_isFullScreen && orientation == Orientation.portrait;
      
      return GestureDetector(
        onTap: _isFullScreen ? _toggleFullScreen : () {
          setState(() {
            _isFullScreen = true;
          });
          // Allow all orientations when entering fullscreen
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        },
        child: InteractiveViewer(
          boundaryMargin: EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Container(
            width: double.infinity,
            height: isSmallPreview 
                ? 300
                : orientation == Orientation.portrait
                    ? MediaQuery.of(context).size.height * 0.7
                    : MediaQuery.of(context).size.height * 0.85,
            decoration: isSmallPreview
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: isSmallPreview
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.contain,
                      errorBuilder: _buildErrorWidget,
                    ),
                  )
                : Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                    errorBuilder: _buildErrorWidget,
                  ),
          ),
        ),
      );
    } else {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: Colors.blue.shade200,
            ),
            SizedBox(height: 16),
            Text(
              'No timetable image uploaded',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the button below to upload',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }
  }
  
  Widget _buildErrorWidget(BuildContext context, Object error, StackTrace? stackTrace) {
    final isFullScreen = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isFullScreen ? Colors.black : Colors.grey.shade100,
        borderRadius: isFullScreen ? null : BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported, 
            size: 48, 
            color: isFullScreen ? Colors.white54 : Colors.grey
          ),
          SizedBox(height: 16),
          Text(
            'Error loading image. Please try updating.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isFullScreen ? Colors.white70 : Colors.grey.shade700
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentOrientation = _forcedOrientation ?? MediaQuery.of(context).orientation;
    final isLandscape = currentOrientation == Orientation.landscape;
    final hasImage = _selectedImage != null || (_storedImagePath != null && File(_storedImagePath!).existsSync());
    
    return OrientationBuilder(
      builder: (context, orientation) {
        return Scaffold(
          appBar: _isFullScreen && isLandscape
              ? null  // Hide app bar in landscape fullscreen mode
              : AppBar(
                  title: Text('View Page'),
                  actions: [
                    if (hasImage)
                      IconButton(
                        icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
                        onPressed: _toggleFullScreen,
                        tooltip: _isFullScreen ? 'Exit fullscreen' : 'Enter fullscreen',
                      ),
                    if (hasImage && !_isFullScreen)
                      IconButton(
                        icon: Icon(Icons.screen_rotation),
                        onPressed: _rotateToLandscape,
                        tooltip: 'View in landscape mode',
                      ),
                  ],
                ),
          body: _isLoading 
            ? Center(child: CircularProgressIndicator())
            : isLandscape && _isFullScreen && hasImage
                ? Stack(
                    children: [
                      // Full screen image in landscape mode
                      Container(
                        color: Colors.black,
                        width: double.infinity,
                        height: double.infinity,
                        child: _buildImageView(orientation),
                      ),
                      // Floating action buttons in landscape
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Column(
                          children: [
                            FloatingActionButton(
                              mini: true,
                              onPressed: _toggleFullScreen,
                              backgroundColor: Colors.black54,
                              tooltip: 'Exit fullscreen',
                              child: Icon(Icons.fullscreen_exit),
                            ),
                            SizedBox(height: 8),
                            FloatingActionButton(
                              mini: true,
                              onPressed: _rotateToPortrait,
                              backgroundColor: Colors.black54,
                              tooltip: 'Rotate to portrait',
                              child: Icon(Icons.screen_rotation),
                            ),
                            SizedBox(height: 8),
                            FloatingActionButton(
                              mini: true,
                              onPressed: _pickImage,
                              backgroundColor: Colors.black54,
                              tooltip: 'Update image',
                              child: Icon(Icons.upload_file),
                            ),
                          ],
                        ),
                      ),
                      // Help text
                      Positioned(
                        bottom: 20,
                        left: 20,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Pinch to zoom • Tap to exit fullscreen',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!_isFullScreen || !hasImage)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Your Timetable',
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Upload a timetable image from your device to display here.',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 20),
                                      ],
                                    ),
                                  
                                  // Display the uploaded image with zooming capability
                                  _buildImageView(orientation),
                                  
                                  SizedBox(height: 24),
                                  
                                  // Upload button
                                  ElevatedButton.icon(
                                    onPressed: _pickImage,
                                    icon: Icon(Icons.upload_file),
                                    label: Text(hasImage
                                      ? 'Update Timetable Image'
                                      : 'Upload Timetable Image'
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      minimumSize: Size(double.infinity, 56),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  
                                  if (hasImage && !_isFullScreen)
                                    Padding(
                                      padding: EdgeInsets.only(top: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: _rotateToLandscape,
                                            icon: Icon(Icons.screen_rotation),
                                            label: Text('View in Landscape'),
                                            style: OutlinedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              foregroundColor: Colors.blue,
                                              side: BorderSide(color: Colors.blue.shade300),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
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
                  ),
          bottomSheet: _isFullScreen && !isLandscape && hasImage
            ? Container(
                color: Colors.black.withOpacity(0.7),
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pinch to zoom in/out',
                      style: TextStyle(color: Colors.white),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.screen_rotation, color: Colors.white),
                          onPressed: _rotateToLandscape,
                          tooltip: 'Rotate to landscape',
                        ),
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: Icon(Icons.upload_file, size: 18),
                          label: Text('Update'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : null,
        );
      }
    );
  }
} 