import 'package:uuid/uuid.dart';

class ExcelImport {
  final String id;
  final String lecturerId;
  final String unitId;
  final String filePath;
  final String status;
  final int processedCount;
  final int totalCount;
  final Map<String, dynamic>? errorLog;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExcelImport({
    String? id,
    required this.lecturerId,
    required this.unitId,
    required this.filePath,
    this.status = 'pending',
    this.processedCount = 0,
    this.totalCount = 0,
    this.errorLog,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'lecturer_id': lecturerId,
    'unit_id': unitId,
    'file_path': filePath,
    'status': status,
    'processed_count': processedCount,
    'total_count': totalCount,
    'error_log': errorLog,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory ExcelImport.fromJson(Map<String, dynamic> json) => ExcelImport(
    id: json['id'],
    lecturerId: json['lecturer_id'],
    unitId: json['unit_id'],
    filePath: json['file_path'],
    status: json['status'],
    processedCount: json['processed_count'] ?? 0,
    totalCount: json['total_count'] ?? 0,
    errorLog: json['error_log'],
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );

  ExcelImport copyWith({
    String? id,
    String? lecturerId,
    String? unitId,
    String? filePath,
    String? status,
    int? processedCount,
    int? totalCount,
    Map<String, dynamic>? errorLog,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ExcelImport(
    id: id ?? this.id,
    lecturerId: lecturerId ?? this.lecturerId,
    unitId: unitId ?? this.unitId,
    filePath: filePath ?? this.filePath,
    status: status ?? this.status,
    processedCount: processedCount ?? this.processedCount,
    totalCount: totalCount ?? this.totalCount,
    errorLog: errorLog ?? this.errorLog,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  String toString() => 'ExcelImport(id: $id, lecturerId: $lecturerId, '
      'unitId: $unitId, status: $status, processed: $processedCount/$totalCount)';
} 