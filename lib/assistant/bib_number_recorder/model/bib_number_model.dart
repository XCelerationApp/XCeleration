import 'package:flutter/material.dart';
import '../../../coach/race_screen/widgets/runner_record.dart';
import 'bib_records_provider.dart';
import 'package:provider/provider.dart';

class BibNumberModel {
  final List<RunnerRecord> runners;

  BibNumberModel({
    List<RunnerRecord>? initialRunners,
  })  : runners = initialRunners ?? [];

  bool get hasRunners => runners.isNotEmpty;

  // Helper to check if we have any non-empty bib numbers
  bool hasNonEmptyBibNumbers(BuildContext context) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    return provider.bibRecords.any((record) => record.bib.isNotEmpty);
  }

  // Helper to count non-empty bib numbers
  int countNonEmptyBibNumbers(BuildContext context) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    return provider.bibRecords.where((bib) => bib.bib.isNotEmpty).length;
  }

  // Helper to count empty bib numbers
  int countEmptyBibNumbers(BuildContext context) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    return provider.bibRecords.where((bib) => bib.bib.isEmpty).length;
  }

  // Helper to count duplicate bib numbers
  int countDuplicateBibNumbers(BuildContext context) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    return provider.bibRecords
        .where((bib) => bib.flags.duplicateBibNumber == true)
        .length;
  }

  // Helper to count unknown bib numbers
  int countUnknownBibNumbers(BuildContext context) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    return provider.bibRecords
        .where((bib) => bib.flags.notInDatabase == true)
        .length;
  }
}
