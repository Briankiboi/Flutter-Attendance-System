import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/cat_result.dart';
import '../../services/supabase_cat_service.dart';

class CatResultsScreen extends StatefulWidget {
  const CatResultsScreen({super.key});

  @override
  State<CatResultsScreen> createState() => _CatResultsScreenState();
}

class _CatResultsScreenState extends State<CatResultsScreen> {
  final SupabaseCatService _supabaseService = SupabaseCatService();
  final _supabase = Supabase.instance.client;
  
  String? _studentId;
  List<CatResult> _results = [];
  Map<String, dynamic>? _stats;
  bool _isLoadingResults = false;
  bool _isLoadingStats = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeStudentData();
  }

  Future<void> _initializeStudentData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _error = 'User not authenticated');
        return;
      }

      final student = await _supabase
          .from('students')
          .select()
          .eq('user_id', user.id)
          .single();
      
      if (mounted) {
        setState(() {
          _studentId = student['id'];
          _isLoadingResults = true;
          _isLoadingStats = true;
        });
      }
      
      // Load results and stats in parallel
      await Future.wait([
        _loadResults(),
        _loadStats(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to load student data: $e');
      }
    }
  }

  Future<void> _loadResults() async {
    if (_studentId == null) return;
    
    try {
      final results = await _supabaseService.getStudentCatResults(_studentId!);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoadingResults = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load CAT results: $e';
          _isLoadingResults = false;
        });
      }
    }
  }

  Future<void> _loadStats() async {
    if (_studentId == null) return;
    
    try {
      final stats = await _supabaseService.getStudentPerformanceStats(_studentId!);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load performance stats: $e';
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAT Results'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isLoadingResults = true;
                        _isLoadingStats = true;
                      });
                      _initializeStudentData();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _isLoadingResults = true;
                  _isLoadingStats = true;
                });
                await Future.wait([
                  _loadResults(),
                  _loadStats(),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isLoadingStats
                          ? _buildLoadingStats()
                          : _stats != null
                              ? _buildPerformanceStats()
                              : const SizedBox.shrink(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text(
                            'CAT Results by Unit',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (_isLoadingResults) ...[
                            const SizedBox(width: 12),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildResultsList(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingStats() {
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
              children: const [
                _LoadingStatCard(),
                _LoadingStatCard(),
                _LoadingStatCard(),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    if (_results.isEmpty && !_isLoadingResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assessment_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No CAT results available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Group results by unit
    final resultsByUnit = <String, List<CatResult>>{};
    for (var result in _results) {
      if (!resultsByUnit.containsKey(result.unitId)) {
        resultsByUnit[result.unitId] = [];
      }
      resultsByUnit[result.unitId]!.add(result);
    }

    return Column(
      children: resultsByUnit.entries.map((entry) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _supabase
              .from('units')
              .select()
              .eq('id', entry.key)
              .single(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingUnitCard();
            }
            
            final unitName = snapshot.data?['name'] ?? 'Unknown Unit';
            final unitCode = snapshot.data?['code'] ?? '';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(unitName),
                subtitle: Text(unitCode),
                children: entry.value.map((result) {
                  return ListTile(
                    title: Text(
                      result.catType.toString().split('.').last,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Status: ${result.status}'),
                    trailing: Text(
                      '${result.marks.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _getMarkColor(result.marks),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Color _getMarkColor(double marks) {
    if (marks >= 70) return Colors.green;
    if (marks >= 50) return Colors.orange;
    return Colors.red;
  }
}

class _LoadingStatCard extends StatelessWidget {
  const _LoadingStatCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _LoadingUnitCard extends StatelessWidget {
  const _LoadingUnitCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 200,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 