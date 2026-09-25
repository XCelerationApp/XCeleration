import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/utils/file_processing.dart';
import 'package:xceleration/core/utils/file_utils.dart';

// Spreadsheets come from Google Sheets, Excel and hand-edited CSV files,
// each with its own habits. Every one must read back as what it shows.

void main() {
  group('parseCsvText', () {
    test('keeps every cell as written, so bib 007 stays 007', () {
      final rows = FileUtils.parseCsvText('Bib,Name,Grade\n007,Ann Lee,10\n');
      expect(rows[1], ['007', 'Ann Lee', '10']);
    });

    test('drops the mark Excel puts before the first heading', () {
      final rows = FileUtils.parseCsvText('﻿Name,Grade,Bib\nAnn Lee,10,101');
      expect(rows.first.first, 'Name');
      expect(processSpreadsheetData(rows).runners, hasLength(1));
    });

    test('reads Windows line endings, as Google Sheets exports', () {
      final rows =
          FileUtils.parseCsvText('Name,Grade,Bib\r\nAnn Lee,10,101\r\nBo Park,11,102\r\n');
      expect(rows, [
        ['Name', 'Grade', 'Bib'],
        ['Ann Lee', '10', '101'],
        ['Bo Park', '11', '102'],
      ]);
    });

    test('reads names with commas and quotes inside quotes', () {
      final rows = FileUtils.parseCsvText(
          'Name,Grade,Bib\n"Lee, Ann",10,101\n"Bo ""BJ"" Park",11,102\n');
      expect(rows[1][0], 'Lee, Ann');
      expect(rows[2][0], 'Bo "BJ" Park');
    });

    test('recognises semicolon- and tab-separated files', () {
      expect(FileUtils.parseCsvText('Name;Grade;Bib\nAnn Lee;10;101')[1],
          ['Ann Lee', '10', '101']);
      expect(FileUtils.parseCsvText('Name\tGrade\tBib\nAnn Lee\t10\t101')[1],
          ['Ann Lee', '10', '101']);
    });

    test('leaves out empty lines', () {
      final rows = FileUtils.parseCsvText('Name,Grade,Bib\n\n,,\nAnn Lee,10,101\n');
      expect(rows, hasLength(2));
    });
  });

  group('decodeText', () {
    test('reads UTF-8, accents and all', () {
      expect(FileUtils.decodeText(utf8.encode('José Núñez')), 'José Núñez');
    });

    test('falls back to Latin-1 for files Excel saved that way', () {
      expect(FileUtils.decodeText(latin1.encode('José')), 'José');
    });
  });

  test('reads an Excel file, cells as shown', () async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    sheet.appendRow([
      TextCellValue('Bib'),
      TextCellValue('Name'),
      TextCellValue('Grade'),
      TextCellValue('Team'),
    ]);
    sheet.appendRow([
      IntCellValue(101),
      TextCellValue('Ann Lee'),
      IntCellValue(10),
      TextCellValue('Eagles'),
    ]);
    sheet.appendRow([
      DoubleCellValue(102),
      TextCellValue('José Núñez'),
      TextCellValue('Sr'),
      TextCellValue('Hawks'),
    ]);
    final dir = Directory.systemTemp.createTempSync('xlsx_import');
    final file = File('${dir.path}/roster.xlsx')
      ..writeAsBytesSync(excel.encode()!);

    final rows = await FileUtils.parseSpreadsheetFile(file);
    final result = processSpreadsheetData(rows!);

    expect(result.skipped, isEmpty);
    expect(result.runners, [
      {'name': 'Ann Lee', 'grade': 10, 'bib': '101', 'team': 'Eagles'},
      {'name': 'José Núñez', 'grade': 12, 'bib': '102', 'team': 'Hawks'},
    ]);
  });

  test('reads a CSV file saved by Excel on Windows', () async {
    final dir = Directory.systemTemp.createTempSync('csv_import');
    final file = File('${dir.path}/roster.csv')
      ..writeAsBytesSync([
        0xEF, 0xBB, 0xBF, // byte-order mark
        ...utf8.encode('Bib,Name,Grade\r\n007,José Núñez,9\r\n'),
      ]);

    final rows = await FileUtils.parseSpreadsheetFile(file);

    expect(processSpreadsheetData(rows!).runners.single,
        {'name': 'José Núñez', 'grade': 9, 'bib': '007'});
  });
}
