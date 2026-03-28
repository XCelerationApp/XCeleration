import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/race_record.dart';
import '../../race_timer/model/ui_record.dart';
import '../../bib_number_recorder/model/bib_datum_record.dart';
import '../../../core/utils/enums.dart';
import '../../../core/result.dart';
import '../../../core/app_error.dart';

enum DownloadFormat { csv, pdf }

/// Service for generating and sharing CSV/PDF exports of assistant race data.
///
/// All methods return [Result<XFile>] — they never throw outward.
/// Call [shareFile] to invoke the system share sheet after a successful export.
class AssistantExportService {
  AssistantExportService._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  static Future<Result<XFile>> exportTimerData(
    RaceRecord race,
    List<UIRecord> records,
    DownloadFormat format,
  ) async {
    return format == DownloadFormat.csv
        ? _exportTimerCsv(race, records)
        : _exportTimerPdf(race, records);
  }

  static Future<Result<XFile>> exportBibData(
    RaceRecord race,
    List<BibDatumRecord> records,
    DownloadFormat format,
  ) async {
    return format == DownloadFormat.csv
        ? _exportBibCsv(race, records)
        : _exportBibPdf(race, records);
  }

  static Future<void> shareFile(XFile file, String subject) async {
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: subject),
    );
  }

  // ---------------------------------------------------------------------------
  // Timer exports
  // ---------------------------------------------------------------------------

  static Future<Result<XFile>> _exportTimerCsv(
    RaceRecord race,
    List<UIRecord> records,
  ) async {
    try {
      final rows = <List<dynamic>>[
        ['Race', race.name],
        ['Date', _formattedDate(race.date)],
        [],
        ['Place', 'Time'],
        ...records
            .where((r) => r.type == RecordType.runnerTime)
            .map((r) => [r.place?.toString() ?? '', r.time]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      return _writeTempTextFile(csv, race.name, 'csv', 'text/csv');
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not create CSV export.',
        originalException: e,
      ));
    }
  }

  static Future<Result<XFile>> _exportTimerPdf(
    RaceRecord race,
    List<UIRecord> records,
  ) async {
    try {
      final pdf = pw.Document();
      final (regular, bold) = await _loadFonts();
      final theme = pw.ThemeData.withFont(base: regular, bold: bold);

      final rows = records
          .where((r) => r.type == RecordType.runnerTime)
          .map((r) => [r.place?.toString() ?? '', r.time])
          .toList();

      pdf.addPage(pw.MultiPage(
        theme: theme,
        build: (_) => [
          pw.Header(level: 0, text: '${race.name} — ${race.formattedDate}'),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Finish Times'),
          pw.TableHelper.fromTextArray(
            headers: ['Place', 'Time'],
            data: rows,
          ),
        ],
      ));

      return _writeTempBytesFile(
        await pdf.save(),
        race.name,
        'pdf',
        'application/pdf',
      );
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not create PDF export.',
        originalException: e,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Bib recorder exports
  // ---------------------------------------------------------------------------

  static Future<Result<XFile>> _exportBibCsv(
    RaceRecord race,
    List<BibDatumRecord> records,
  ) async {
    try {
      final rows = <List<dynamic>>[
        ['Race', race.name],
        ['Date', _formattedDate(race.date)],
        [],
        ['Place', 'Bib', 'Name', 'Team', 'Grade'],
        ...records.asMap().entries.map((e) => [
              e.key + 1,
              e.value.bib,
              e.value.name ?? '',
              e.value.teamAbbreviation ?? '',
              e.value.grade ?? '',
            ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      return _writeTempTextFile(csv, race.name, 'csv', 'text/csv');
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not create CSV export.',
        originalException: e,
      ));
    }
  }

  static Future<Result<XFile>> _exportBibPdf(
    RaceRecord race,
    List<BibDatumRecord> records,
  ) async {
    try {
      final pdf = pw.Document();
      final (regular, bold) = await _loadFonts();
      final theme = pw.ThemeData.withFont(base: regular, bold: bold);

      final rows = records
          .asMap()
          .entries
          .map((e) => [
                '${e.key + 1}',
                e.value.bib,
                e.value.name ?? '',
                e.value.teamAbbreviation ?? '',
                e.value.grade ?? '',
              ])
          .toList();

      pdf.addPage(pw.MultiPage(
        theme: theme,
        build: (_) => [
          pw.Header(level: 0, text: '${race.name} — ${race.formattedDate}'),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Bib Numbers'),
          pw.TableHelper.fromTextArray(
            headers: ['Place', 'Bib', 'Name', 'Team', 'Grade'],
            data: rows,
          ),
        ],
      ));

      return _writeTempBytesFile(
        await pdf.save(),
        race.name,
        'pdf',
        'application/pdf',
      );
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not create PDF export.',
        originalException: e,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Future<(pw.Font, pw.Font)> _loadFonts() async {
    final regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    return (regular, bold);
  }

  static Future<Result<XFile>> _writeTempTextFile(
    String content,
    String raceName,
    String extension,
    String mimeType,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, '${_safeFileName(raceName)}.$extension');
      await File(path).writeAsString(content, flush: true);
      return Success(XFile(path, mimeType: mimeType));
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not save export file.',
        originalException: e,
      ));
    }
  }

  static Future<Result<XFile>> _writeTempBytesFile(
    List<int> bytes,
    String raceName,
    String extension,
    String mimeType,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, '${_safeFileName(raceName)}.$extension');
      await File(path).writeAsBytes(bytes, flush: true);
      return Success(XFile(path, mimeType: mimeType));
    } catch (e) {
      return Failure(AppError(
        userMessage: 'Could not save export file.',
        originalException: e,
      ));
    }
  }

  static String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  static String _formattedDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';
}
