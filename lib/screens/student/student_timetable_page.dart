import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';

class StudentTimetablePage extends StatefulWidget {
  const StudentTimetablePage({super.key});

  @override
  _StudentTimetablePageState createState() => _StudentTimetablePageState();
}

class _StudentTimetablePageState extends State<StudentTimetablePage> {
  File? _timetableImage;
  String? _email;
  bool _isLoading = true;
  bool _hasTimetable = false;
  
  @override
  void initState() {
    super.initState();
    _loadTimetableImage();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we received user data from arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args.containsKey('email')) {
      if (_email != args['email']) {
        setState(() {
          _email = args['email'];
        });
        // Reload timetable if email changed
        _loadTimetableImage();
      }
    }
  }
  
  @override
  void dispose() {
    // Reset to portrait orientation when leaving the page
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }
  
  Future<void> _loadTimetableImage() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // If we already have an email from arguments, use it
      if (_email == null || _email!.isEmpty) {
        // Get the current user email
        final prefs = await SharedPreferences.getInstance();
        _email = prefs.getString('current_user_email');
        
        if (_email == null || _email!.isEmpty) {
          // Try legacy keys if the current key doesn't exist
          _email = prefs.getString('currentUser') ?? 
                   prefs.getString('currentUserEmail');
        }
      }

      if (_email == null || _email!.isEmpty) {
        print('Error: No user email found in preferences');
        setState(() {
          _isLoading = false;
          _hasTimetable = false;
        });
        return;
      }

      print('Loading timetable for user: $_email');

      // First check if we have a saved path in preferences
      final prefs = await SharedPreferences.getInstance();
      
      // Make sure we use the user-specific timetable path
      final savedPath = prefs.getString('user_timetable_path_$_email');
      
      if (savedPath != null && savedPath.isNotEmpty) {
        final savedFile = File(savedPath);
        if (await savedFile.exists()) {
          setState(() {
            _timetableImage = savedFile;
            _hasTimetable = true;
            _isLoading = false;
          });
          print('Timetable found from saved path: $savedPath');
          return;
        } else {
          // If the file doesn't exist anymore, remove the reference
          await prefs.remove('user_timetable_path_$_email');
          print('Removing invalid timetable path: $savedPath');
        }
      }

      // Fall back to the standard location if no saved path or file doesn't exist
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/timetable_images';
      
      // Sanitize email for use in filename
      final sanitizedEmail = _email!.replaceAll(RegExp(r'[^\w\s\.]'), '_');
      
      // Try to find any file that matches this user's timetable pattern
      final dir = Directory(path);
      if (await dir.exists()) {
        final files = dir.listSync().whereType<File>().where(
          (file) => file.path.contains('timetable_$sanitizedEmail')
        ).toList();
        
        // Sort by modification time, newest first
        files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        
        if (files.isNotEmpty) {
          setState(() {
            _timetableImage = files.first;
            _hasTimetable = true;
            _isLoading = false;
          });
          
          // Save this path as the current one
          await prefs.setString('user_timetable_path_$_email', files.first.path);
          
          print('Timetable found by searching directory: ${files.first.path}');
          return;
        }
      }
      
      // If we get here, no timetable was found
      setState(() {
        _isLoading = false;
        _hasTimetable = false;
        _timetableImage = null;
      });
      print('No timetable found for user: $_email');
      
    } catch (e) {
      print('Error loading timetable image: $e');
      setState(() {
        _isLoading = false;
        _hasTimetable = false;
        _timetableImage = null;
      });
    }
  }
  
  Future<void> _pickTimetableImage() async {
    try {
      // Ensure we have the current user email
      if (_email == null || _email!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _email = prefs.getString('current_user_email') ?? 
                 prefs.getString('currentUser') ?? 
                 prefs.getString('currentUserEmail');
                 
        if (_email == null || _email!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: User not logged in'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 80  // Compressed for better performance
      );
      
      if (pickedFile != null) {
        // First check if the picked file is valid
        final tempFile = File(pickedFile.path);
        if (!(await tempFile.exists())) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Selected file is invalid'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/timetable_images';
        
        // Create directory if it doesn't exist
        final dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        
        // Sanitize email for use in filename
        final sanitizedEmail = _email!.replaceAll(RegExp(r'[^\w\s\.]'), '_');
        
        // Check and remove any existing timetable files for this user
        final existingFiles = dir.listSync().whereType<File>().where(
          (file) => file.path.contains('timetable_$sanitizedEmail')
        ).toList();
        
        for (var file in existingFiles) {
          try {
            await file.delete();
            print('Deleted old timetable file: ${file.path}');
          } catch (e) {
            print('Error deleting old timetable file: $e');
          }
        }
        
        // Save image with a unique timestamp to avoid caching issues
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniquePath = '$path/timetable_${sanitizedEmail}_$timestamp.jpg';
        await tempFile.copy(uniquePath);
        
        // Save reference in preferences
        final prefs = await SharedPreferences.getInstance();
        // Remove old key if exists
        await prefs.remove('user_timetable_path_$_email');
        // Save new path
        await prefs.setString('user_timetable_path_$_email', uniquePath);
        
        print('Timetable saved to: $uniquePath for user: $_email');
        
        // Now force refresh the UI with the new image
        final newImageFile = File(uniquePath);
        if (await newImageFile.exists()) {
          setState(() {
            _timetableImage = newImageFile;
            _hasTimetable = true;
          });
          
          // Force a rebuild of the image widget by adding a uniqueness identifier
          await Future.delayed(Duration(milliseconds: 500));
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Timetable image saved successfully for $_email'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Failed to save timetable image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking timetable image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading timetable image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTimetableFullScreen() {
    if (_timetableImage == null || !_hasTimetable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No timetable image available to display'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Force landscape orientation for timetable view
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Timetable View'),
            backgroundColor: Colors.blue,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                // Reset to portrait before popping
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                ]);
                Navigator.of(context).pop();
              },
            ),
          ),
          body: Container(
            color: Colors.black,
            child: PhotoView(
              imageProvider: FileImage(_timetableImage!),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              backgroundDecoration: BoxDecoration(
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Class Timetable'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card for uploading or viewing timetable
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 48,
                              color: Colors.blue,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Your Class Timetable',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _hasTimetable 
                                  ? 'Your timetable is ready to view'
                                  : 'Upload your class timetable as an image',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _pickTimetableImage,
                              icon: Icon(Icons.upload_file),
                              label: Text(_hasTimetable ? 'Change Timetable' : 'Upload Timetable'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (_timetableImage != null && _hasTimetable) ...[
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.image, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text(
                                        'Your Timetable',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.fullscreen, color: Colors.blue),
                                    onPressed: _showTimetableFullScreen,
                                    tooltip: 'View fullscreen',
                                  )
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: _showTimetableFullScreen,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                      child: Image.file(
                                        _timetableImage!,
                                        fit: BoxFit.contain,
                                        height: 300,
                                        width: double.infinity,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 10,
                                    bottom: 10,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.touch_app,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Tap to view',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
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
                      ),
                      // Button to change timetable
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: EdgeInsets.only(top: 16),
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _pickTimetableImage,
                            icon: Icon(Icons.edit),
                            label: Text('Change Timetable Image'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
} 