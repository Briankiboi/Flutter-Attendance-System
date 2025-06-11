import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum CatType { CAT1, CAT2 }

class CatResult {
  final String id;
  final String unitId;
  final String studentId;
  final String lecturerId;
  final CatType catType;
  final double marks;
  final String status;
  final String? comments;
  final String? batchId;
  final String? importSource;
  final DateTime createdAt;
  final DateTime updatedAt;

  CatResult({
    String? id,
    required this.unitId,
    required this.studentId,
    required this.lecturerId,
    required this.catType,
    required this.marks,
    this.status = 'draft',
    this.comments,
    this.batchId,
    this.importSource,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'unit_id': unitId,
    'student_id': studentId,
    'lecturer_id': lecturerId,
    'cat_number': catType == CatType.CAT1 ? 'CAT1' : 'CAT2',
    'marks': marks,
    'status': status,
    'comments': comments,
    'batch_id': batchId,
    'import_source': importSource,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory CatResult.fromJson(Map<String, dynamic> json) => CatResult(
    id: json['id'],
    unitId: json['unit_id'],
    studentId: json['student_id'],
    lecturerId: json['lecturer_id'],
    catType: json['cat_number'] == 'CAT1' ? CatType.CAT1 : CatType.CAT2,
    marks: json['marks'].toDouble(),
    status: json['status'],
    comments: json['comments'],
    batchId: json['batch_id'],
    importSource: json['import_source'],
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );

  CatResult copyWith({
    String? id,
    String? unitId,
    String? studentId,
    String? lecturerId,
    CatType? catType,
    double? marks,
    String? status,
    String? comments,
    String? batchId,
    String? importSource,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CatResult(
    id: id ?? this.id,
    unitId: unitId ?? this.unitId,
    studentId: studentId ?? this.studentId,
    lecturerId: lecturerId ?? this.lecturerId,
    catType: catType ?? this.catType,
    marks: marks ?? this.marks,
    status: status ?? this.status,
    comments: comments ?? this.comments,
    batchId: batchId ?? this.batchId,
    importSource: importSource ?? this.importSource,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  String toString() => 'CatResult(id: $id, unitId: $unitId, studentId: $studentId, '
      'catType: $catType, marks: $marks, status: $status)';
} 