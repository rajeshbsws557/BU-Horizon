import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../repositories/attendance_repository.dart';

/// Builds a clean, teacher-ready attendance CSV from [AttendanceExportData] and
/// lets the CR save it to a location of their choice.
///
/// Two shapes come out of the same builder:
///  * Single class  → one dated status column ("Present"/"Absent").
///  * Full course    → one column per class plus Present/Total/% summary cols.
///
/// The CSV is UTF-8 with a BOM so Excel opens Bangla names and the % sign
/// correctly, and every field is quoted/escaped so commas in names never break
/// the columns.
class AttendanceExportService {
  const AttendanceExportService();

  /// Generates the CSV text for [data].
  String buildCsv(AttendanceExportData data) {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final buffer = StringBuffer();

    // ── Report header (a few titled lines above the table) ────────────────
    buffer.writeln(_row(['Course code', data.courseCode]));
    buffer.writeln(_row(['Course title', data.courseTitle]));
    if (data.teacherName.isNotEmpty) {
      buffer.writeln(_row(['Course teacher', data.teacherName]));
    }
    buffer.writeln(
      _row([
        'Generated',
        DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      ]),
    );
    buffer.writeln(
      _row([
        'Total classes',
        data.sessions.length.toString(),
      ]),
    );
    buffer.writeln(); // blank spacer line

    final single = data.sessions.length == 1;

    // ── Column header row ─────────────────────────────────────────────────
    final header = <String>['#', 'Roll', 'Student ID', 'Name'];
    if (single) {
      final s = data.sessions.first;
      header.add('${dateFmt.format(s.date)} — Status');
    } else {
      for (final s in data.sessions) {
        header.add(dateFmt.format(s.date));
      }
      header
        ..add('Present')
        ..add('Total')
        ..add('Percentage');
    }
    buffer.writeln(_row(header));

    // ── Student rows ──────────────────────────────────────────────────────
    // Sort by roll then name so the sheet matches a printed class list.
    final students = [...data.students]..sort((a, b) {
      final byRoll = _rollKey(a.roll).compareTo(_rollKey(b.roll));
      if (byRoll != 0) return byRoll;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });

    for (var i = 0; i < students.length; i++) {
      final student = students[i];
      final row = <String>[
        '${i + 1}',
        student.roll,
        student.studentId,
        student.fullName,
      ];
      if (single) {
        row.add(_statusLabel(student.marksBySession[data.sessions.first.id]));
      } else {
        for (final s in data.sessions) {
          row.add(_statusLabel(student.marksBySession[s.id]));
        }
        final present = student.presentIn(data.sessions);
        final total = data.sessions.length;
        row
          ..add('$present')
          ..add('$total')
          ..add(total == 0 ? '0%' : '${((present / total) * 100).round()}%');
      }
      buffer.writeln(_row(row));
    }

    return buffer.toString();
  }

  /// A safe file name like `CSE-1101_attendance_2026-07-26.csv`.
  String suggestedFileName(AttendanceExportData data) {
    final safeCode = data.courseCode.isEmpty
        ? 'course'
        : data.courseCode.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final stamp = data.sessions.length == 1 && data.sessions.isNotEmpty
        ? DateFormat('yyyy-MM-dd').format(data.sessions.first.date)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
    final kind = data.sessions.length == 1 ? 'class' : 'attendance';
    return '${safeCode}_${kind}_$stamp.csv';
  }

  /// Writes [data] to a CSV the user picks a location for. Returns the saved
  /// path, or null if the user cancelled.
  Future<String?> exportToFile(AttendanceExportData data) async {
    final csv = buildCsv(data);
    // Prepend a UTF-8 BOM so spreadsheet apps detect the encoding.
    final bytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(csv),
    ]);
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save attendance CSV',
      fileName: suggestedFileName(data),
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: bytes,
    );
  }

  static String _statusLabel(AttendanceMark? mark) => switch (mark) {
    AttendanceMark.present => 'Present',
    AttendanceMark.absent => 'Absent',
    null => '—',
  };

  /// Numeric-aware roll sort: "CSE-2" sorts before "CSE-10".
  static String _rollKey(String roll) {
    return roll.replaceAllMapped(
      RegExp(r'\d+'),
      (m) => m.group(0)!.padLeft(6, '0'),
    );
  }

  /// One CSV line: every field quoted with internal quotes doubled.
  static String _row(List<String> fields) =>
      fields.map(_escape).join(',');

  static String _escape(String field) {
    final needsQuotes =
        field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r');
    final escaped = field.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
