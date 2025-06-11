# Comprehensive Implementation Guide - QR Attendance & CAT System

## 🎨 UI/UX Standards

### Color Scheme
```dart
// Primary Colors
static const Color primaryBlue = Color(0xFF2196F3);
static const Color primaryBackground = Colors.grey.shade50;

// Status Colors
static const Color draftColor = Colors.orange;
static const Color finalizedColor = Colors.green;
static const Color errorColor = Colors.red;
static const Color pendingColor = Colors.grey;

// Text Colors
static const Color primaryText = Colors.black87;
static const Color secondaryText = Colors.black54;
static const Color lightText = Colors.white;
```

### Loading States
```dart
// Loading Indicator Widget
Widget buildLoadingIndicator() {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(
          color: Color(0xFF2196F3),
          strokeWidth: 2,
        ),
        SizedBox(height: 8),
        Text(
          'Please wait...',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    ),
  );
}

// Shimmer Loading Effect
Widget buildShimmerLoading() {
  return Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: YourContentWidget(),
  );
}
```

### Error Handling UI
```dart
void showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.white),
          SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red,
      duration: Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showSuccessSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.white),
          SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
```

## 📊 Database Schema & Relationships

### Complete Table Structure

#### 1. students
```sql
CREATE TABLE students (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  registration_number VARCHAR(20) UNIQUE NOT NULL,
  course_id UUID REFERENCES courses(id),
  year INTEGER NOT NULL,
  semester INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_students_reg_number ON students(registration_number);
CREATE INDEX idx_students_course ON students(course_id);
```

#### 2. lecturers
```sql
CREATE TABLE lecturers (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  staff_number VARCHAR(20) UNIQUE NOT NULL,
  department VARCHAR(100) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_lecturers_staff ON lecturers(staff_number);
```

#### 3. units
```sql
CREATE TABLE units (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  unit_code VARCHAR(10) UNIQUE NOT NULL,
  unit_name VARCHAR(100) NOT NULL,
  course_id UUID REFERENCES courses(id),
  year INTEGER NOT NULL,
  semester INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_units_code ON units(unit_code);
CREATE INDEX idx_units_course ON units(course_id);
```

#### 4. student_units
```sql
CREATE TABLE student_units (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  student_id UUID REFERENCES students(id),
  unit_id UUID REFERENCES units(id),
  academic_year VARCHAR(9) NOT NULL,
  registration_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(student_id, unit_id, academic_year)
);

-- Indexes
CREATE INDEX idx_student_units_lookup ON student_units(student_id, unit_id);
```

### Row Level Security Policies

```sql
-- Students can only view their own data
CREATE POLICY "Students read own data"
ON students FOR SELECT
USING (auth.uid() = user_id);

-- Lecturers can view assigned units
CREATE POLICY "Lecturers view assigned units"
ON lecturer_assigned_units FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = lecturer_assigned_units.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

-- CAT marks policies
CREATE POLICY "Lecturers manage own unit marks"
ON cat_results FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM lecturer_assigned_units
    WHERE lecturer_assigned_units.unit_id = cat_results.unit_id
    AND lecturer_assigned_units.lecturer_id = cat_results.lecturer_id
  )
);

CREATE POLICY "Students view own marks"
ON cat_results FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM students
    WHERE students.id = cat_results.student_id
    AND students.user_id = auth.uid()
  )
);
```

## 🔄 Data Flow & Services

### Student Data Service
```dart
class StudentService {
  final SupabaseClient _supabase;
  
  Future<List<Map<String, dynamic>>> getEnrolledStudents(String unitId) async {
    try {
      final response = await _supabase
        .from('student_units')
        .select('''
          student:student_id(
            id,
            user:user_id(
              name,
              email
            ),
            registration_number
          )
        ''')
        .eq('unit_id', unitId)
        .order('student(registration_number)', ascending: true);
        
      return response;
    } catch (e) {
      throw 'Error fetching enrolled students: $e';
    }
  }
}
```

### Lecturer Service
```dart
class LecturerService {
  final SupabaseClient _supabase;
  
  Future<List<Map<String, dynamic>>> getAssignedUnits(String lecturerId) async {
    try {
      return await _supabase
        .from('lecturer_assigned_units')
        .select()
        .eq('lecturer_id', lecturerId)
        .order('unit_code');
    } catch (e) {
      throw 'Error fetching assigned units: $e';
    }
  }
}
```

## 📱 UI Components & Widgets

### Custom AppBar
```dart
PreferredSize buildCustomAppBar({
  required String title,
  required List<Widget> actions,
}) {
  return PreferredSize(
    preferredSize: Size.fromHeight(140),
    child: AppBar(
      title: Text(title),
      backgroundColor: Color(0xFF2196F3),
      elevation: 0,
      foregroundColor: Colors.white,
      actions: actions,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(140),
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFF2196F3),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.all(16),
          child: YourContent(),
        ),
      ),
    ),
  );
}
```

### Search Field
```dart
class CustomSearchField extends StatelessWidget {
  final Function(String) onSearch;
  final String hintText;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: onSearch,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search, color: Colors.blue[400]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}
```

## 📄 PDF Generation

### PDF Configuration
```dart
// Standard A4 page setup
final pageFormat = PdfPageFormat.a4;
const rowsPerPage = 35;

// Consistent styling
final headerStyle = pw.TextStyle(
  fontSize: 16,
  fontWeight: pw.FontWeight.bold,
);

final normalStyle = pw.TextStyle(
  fontSize: 10,
);

final smallStyle = pw.TextStyle(
  fontSize: 8,
  color: PdfColors.grey700,
);
```

### Header Template
```dart
pw.Widget buildHeader(pw.MemoryImage logoImage) {
  return pw.Column(
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(
            width: 400,
            child: pw.Image(logoImage),
          ),
        ],
      ),
      pw.SizedBox(height: 20),
      pw.Text(
        'CAT MARKS REPORT',
        style: headerStyle,
      ),
    ],
  );
}
```

## 🔒 Error Handling & Validation

### Data Validation
```dart
class Validator {
  static String? validateCatMark(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mark is required';
    }
    
    final mark = double.tryParse(value);
    if (mark == null) {
      return 'Please enter a valid number';
    }
    
    if (mark < 0 || mark > 30) {
      return 'Mark must be between 0 and 30';
    }
    
    return null;
  }
}
```

### Network Error Handling
```dart
Future<T> handleNetworkCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PostgrestException catch (e) {
    throw 'Database error: ${e.message}';
  } on SocketException {
    throw 'No internet connection';
  } catch (e) {
    throw 'An unexpected error occurred';
  }
}
```

## 🔄 State Management

### Loading State
```dart
class LoadingState<T> {
  final bool isLoading;
  final T? data;
  final String? error;
  
  const LoadingState({
    this.isLoading = false,
    this.data,
    this.error,
  });
  
  LoadingState<T> copyWith({
    bool? isLoading,
    T? data,
    String? error,
  }) {
    return LoadingState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}
```

## 📱 Screen States & Lifecycle

### Page Lifecycle Management
```dart
@override
void initState() {
  super.initState();
  _initializeLecturerData();
  _setupConnectivityListener();
}

@override
void dispose() {
  _connectivitySubscription?.cancel();
  _searchController.dispose();
  super.dispose();
}

Future<void> _initializeLecturerData() async {
  setState(() => _isLoading = true);
  try {
    await _loadLecturerProfile();
    await _loadAssignedUnits();
  } catch (e) {
    _handleError(e);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

## 🔌 Connectivity Handling

```dart
class ConnectivityManager {
  final _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  
  void initialize(BuildContext context) {
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        showNoConnectionBanner(context);
      } else {
        hideNoConnectionBanner(context);
      }
    });
  }
  
  void dispose() {
    _subscription?.cancel();
  }
}
```

## 🎯 Performance Optimization

### Query Optimization
```sql
-- Composite indexes for common queries
CREATE INDEX idx_cat_results_composite 
ON cat_results (unit_id, student_id, cat_number, status);

-- Partial index for draft marks
CREATE INDEX idx_cat_results_draft 
ON cat_results (unit_id) 
WHERE status = 'draft';
```

### Caching Strategy
```dart
class CacheManager {
  final Box<dynamic> _cache;
  
  Future<T> getCachedData<T>(
    String key,
    Future<T> Function() fetchData,
    Duration expiry,
  ) async {
    final cached = _cache.get(key);
    if (cached != null && !_isExpired(cached['timestamp'], expiry)) {
      return cached['data'] as T;
    }
    
    final fresh = await fetchData();
    await _cache.put(key, {
      'data': fresh,
      'timestamp': DateTime.now(),
    });
    return fresh;
  }
}
```

## 📊 Data Models

### CAT Result Model
```dart
class CatResult {
  final String id;
  final String unitId;
  final String studentId;
  final String lecturerId;
  final String catNumber;
  final double marks;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  factory CatResult.fromJson(Map<String, dynamic> json) {
    return CatResult(
      id: json['id'],
      unitId: json['unit_id'],
      studentId: json['student_id'],
      lecturerId: json['lecturer_id'],
      catNumber: json['cat_number'],
      marks: json['marks']?.toDouble() ?? 0.0,
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
```

## 📱 Student CAT View Implementation

### Overview
The student CAT view provides a comprehensive interface for students to view their CAT marks across all units. Key features include:
- Performance statistics with visual indicators
- Unit-wise grouping of results
- Status tracking for each CAT
- Color-coded mark display

### UI Implementation
```dart
// Performance Statistics Widget
Widget _buildPerformanceStats() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Overview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                'Average',
                '${(_stats!['average'] as num).toStringAsFixed(1)}%',
                Icons.analytics,
              ),
              _buildStatCard(
                'Highest',
                '${(_stats!['highest'] as num).toStringAsFixed(1)}%',
                Icons.arrow_upward,
              ),
              _buildStatCard(
                'Lowest',
                '${(_stats!['lowest'] as num).toStringAsFixed(1)}%',
                Icons.arrow_downward,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

### Data Flow
```dart
// CatService Implementation
class CatService {
  final SupabaseCatService _supabaseService = SupabaseCatService();
  
  // Get CAT results for a student in a unit
  Future<List<CatResult>> getStudentResults(String studentId, String unitId) async {
    try {
      final results = await _supabaseService.getStudentCatResults(studentId);
      return results.where((result) => result.unitId == unitId).toList();
    } catch (e) {
      throw 'Failed to get student results: $e';
    }
  }
}
```

### State Management
```dart
// CAT Provider Implementation
class CatProvider extends ChangeNotifier {
  void setSelectedCatType(CatType type) {
    _selectedCatType = type;
    notifyListeners();
    loadResults();
  }

  Future<void> loadResults() async {
    if (_selectedUnitId == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final results = await _catService.getUnitResults(_selectedUnitId!, _lecturerId!);
      _results = results.where((r) => r.catType == _selectedCatType).toList();
      
      // Group results by unit
      _resultsByUnit.clear();
      for (var result in _results) {
        if (!_resultsByUnit.containsKey(result.unitId)) {
          _resultsByUnit[result.unitId] = [];
        }
        _resultsByUnit[result.unitId]!.add(result);
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
```

## 📊 CAT Marks Entry System

### Grid Implementation
```dart
class CatGridWidget extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final CatType selectedCatType;
  final Function(String, double) onMarkSaved;
  final bool isLoading;
  final String searchQuery;

  @override
  State<CatGridWidget> createState() => _CatGridWidgetState();
}

class _CatGridWidgetState extends State<CatGridWidget> {
  final Map<String, TextEditingController> _controllers = {};
  Timer? _debounceTimer;
  Map<String, bool> _hasError = {};
  Map<String, String?> _errorMessages = {};
  Map<String, bool> _isSaving = {};
  
  bool _isValidMark(String value) {
    if (value.isEmpty) return true;
    final mark = double.tryParse(value);
    if (mark == null) return false;
    if (mark < 0 || mark > 15) return false;
    final decimal = mark - mark.floor();
    return decimal == 0 || decimal == 0.5;
  }
}
```

### PDF Report Generation
```dart
Future<void> _printCatMarks() async {
  final pdf = pw.Document();
  
  // Header with university logo
  final ByteData logoData = await rootBundle.load('assets/images/university_logo.png');
  final Uint8List logoBytes = logoData.buffer.asUint8List();
  final logoImage = pw.MemoryImage(logoBytes);

  // Calculate pages
  const int rowsPerPage = 35;
  final int totalPages = (_students.length / rowsPerPage).ceil();

  // Generate pages with tables
  for (var pageNum = 0; pageNum < totalPages; pageNum++) {
    final startIndex = pageNum * rowsPerPage;
    final endIndex = min(startIndex + rowsPerPage, _students.length);

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          children: [
            // Header
            if (pageNum == 0) _buildHeader(logoImage),
            
            // Students Table
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                // Table header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    'No.',
                    'Name',
                    'Registration',
                    'Marks',
                    'Status'
                  ].map((header) => pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text(
                      header,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  )).toList(),
                ),
                // Student rows
                ..._students.sublist(startIndex, endIndex).map((student) {
                  return pw.TableRow(
                    children: [
                      student['name'],
                      student['registration'],
                      student['marks'],
                      student['status'],
                    ].map((cell) => pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(cell ?? '-'),
                    )).toList(),
                  );
                }),
              ],
            ),
            
            // Summary (on last page)
            if (pageNum == totalPages - 1) _buildSummary(),
          ],
        ),
      ),
    );
  }
}
```

## 🔄 Data Synchronization

### Real-time Updates
```dart
void _setupRealtimeSubscription() {
  _subscription = _supabase
    .from('cat_results')
    .stream(['id'])
    .eq('unit_id', _selectedUnitId)
    .listen((List<Map<String, dynamic>> data) {
      if (mounted) {
        _refreshData();
      }
    });
}

@override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}
```

### Offline Support
```dart
class OfflineQueue {
  final Queue<CatMarkUpdate> _queue = Queue();
  final SharedPreferences _prefs;

  Future<void> addToQueue(CatMarkUpdate update) async {
    _queue.add(update);
    await _saveQueue();
  }

  Future<void> processQueue() async {
    while (_queue.isNotEmpty) {
      final update = _queue.first;
      try {
        await _catService.saveMark(
          unitId: update.unitId,
          studentId: update.studentId,
          marks: update.marks,
        );
        _queue.removeFirst();
        await _saveQueue();
      } catch (e) {
        if (!_isConnectivityError(e)) {
          _queue.removeFirst();
          await _saveQueue();
        }
        break;
      }
    }
  }
}
```

## 🎯 Performance Optimizations

### Lazy Loading
```dart
class LazyLoadingController extends ScrollController {
  final Future<void> Function() onLoadMore;
  bool _isLoading = false;

  LazyLoadingController({required this.onLoadMore}) {
    addListener(() {
      if (position.pixels >= position.maxScrollExtent - 200 && !_isLoading) {
        _loadMore();
      }
    });
  }

  Future<void> _loadMore() async {
    _isLoading = true;
    await onLoadMore();
    _isLoading = false;
  }
}
```

### Caching Strategy
```dart
class CatResultsCache {
  final _cache = <String, CacheEntry>{};
  
  Future<List<CatResult>> getCachedResults(String unitId) async {
    final entry = _cache[unitId];
    if (entry != null && !entry.isExpired) {
      return entry.results;
    }
    
    final results = await _catService.getUnitResults(unitId);
    _cache[unitId] = CacheEntry(
      results: results,
      timestamp: DateTime.now(),
    );
    return results;
  }
}

class CacheEntry {
  final List<CatResult> results;
  final DateTime timestamp;
  static const maxAge = Duration(minutes: 5);
  
  bool get isExpired => 
    DateTime.now().difference(timestamp) > maxAge;
}
```

## 📱 Error Handling & Recovery

### Graceful Degradation
```dart
Widget _buildResultsWidget() {
  return FutureBuilder<List<CatResult>>(
    future: _loadResults(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _buildErrorWidget(
          message: 'Unable to load results',
          error: snapshot.error,
          onRetry: () => setState(() {}),
        );
      }
      
      if (!snapshot.hasData) {
        return _buildLoadingWidget();
      }
      
      if (snapshot.data!.isEmpty) {
        return _buildEmptyStateWidget();
      }
      
      return _buildResultsList(snapshot.data!);
    },
  );
}

Widget _buildErrorWidget({
  required String message,
  required Object error,
  required VoidCallback onRetry,
}) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red),
        Text(message),
        if (_isNetworkError(error))
          Text('Please check your connection'),
        ElevatedButton(
          onPressed: onRetry,
          child: Text('Retry'),
        ),
      ],
    ),
  );
}
```

### Automatic Recovery
```dart
class AutoRecoveryManager {
  Timer? _recoveryTimer;
  int _retryCount = 0;
  static const maxRetries = 3;
  
  Future<void> attemptRecovery(
    Future<void> Function() operation,
  ) async {
    if (_retryCount >= maxRetries) {
      _showFatalError();
      return;
    }
    
    try {
      await operation();
      _resetRetryCount();
    } catch (e) {
      _retryCount++;
      _scheduleRetry(operation);
    }
  }
  
  void _scheduleRetry(Future<void> Function() operation) {
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(
      Duration(seconds: pow(2, _retryCount).toInt()),
      () => attemptRecovery(operation),
    );
  }
}
```

## 🔄 Core Unit Assignment & Registration System

### Database Schema & Relationships

```sql
-- Core Tables Structure
CREATE TABLE departments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  department_id UUID REFERENCES departments(id) NOT NULL,
  UNIQUE(name, department_id)
);

CREATE TABLE units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  course_id UUID REFERENCES courses(id),
  year TEXT NOT NULL,
  semester TEXT NOT NULL
);

-- Lecturer Assignment Tables
CREATE TABLE lecturer_assigned_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id UUID REFERENCES lecturers(id) NOT NULL,
  unit_code TEXT REFERENCES units(code) NOT NULL,
  unit_name TEXT NOT NULL,
  department TEXT NOT NULL,
  course_name TEXT NOT NULL,
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  UNIQUE(lecturer_id, unit_code, year, semester)
);

-- Student Registration Tables
CREATE TABLE student_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL,
  unit_id UUID REFERENCES units(id) NOT NULL,
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'registered', 'dropped')),
  UNIQUE(student_id, unit_id, year, semester)
);
```

### Key Relationships & Data Flow

1. **Department -> Course -> Unit Hierarchy**
   - Each department has multiple courses
   - Each course has multiple units
   - Units are linked to specific years and semesters

2. **Lecturer Assignment Process**
   ```sql
   -- Function to get lecturer's assigned units
   CREATE OR REPLACE FUNCTION get_lecturer_units(p_lecturer_id UUID)
   RETURNS TABLE (
     unit_id UUID,
     unit_code TEXT,
     unit_name TEXT,
     department TEXT,
     course_name TEXT,
     year TEXT,
     semester TEXT
   ) AS $$
   BEGIN
     RETURN QUERY
     SELECT 
       u.id,
       u.code,
       u.name,
       d.name,
       c.name,
       lau.year,
       lau.semester
     FROM lecturer_assigned_units lau
     JOIN units u ON u.code = lau.unit_code
     JOIN courses c ON u.course_id = c.id
     JOIN departments d ON c.department_id = d.id
     WHERE lau.lecturer_id = p_lecturer_id
     ORDER BY lau.year, lau.semester, u.code;
   END;
   $$ LANGUAGE plpgsql;
   ```

3. **Student Registration Flow**
   ```sql
   -- Function to get registered students for a unit
   CREATE OR REPLACE FUNCTION get_unit_students(p_unit_id UUID)
   RETURNS TABLE (
     student_id UUID,
     name TEXT,
     registration_number TEXT,
     registration_date TIMESTAMP
   ) AS $$
   BEGIN
     RETURN QUERY
     SELECT 
       s.id,
       u.name,
       s.registration_number,
       su.registration_date
     FROM student_units su
     JOIN students s ON s.id = su.student_id
     JOIN auth.users u ON u.id = s.user_id
     WHERE su.unit_id = p_unit_id
     AND su.status = 'registered'
     ORDER BY u.name;
   END;
   $$ LANGUAGE plpgsql;
   ```

### Implementation Details

1. **Unit Loading Process**
```dart
class UnitService {
  final _supabase = Supabase.instance.client;

  // Get lecturer's assigned units
  Future<List<Map<String, dynamic>>> getAssignedUnits(String lecturerId) async {
    try {
      final response = await _supabase
        .from('lecturer_assigned_units')
        .select()
        .eq('lecturer_id', lecturerId)
        .order('unit_code');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to load assigned units: $e';
    }
  }

  // Get students registered for a unit
  Future<List<Map<String, dynamic>>> getRegisteredStudents(String unitId) async {
    try {
      final response = await _supabase
        .rpc('get_unit_students', 
        params: {
          'p_unit_id': unitId,
        });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to load registered students: $e';
    }
  }
}
```

2. **Registration Verification**
```dart
class RegistrationService {
  final _supabase = Supabase.instance.client;

  // Verify student registration
  Future<bool> verifyRegistration(String studentId, String unitId) async {
    try {
      final result = await _supabase
        .from('student_units')
        .select()
        .eq('student_id', studentId)
        .eq('unit_id', unitId)
        .eq('status', 'registered')
        .single();
      return result != null;
    } catch (e) {
      return false;
    }
  }

  // Get student's registered units
  Future<List<Map<String, dynamic>>> getStudentUnits(String studentId) async {
    try {
      final response = await _supabase
        .from('student_units')
        .select('''
          unit:unit_id(
            id,
            code,
            name,
            course:course_id(
              name,
              department:department_id(name)
            )
          )
        ''')
        .eq('student_id', studentId)
        .eq('status', 'registered');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to load student units: $e';
    }
  }
}
```

### Security & Access Control

1. **Row Level Security (RLS)**
```sql
-- Lecturer unit access
CREATE POLICY "Lecturers can view their assigned units"
ON lecturer_assigned_units FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = lecturer_assigned_units.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

-- Student unit access
CREATE POLICY "Students can view their registered units"
ON student_units FOR SELECT
USING (
  auth.uid() IN (
    SELECT user_id FROM students WHERE id = student_id
  )
);
```

2. **Data Validation**
```dart
class UnitValidator {
  static bool isValidRegistration(Map<String, dynamic> registration) {
    return registration['student_id'] != null &&
           registration['unit_id'] != null &&
           registration['year'] != null &&
           registration['semester'] != null;
  }

  static bool isValidAssignment(Map<String, dynamic> assignment) {
    return assignment['lecturer_id'] != null &&
           assignment['unit_code'] != null &&
           assignment['year'] != null &&
           assignment['semester'] != null;
  }
}
```

### Real-time Synchronization

```dart
class UnitSyncManager {
  StreamSubscription? _unitSubscription;
  StreamSubscription? _registrationSubscription;

  // Setup unit assignment sync
  void setupUnitSync(String lecturerId) {
    _unitSubscription = Supabase.instance.client
      .from('lecturer_assigned_units')
      .stream(['id'])
      .eq('lecturer_id', lecturerId)
      .listen((data) {
        // Handle unit assignment updates
      });
  }

  // Setup registration sync
  void setupRegistrationSync(String unitId) {
    _registrationSubscription = Supabase.instance.client
      .from('student_units')
      .stream(['id'])
      .eq('unit_id', unitId)
      .listen((data) {
        // Handle registration updates
      });
  }

  void dispose() {
    _unitSubscription?.cancel();
    _registrationSubscription?.cancel();
  }
}
```

## 🔍 Key Identifiers & Relationships

### Core Identifiers

1. **Unit Identifiers**
```sql
-- Units Table Structure
CREATE TABLE units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),  -- Primary identifier
  code TEXT NOT NULL UNIQUE,                       -- Business identifier (e.g., 'CS101')
  name TEXT NOT NULL,                              -- Display name
  course_id UUID REFERENCES courses(id),           -- Course relationship
  department_id UUID REFERENCES departments(id),    -- Department relationship
  year TEXT NOT NULL,                              -- Academic year
  semester TEXT NOT NULL                           -- Academic semester
);
```

2. **Student Identifiers**
```sql
-- Students Table Structure
CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),  -- Primary identifier
  user_id UUID REFERENCES auth.users(id),          -- Auth relationship
  registration_number TEXT UNIQUE NOT NULL,        -- Business identifier
  course_id UUID REFERENCES courses(id),           -- Course relationship
  department_id UUID REFERENCES departments(id),    -- Department relationship
  year TEXT NOT NULL,
  semester TEXT NOT NULL
);
```

3. **Lecturer Identifiers**
```sql
-- Lecturers Table Structure
CREATE TABLE lecturers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),  -- Primary identifier
  user_id UUID UNIQUE NOT NULL,                    -- Auth relationship
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,                      -- Business identifier
  department TEXT NOT NULL,
  lecture_number TEXT                              -- Additional identifier
);
```

### Critical Relationships

1. **Unit -> Course -> Department Hierarchy**
```sql
-- Example: Get complete unit information
SELECT 
    u.code as unit_code,
    u.name as unit_name,
    c.name as course_name,
    d.name as department_name
FROM units u
JOIN courses c ON u.course_id = c.id
JOIN departments d ON c.department_id = d.id;
```

2. **Student -> Unit Registration Flow**
```sql
-- Student Registration Table
CREATE TABLE student_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL,
  unit_id UUID REFERENCES units(id) NOT NULL,
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  UNIQUE(student_id, unit_id, year, semester)
);

-- Get registered students for a unit
CREATE OR REPLACE FUNCTION get_unit_students(p_unit_id UUID)
RETURNS TABLE (
  student_id UUID,
  registration_number TEXT,
  name TEXT,
  email TEXT,
  department TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.id,
    s.registration_number,
    u.name,
    u.email,
    d.name
  FROM student_units su
  JOIN students s ON s.id = su.student_id
  JOIN auth.users u ON u.id = s.user_id
  JOIN departments d ON s.department_id = d.id
  WHERE su.unit_id = p_unit_id
  AND su.status = 'registered';
END;
$$ LANGUAGE plpgsql;
```

3. **Lecturer -> Unit Assignment Flow**
```sql
-- Lecturer Assignment Table
CREATE TABLE lecturer_assigned_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id UUID REFERENCES lecturers(id) NOT NULL,
  unit_code TEXT REFERENCES units(code) NOT NULL,
  unit_name TEXT NOT NULL,
  department TEXT NOT NULL,
  course_name TEXT NOT NULL,
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  UNIQUE(lecturer_id, unit_code, year, semester)
);

-- Get lecturer's assigned units
CREATE OR REPLACE FUNCTION get_lecturer_units(p_lecturer_id UUID)
RETURNS TABLE (
  unit_id UUID,
  unit_code TEXT,
  unit_name TEXT,
  department TEXT,
  course_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.code,
    u.name,
    d.name,
    c.name
  FROM lecturer_assigned_units lau
  JOIN units u ON u.code = lau.unit_code
  JOIN courses c ON u.course_id = c.id
  JOIN departments d ON c.department_id = d.id
  WHERE lau.lecturer_id = p_lecturer_id;
END;
$$ LANGUAGE plpgsql;
```

### Common Error Scenarios & Solutions

1. **Unit Code Mismatches**
```dart
// Problem: Unit codes might be in different formats
// Solution: Standardize unit code format
String standardizeUnitCode(String code) {
  // Remove spaces and convert to uppercase
  code = code.replaceAll(' ', '').toUpperCase();
  
  // Ensure proper format (e.g., CS101)
  if (!RegExp(r'^[A-Z]{2,}\d{3}$').hasMatch(code)) {
    throw FormatException('Invalid unit code format');
  }
  
  return code;
}
```

2. **Student Registration Conflicts**
```sql
-- Problem: Duplicate registrations
-- Solution: Use unique constraints and proper error handling
CREATE OR REPLACE FUNCTION register_student_unit(
  p_student_id UUID,
  p_unit_id UUID,
  p_year TEXT,
  p_semester TEXT
) RETURNS TEXT AS $$
BEGIN
  -- Check if already registered
  IF EXISTS (
    SELECT 1 FROM student_units
    WHERE student_id = p_student_id
    AND unit_id = p_unit_id
    AND year = p_year
    AND semester = p_semester
  ) THEN
    RETURN 'Already registered';
  END IF;

  -- Proceed with registration
  INSERT INTO student_units (
    student_id, unit_id, year, semester, status
  ) VALUES (
    p_student_id, p_unit_id, p_year, p_semester, 'registered'
  );
  
  RETURN 'Registration successful';
EXCEPTION
  WHEN unique_violation THEN
    RETURN 'Duplicate registration';
  WHEN OTHERS THEN
    RETURN 'Registration failed: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;
```

3. **Department-Course-Unit Inconsistencies**
```sql
-- Problem: Inconsistent relationships
-- Solution: Add trigger to maintain consistency
CREATE OR REPLACE FUNCTION maintain_unit_relationships()
RETURNS TRIGGER AS $$
BEGIN
  -- Ensure unit's department matches course's department
  IF NEW.course_id IS NOT NULL THEN
    NEW.department_id := (
      SELECT department_id
      FROM courses
      WHERE id = NEW.course_id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER unit_relationship_trigger
  BEFORE INSERT OR UPDATE ON units
  FOR EACH ROW
  EXECUTE FUNCTION maintain_unit_relationships();
```

### Data Validation & Error Prevention

1. **Input Validation**
```dart
class UnitValidator {
  static bool isValidUnitCode(String code) {
    return RegExp(r'^[A-Z]{2,}\d{3}$').hasMatch(code);
  }

  static bool isValidYear(String year) {
    final y = int.tryParse(year);
    return y != null && y >= 1 && y <= 4;
  }

  static bool isValidSemester(String semester) {
    final s = int.tryParse(semester);
    return s != null && s >= 1 && s <= 2;
  }
}
```

2. **Relationship Verification**
```dart
Future<bool> verifyUnitRelationships(String unitCode) async {
  try {
    final result = await _supabase.rpc(
      'verify_unit_relationships',
      params: {'p_unit_code': unitCode}
    );
    return result as bool;
  } catch (e) {
    print('Error verifying unit relationships: $e');
    return false;
  }
}
```

3. **Error Recovery**
```dart
class ErrorRecoveryService {
  // Fix inconsistent unit assignments
  Future<void> fixUnitAssignments() async {
    try {
      await _supabase.rpc('fix_unit_assignments');
    } catch (e) {
      print('Error fixing unit assignments: $e');
    }
  }

  // Fix student registrations
  Future<void> fixStudentRegistrations() async {
    try {
      await _supabase.rpc('fix_student_registrations');
    } catch (e) {
      print('Error fixing student registrations: $e');
    }
  }
}
```

## 📝 CAT Marks System Integration

### Database Schema

```sql
CREATE TABLE cat_results (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  unit_id UUID REFERENCES units(id) NOT NULL,
  student_id UUID REFERENCES students(id) NOT NULL,
  lecturer_id UUID REFERENCES lecturers(id) NOT NULL,
  cat_number INTEGER NOT NULL CHECK (cat_number IN (1, 2)),
  marks DECIMAL(4,1) NOT NULL CHECK (marks >= 0 AND marks <= 30),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'final')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(unit_id, student_id, cat_number)
);

-- Performance indexes
CREATE INDEX idx_cat_results_lookup ON cat_results(unit_id, student_id, cat_number);
CREATE INDEX idx_cat_results_lecturer ON cat_results(lecturer_id);
```

### Access Control

```sql
-- Lecturer access
CREATE POLICY "Lecturers manage their unit marks"
ON cat_results FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM lecturer_assigned_units lau
    WHERE lau.lecturer_id = cat_results.lecturer_id
    AND lau.unit_id = cat_results.unit_id
  )
);

-- Student access
CREATE POLICY "Students view own marks"
ON cat_results FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM students s
    WHERE s.id = cat_results.student_id
    AND s.user_id = auth.uid()
  )
);
```

### Service Layer

```dart
class CatMarksService {
  final SupabaseClient _supabase;
  
  Future<void> saveCatMarks({
    required String unitId,
    required String studentId,
    required int catNumber,
    required double marks,
    required String lecturerId,
  }) async {
    try {
      // Verify registration
      final isRegistered = await _verifyStudentRegistration(
        unitId, 
        studentId
      );
      
      if (!isRegistered) {
        throw 'Student not registered for unit';
      }

      // Save marks
      await _supabase.from('cat_results').upsert({
        'unit_id': unitId,
        'student_id': studentId,
        'lecturer_id': lecturerId,
        'cat_number': catNumber,
        'marks': marks,
        'status': 'draft'
      });
    } catch (e) {
      throw 'Failed to save marks: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getStudentMarks(
    String studentId
  ) async {
    try {
      return await _supabase
        .from('cat_results')
        .select('''
          *,
          unit:unit_id(
            code, 
            name,
            course:course_id(name)
          )
        ''')
        .eq('student_id', studentId)
        .order('created_at');
    } catch (e) {
      throw 'Failed to fetch marks: $e';
    }
  }
}
```

### Error Handling

```dart
class CatMarksErrorHandler {
  String handleError(dynamic error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case '23505': 
          return 'Marks already exist';
        case '23514':
          return 'Invalid marks value';
        default:
          return 'Database error: ${error.message}';
      }
    }
    return 'Unexpected error occurred';
  }
}
```

### PDF Generation

```dart
class CatReportGenerator {
  Future<Uint8List> generateReport({
    required String unitId,
    required List<CatResult> results,
    required UnitInfo unitInfo,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        header: (context) => _buildHeader(unitInfo),
        build: (context) => [
          _buildSummaryStats(results),
          _buildMarksTable(results),
        ],
      ),
    );

    return pdf.save();
  }
}
```

## 🔗 CAT Marks Relationships & Validation

### Prerequisites & Dependencies

1. **Unit Assignment Validation**
```sql
-- Function to validate unit assignments
CREATE OR REPLACE FUNCTION validate_cat_prerequisites()
RETURNS TRIGGER AS $$
BEGIN
  -- Verify student registration
  IF NOT EXISTS (
    SELECT 1 FROM student_units
    WHERE student_id = NEW.student_id
    AND unit_id = NEW.unit_id
    AND status = 'registered'
  ) THEN
    RAISE EXCEPTION 'Student is not registered for this unit';
  END IF;

  -- Verify lecturer assignment
  IF NOT EXISTS (
    SELECT 1 FROM lecturer_assigned_units
    WHERE lecturer_id = NEW.lecturer_id
    AND unit_id = NEW.unit_id
  ) THEN
    RAISE EXCEPTION 'Lecturer is not assigned to this unit';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce prerequisites
CREATE TRIGGER enforce_cat_prerequisites
  BEFORE INSERT OR UPDATE ON cat_results
  FOR EACH ROW
  EXECUTE FUNCTION validate_cat_prerequisites();
```

2. **Relationship Constraints**
```sql
-- Foreign key constraints
ALTER TABLE cat_results
ADD CONSTRAINT fk_cat_student_unit
FOREIGN KEY (student_id, unit_id)
REFERENCES student_units(student_id, unit_id);

ALTER TABLE cat_results
ADD CONSTRAINT fk_cat_lecturer_unit
FOREIGN KEY (lecturer_id, unit_id)
REFERENCES lecturer_assigned_units(lecturer_id, unit_id);

-- Status transition constraints
CREATE OR REPLACE FUNCTION validate_status_transition()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status = 'final' AND NEW.status = 'draft' THEN
    RAISE EXCEPTION 'Cannot change status from final to draft';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_status_transition
  BEFORE UPDATE ON cat_results
  FOR EACH ROW
  EXECUTE FUNCTION validate_status_transition();
```

3. **Data Validation Service**
```dart
class CatValidationService {
  final SupabaseClient _supabase;

  // Verify all prerequisites
  Future<void> validatePrerequisites({
    required String unitId,
    required String studentId,
    required String lecturerId,
  }) async {
    final results = await Future.wait([
      _verifyStudentRegistration(unitId, studentId),
      _verifyLecturerAssignment(unitId, lecturerId),
    ]);

    if (!results[0]) {
      throw 'Student is not registered for this unit';
    }
    if (!results[1]) {
      throw 'Lecturer is not assigned to this unit';
    }
  }

  // Verify student registration
  Future<bool> _verifyStudentRegistration(
    String unitId,
    String studentId,
  ) async {
    final result = await _supabase
      .from('student_units')
      .select()
      .match({
        'unit_id': unitId,
        'student_id': studentId,
        'status': 'registered'
      })
      .maybeSingle();
    return result != null;
  }

  // Verify lecturer assignment
  Future<bool> _verifyLecturerAssignment(
    String unitId,
    String lecturerId,
  ) async {
    final result = await _supabase
      .from('lecturer_assigned_units')
      .select()
      .match({
        'unit_id': unitId,
        'lecturer_id': lecturerId
      })
      .maybeSingle();
    return result != null;
  }

  // Validate marks value
  bool validateMarks(double marks) {
    return marks >= 0 && marks <= 30;
  }
}
```

4. **Error Recovery**
```dart
class CatErrorRecovery {
  final SupabaseClient _supabase;

  // Find and fix inconsistencies
  Future<void> fixInconsistencies(String unitId) async {
    try {
      // Find orphaned CAT records
      final orphanedRecords = await _findOrphanedRecords(unitId);
      
      // Remove invalid records
      if (orphanedRecords.isNotEmpty) {
        await _supabase
          .from('cat_results')
          .delete()
          .in_('id', orphanedRecords.map((r) => r['id']));
      }

      // Find and update incorrect statuses
      await _fixIncorrectStatuses(unitId);
    } catch (e) {
      print('Error recovery failed: $e');
    }
  }

  // Find orphaned records
  Future<List<Map<String, dynamic>>> _findOrphanedRecords(
    String unitId,
  ) async {
    return await _supabase
      .from('cat_results')
      .select('id')
      .eq('unit_id', unitId)
      .not('student_id', 'in', (
        _supabase
          .from('student_units')
          .select('student_id')
          .eq('unit_id', unitId)
      ));
  }

  // Fix incorrect statuses
  Future<void> _fixIncorrectStatuses(String unitId) async {
    await _supabase.rpc(
      'fix_cat_result_statuses',
      params: {'p_unit_id': unitId}
    );
  }
}
```

## 🔌 Crucial Supabase Service Patterns

### 1. Core Tables & Relationships
```sql
-- Essential tables for the system
CREATE TABLE lecturer_assigned_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id UUID REFERENCES lecturers(id),
  unit_id UUID REFERENCES units(id),
  unit_code TEXT NOT NULL,
  unit_name TEXT NOT NULL,
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  UNIQUE(lecturer_id, unit_code, year, semester)
);

CREATE TABLE student_registered_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES students(id),
  unit_id UUID REFERENCES units(id),
  unit_code TEXT NOT NULL,
  status TEXT DEFAULT 'registered',
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(student_id, unit_id, year, semester)
);

-- Indexes for quick lookups
CREATE INDEX idx_lecturer_units ON lecturer_assigned_units(lecturer_id, unit_id);
CREATE INDEX idx_student_units ON student_registered_units(student_id, unit_id);
```

### 2. Reusable Supabase Queries

```dart
class CoreQueries {
  final SupabaseClient _supabase;

  // Get lecturer's assigned units with full details
  Future<List<Map<String, dynamic>>> getLecturerUnits(String lecturerId) async {
    try {
      return await _supabase
        .from('lecturer_assigned_units')
        .select('''
          *,
          unit:units!inner(
            id,
            code,
            name,
            course:courses!inner(
              name,
              department:departments!inner(name)
            )
          )
        ''')
        .eq('lecturer_id', lecturerId)
        .order('unit_code');
    } catch (e) {
      throw 'Failed to fetch lecturer units: $e';
    }
  }

  // Get students registered in a unit
  Future<List<Map<String, dynamic>>> getUnitStudents(String unitId) async {
    try {
      return await _supabase
        .from('student_registered_units')
        .select('''
          *,
          student:students!inner(
            id,
            registration_number,
            user:auth.users!inner(
              email,
              name
            )
          )
        ''')
        .eq('unit_id', unitId)
        .eq('status', 'registered')
        .order('student(registration_number)');
    } catch (e) {
      throw 'Failed to fetch unit students: $e';
    }
  }

  // Get student's registered units
  Future<List<Map<String, dynamic>>> getStudentUnits(String studentId) async {
    try {
      return await _supabase
        .from('student_registered_units')
        .select('''
          *,
          unit:units!inner(
            id,
            code,
            name,
            lecturer:lecturer_assigned_units!inner(
              lecturer:lecturers!inner(
                name,
                email
              )
            )
          )
        ''')
        .eq('student_id', studentId)
        .eq('status', 'registered')
        .order('unit_code');
    } catch (e) {
      throw 'Failed to fetch student units: $e';
    }
  }
}
```

### 3. Reusable Service Mixins

```dart
// Mixin for lecturer-related queries
mixin LecturerQueryMixin {
  SupabaseClient get supabase;

  Future<bool> verifyLecturerUnit(String lecturerId, String unitId) async {
    final result = await supabase
      .from('lecturer_assigned_units')
      .select()
      .match({
        'lecturer_id': lecturerId,
        'unit_id': unitId
      })
      .maybeSingle();
    return result != null;
  }

  Future<Map<String, dynamic>?> getLecturerProfile(String userId) async {
    return await supabase
      .from('lecturers')
      .select('''
        *,
        user:auth.users!inner(
          email,
          name
        )
      ''')
      .eq('user_id', userId)
      .single();
  }
}

// Mixin for student-related queries
mixin StudentQueryMixin {
  SupabaseClient get supabase;

  Future<bool> verifyStudentRegistration(String studentId, String unitId) async {
    final result = await supabase
      .from('student_registered_units')
      .select()
      .match({
        'student_id': studentId,
        'unit_id': unitId,
        'status': 'registered'
      })
      .maybeSingle();
    return result != null;
  }

  Future<Map<String, dynamic>?> getStudentProfile(String userId) async {
    return await supabase
      .from('students')
      .select('''
        *,
        user:auth.users!inner(
          email,
          name
        ),
        course:courses!inner(
          name,
          department:departments!inner(name)
        )
      ''')
      .eq('user_id', userId)
      .single();
  }
}
```

### 4. Service Usage Example

```dart
class FeatureService with LecturerQueryMixin, StudentQueryMixin {
  @override
  final SupabaseClient supabase;
  
  Future<void> someFeatureOperation(
    String lecturerId,
    String unitId,
    String studentId
  ) async {
    // Verify relationships
    final isLecturerAssigned = await verifyLecturerUnit(lecturerId, unitId);
    if (!isLecturerAssigned) {
      throw 'Lecturer not assigned to this unit';
    }

    final isStudentRegistered = await verifyStudentRegistration(studentId, unitId);
    if (!isStudentRegistered) {
      throw 'Student not registered for this unit';
    }

    // Proceed with operation...
  }
}
```

## 🎨 Standard Page Layout & Styling

### 1. Page Layout Template
```dart
class StandardPage extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(140),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 2),
                blurRadius: 4,
              )
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.lightText,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  actions: actions,
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  child: SearchField(
                    onSearch: (query) {
                      // Handle search
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: AppColors.background,
        child: body,
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
```

### 2. Content Card Template
```dart
class ContentCard extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
```

### 3. Usage Example
```dart
class FeaturePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StandardPage(
      title: 'Feature Name',
      actions: [
        IconButton(
          icon: Icon(Icons.refresh),
          onPressed: () {
            // Refresh data
          },
        ),
      ],
      body: ListView(
        children: [
          ContentCard(
            title: 'Section Title',
            actions: [
              TextButton(
                child: Text('View All'),
                onPressed: () {
                  // Handle action
                },
              ),
            ],
            child: YourContent(),
          ),
          // More cards...
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add),
        onPressed: () {
          // Handle action
        },
      ),
    );
  }
}
```

This section provides:
- Essential Supabase queries for core functionality
- Standard page layout with blue header
- Critical database tables and relationships
- Consistent styling and colors
- Quick implementation example

When implementing new features:
1. Use CoreDataService for data access
2. Follow the StandardPage layout
3. Use AppStyle for consistent colors
4. Reference critical tables for relationships

This guide serves as a comprehensive reference for:
- UI/UX standards and components
- Database schema and relationships
- Data flow and service patterns
- Error handling and validation
- State management
- Performance optimization
- Connectivity handling
- PDF generation
- Screen lifecycle management

Use this as a template for implementing similar features while maintaining consistency across the application. 

## 📦 Additional Reusable Components & Patterns

### 1. Common Supabase Queries
```dart
class AdvancedQueries {
  final SupabaseClient _supabase;

  // Get unit attendance statistics
  Future<Map<String, dynamic>> getUnitAttendanceStats(String unitId) async {
    return await _supabase
      .rpc('calculate_unit_attendance_stats', 
      params: {'unit_id': unitId});
  }

  // Get student performance across units
  Future<List<Map<String, dynamic>>> getStudentPerformance(String studentId) async {
    return await _supabase
      .from('cat_results')
      .select('''
        marks,
        cat_number,
        unit:units!inner(
          code,
          name,
          lecturer:lecturer_assigned_units!inner(
            lecturer:lecturers!inner(name)
          )
        )
      ''')
      .eq('student_id', studentId)
      .order('unit(code)');
  }

  // Get lecturer's unit statistics
  Future<List<Map<String, dynamic>>> getLecturerUnitStats(String lecturerId) async {
    return await _supabase
      .rpc('get_lecturer_unit_statistics',
      params: {'p_lecturer_id': lecturerId});
  }
}
```

### 2. Reusable UI Components

```dart
// 1. Statistics Card
class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              SizedBox(width: 8),
              Text(title, style: TextStyle(color: color)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// 2. Action Button
class ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppStyle.headerBlue,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: isLoading ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(icon, size: 18),
          SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

// 3. Empty State Widget
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (onActionPressed != null) ...[
            SizedBox(height: 16),
            ActionButton(
              label: actionLabel!,
              icon: Icons.refresh,
              onPressed: onActionPressed!,
            ),
          ],
        ],
      ),
    );
  }
}
```

### 3. Implementation Examples

#### Example 1: Unit Statistics Page
```dart
class UnitStatisticsPage extends StatelessWidget {
  final String unitId;
  final AdvancedQueries _queries = AdvancedQueries();

  @override
  Widget build(BuildContext context) {
    return StandardPage(
      title: 'Unit Statistics',
      body: FutureBuilder<Map<String, dynamic>>(
        future: _queries.getUnitAttendanceStats(unitId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data!;
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatsCard(
                      title: 'Attendance Rate',
                      value: '${stats['attendance_rate']}%',
                      icon: Icons.people,
                      color: AppStyle.headerBlue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: StatsCard(
                      title: 'Average CAT Score',
                      value: stats['average_score'].toStringAsFixed(1),
                      icon: Icons.score,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              ContentCard(
                title: 'Performance Trend',
                child: PerformanceChart(data: stats['trend_data']),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

#### Example 2: Student List with Search
```dart
class StudentListPage extends StatefulWidget {
  @override
  _StudentListPageState createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  final CoreDataService _dataService = CoreDataService();
  String _searchQuery = '';
  List<Map<String, dynamic>>? _students;

  @override
  Widget build(BuildContext context) {
    return StandardPage(
      title: 'Students',
      searchHint: 'Search by name or registration number',
      onSearch: (query) {
        setState(() => _searchQuery = query);
      },
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dataService.getUnitStudents(widget.unitId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          _students = snapshot.data!;
          final filteredStudents = _filterStudents(_students!, _searchQuery);

          if (filteredStudents.isEmpty) {
            return EmptyStateWidget(
              message: 'No students found',
              icon: Icons.people_outline,
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: filteredStudents.length,
            itemBuilder: (context, index) {
              final student = filteredStudents[index];
              return Container(
                decoration: AppStyle.cardDecoration,
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(student['student']['user']['name'][0]),
                    backgroundColor: AppStyle.headerBlue,
                    foregroundColor: Colors.white,
                  ),
                  title: Text(student['student']['user']['name']),
                  subtitle: Text(student['student']['registration_number']),
                  trailing: ActionButton(
                    label: 'View Details',
                    icon: Icons.arrow_forward,
                    onPressed: () {
                      // Navigate to student details
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filterStudents(
    List<Map<String, dynamic>> students,
    String query,
  ) {
    if (query.isEmpty) return students;
    
    return students.where((student) {
      final name = student['student']['user']['name'].toLowerCase();
      final regNo = student['student']['registration_number'].toLowerCase();
      final searchLower = query.toLowerCase();
      
      return name.contains(searchLower) || regNo.contains(searchLower);
    }).toList();
  }
}
```

### 4. Common Error Handling

```dart
class ErrorHandler {
  static Widget buildErrorWidget({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[400],
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ActionButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }

  static String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case '23505':
          return 'This record already exists';
        case '23503':
          return 'Referenced record does not exist';
        default:
          return 'Database error: ${error.message}';
      }
    }

    if (error is SocketException) {
      return 'Network error. Please check your connection';
    }

    return 'An unexpected error occurred';
  }
}
```

This completes our implementation guide with:
- Advanced Supabase query patterns
- Additional reusable UI components
- Complete implementation examples
- Common error handling patterns

Use these patterns and components to maintain consistency and speed up development across the application. 

## 🧪 Testing Patterns

### 1. Unit Tests
```dart
class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('CoreDataService Tests', () {
    late CoreDataService service;
    late MockSupabaseClient mockClient;

    setUp(() {
      mockClient = MockSupabaseClient();
      service = CoreDataService(supabase: mockClient);
    });

    test('getLecturerUnits returns formatted data', () async {
      // Arrange
      final mockResponse = [
        {
          'unit_code': 'CS101',
          'unit_name': 'Introduction to Computing',
          'year': '2024',
          'semester': '1'
        }
      ];

      when(() => mockClient.from('lecturer_assigned_units'))
          .thenReturn(mockResponse);

      // Act
      final result = await service.getLecturerUnits('lecturer_id');

      // Assert
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.first['unit_code'], equals('CS101'));
    });

    test('saveCatMarks validates input', () async {
      // Arrange
      final invalidData = {
        'marks': 35, // Invalid: > 30
      };

      // Act & Assert
      expect(
        () => service.saveCatMarks(invalidData),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
```

### 2. Widget Tests
```dart
void main() {
  group('StandardPage Widget Tests', () {
    testWidgets('renders all components correctly', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: StandardPage(
            title: 'Test Page',
            body: Text('Test Content'),
          ),
        ),
      );

      // Assert
      expect(find.text('Test Page'), findsOneWidget);
      expect(find.byType(SearchField), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('search functionality works', (tester) async {
      String? searchQuery;
      
      await tester.pumpWidget(
        MaterialApp(
          home: StandardPage(
            title: 'Test',
            onSearch: (query) => searchQuery = query,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'test query'
      );

      expect(searchQuery, equals('test query'));
    });
  });
}
```

## 📱 Navigation & State Management

### 1. Route Management
```dart
class AppRouter {
  static const String home = '/';
  static const String units = '/units';
  static const String catMarks = '/units/:unitId/cat';
  static const String attendance = '/units/:unitId/attendance';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => HomePage(),
        );
      
      case units:
        return MaterialPageRoute(
          builder: (_) => UnitsPage(),
        );
      
      case catMarks:
        final unitId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => CatMarksPage(unitId: unitId),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => NotFoundPage(),
        );
    }
  }

  static void navigateToUnit(BuildContext context, String unitId) {
    Navigator.pushNamed(
      context,
      catMarks.replaceAll(':unitId', unitId),
    );
  }
}
```

### 2. State Management Pattern
```dart
class UnitState extends ChangeNotifier {
  final CoreDataService _dataService;
  List<Map<String, dynamic>>? _units;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get units => _units ?? [];
  String? get error => _error;

  Future<void> loadUnits(String lecturerId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _units = await _dataService.getLecturerUnits(lecturerId);
      
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshData(String lecturerId) async {
    _units = null;
    notifyListeners();
    await loadUnits(lecturerId);
  }
}
```

## 🔄 Background Tasks & Sync

### 1. Data Synchronization
```dart
class SyncManager {
  final CoreDataService _dataService;
  Timer? _syncTimer;

  void startPeriodicSync(String lecturerId) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: 5),
      (_) => _syncData(lecturerId),
    );
  }

  Future<void> _syncData(String lecturerId) async {
    try {
      // Sync attendance data
      await _dataService.syncAttendance(lecturerId);
      
      // Sync CAT marks
      await _dataService.syncCatMarks(lecturerId);
      
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}
```

### 2. Background Processing
```dart
class BackgroundTaskManager {
  static const taskChannel = MethodChannel('app/background_tasks');

  static Future<void> scheduleAttendanceSync() async {
    try {
      await taskChannel.invokeMethod('scheduleSync', {
        'task': 'attendance_sync',
        'interval': 15, // minutes
      });
    } catch (e) {
      print('Failed to schedule sync: $e');
    }
  }

  static Future<void> processOfflineData() async {
    final offlineStore = await SharedPreferences.getInstance();
    final pendingData = offlineStore.getString('pending_data');
    
    if (pendingData != null) {
      try {
        final data = json.decode(pendingData);
        await CoreDataService().processPendingData(data);
        await offlineStore.remove('pending_data');
      } catch (e) {
        print('Failed to process offline data: $e');
      }
    }
  }
}
```

## 📊 Performance Monitoring

### 1. Query Performance
```dart
class QueryMonitor {
  static final _queryTimes = <String, List<Duration>>{};

  static Future<T> trackQuery<T>(
    String queryName,
    Future<T> Function() query,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await query();
    } finally {
      stopwatch.stop();
      _recordQueryTime(queryName, stopwatch.elapsed);
    }
  }

  static void _recordQueryTime(String queryName, Duration time) {
    _queryTimes.putIfAbsent(queryName, () => []).add(time);
    
    final avgTime = _queryTimes[queryName]!
      .reduce((a, b) => a + b) ~/ _queryTimes[queryName]!.length;
      
    if (avgTime.inMilliseconds > 500) {
      print('Warning: Slow query detected - $queryName');
    }
  }
}
```

### 2. UI Performance
```dart
class PerformanceOverlay extends StatelessWidget {
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (kDebugMode)
          Positioned(
            top: 0,
            right: 0,
            child: _buildMetrics(),
          ),
      ],
    );
  }

  Widget _buildMetrics() {
    return StreamBuilder<FrameTiming>(
      stream: WidgetsBinding.instance.onFrameTimingUpdate,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox();
        
        final timing = snapshot.data!;
        final fps = 1000 ~/ timing.totalSpan.inMilliseconds;
        
        return Container(
          padding: EdgeInsets.all(8),
          color: Colors.black54,
          child: Text(
            '$fps FPS',
            style: TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }
}
```

This completes our implementation guide with:
- Comprehensive testing patterns
- Navigation and state management
- Background processing and sync
- Performance monitoring

The guide now provides a complete reference for building and maintaining all aspects of the application. Use these patterns and components to ensure consistency, reliability, and performance across all features. 