import 'package:xceleration/shared/models/database/race_runner.dart';

class BibDatum {
  final String bib;
  final String name;
  final String teamAbbreviation;
  final String grade;

  BibDatum(
      {required this.bib,
      required this.name,
      required this.teamAbbreviation,
      required this.grade});

  factory BibDatum.fromRaceRunner(RaceRunner raceRunner) {
    return BibDatum(
      bib: raceRunner.runner.bibNumber!.toString(),
      name: raceRunner.runner.name!,
      teamAbbreviation: raceRunner.team.abbreviation!,
      grade: raceRunner.runner.grade!.toString(),
    );
  }

  String encode() {
    return [
      Uri.encodeComponent(bib),
      Uri.encodeComponent(name),
      Uri.encodeComponent(teamAbbreviation),
      Uri.encodeComponent(grade),
    ].join(',');
  }

  factory BibDatum.fromEncodedString(String encodedString) {
    final parts = encodedString.split(',');
    if (parts.length != 4) {
      throw Exception('Invalid encoded runner string: $encodedString');
    }
    return BibDatum(
      bib: Uri.decodeComponent(parts[0]),
      name: Uri.decodeComponent(parts[1]),
      teamAbbreviation: Uri.decodeComponent(parts[2]),
      grade: Uri.decodeComponent(parts[3]),
    );
  }
}
