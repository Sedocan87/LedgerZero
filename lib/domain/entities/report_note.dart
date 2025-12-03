import 'package:equatable/equatable.dart';

class ReportNote extends Equatable {
  final String id;
  final String date;
  final String note;
  final String? createdAt;
  final String? updatedAt;

  const ReportNote({
    required this.id,
    required this.date,
    required this.note,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [id, date, note, createdAt, updatedAt];

  ReportNote copyWith({
    String? id,
    String? date,
    String? note,
    String? createdAt,
    String? updatedAt,
  }) {
    return ReportNote(
      id: id ?? this.id,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
