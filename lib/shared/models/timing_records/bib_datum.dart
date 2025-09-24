import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';

class BibDatum {
  final String bib;
  String? name;
  String? teamAbbreviation;
  String? grade;
  Color? teamColor;

  BibDatum(
      {required this.bib,
      this.name,
      this.teamAbbreviation,
      this.grade,
      this.teamColor});

  /// True if all optional fields were provided (name, teamAbbreviation, grade)
  bool get isValid =>
      (name != null && name!.isNotEmpty) &&
      (teamAbbreviation != null && teamAbbreviation!.isNotEmpty) &&
      (grade != null && grade!.isNotEmpty);

  factory BibDatum.fromRaceRunner(RaceRunner raceRunner) {
    return BibDatum(
      bib: raceRunner.runner.bibNumber!.toString(),
      name: raceRunner.runner.name,
      teamAbbreviation: raceRunner.team.abbreviation,
      grade: raceRunner.runner.grade?.toString(),
      teamColor: raceRunner.team.color,
    );
  }

  String encode() {
    // If full data is present, encode all fields; otherwise encode bib only
    if (isValid) {
      return [
        Uri.encodeComponent(bib),
        Uri.encodeComponent(name!),
        Uri.encodeComponent(teamAbbreviation!),
        Uri.encodeComponent(grade!),
        teamColor?.toARGB32().toString() ?? '',
      ].join(',');
    }
    return Uri.encodeComponent(bib);
  }

  factory BibDatum.fromEncodedString(String encodedString) {
    final parts = encodedString
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      throw Exception('Invalid encoded runner string: $encodedString');
    }

    if (parts.length == 1) {
      // Only bib provided
      return BibDatum(
        bib: Uri.decodeComponent(parts[0]),
      );
    }

    if (parts.length >= 4) {
      // Use first four fields (bib, name, teamAbbreviation, grade)
      Color? teamColor;
      if (parts.length >= 5 && parts[4].isNotEmpty) {
        try {
          teamColor = Color(int.parse(parts[4]));
        } catch (e) {
          // If parsing fails, teamColor remains null
        }
      }

      return BibDatum(
        bib: Uri.decodeComponent(parts[0]),
        name: Uri.decodeComponent(parts[1]),
        teamAbbreviation: Uri.decodeComponent(parts[2]),
        grade: Uri.decodeComponent(parts[3]),
        teamColor: teamColor,
      );
    }

    // Fallback: treat the first field as bib when format is unexpected
    return BibDatum(bib: Uri.decodeComponent(parts.first));
  }
}
