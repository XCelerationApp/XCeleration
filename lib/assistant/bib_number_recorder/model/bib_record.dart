import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';

class BibDatumRecord extends BibDatum {
  BibDatumRecordFlags flags;

  BibDatumRecord({
    required super.bib,
    required super.name,
    required super.teamAbbreviation,
    required super.grade,
    super.teamColor,
    this.flags = const BibDatumRecordFlags(
      notInDatabase: false,
      duplicateBibNumber: false,
    ),
  });

  factory BibDatumRecord.blank() {
    return BibDatumRecord(
      bib: '',
      name: '',
      teamAbbreviation: '',
      grade: '',
    );
  }

  factory BibDatumRecord.fromBibDatum(
    BibDatum datum, {
    BibDatumRecordFlags flags = const BibDatumRecordFlags(
      notInDatabase: false,
      duplicateBibNumber: false,
    ),
  }) {
    return BibDatumRecord(
      bib: datum.bib,
      name: datum.name,
      teamAbbreviation: datum.teamAbbreviation,
      grade: datum.grade,
      teamColor: datum.teamColor,
      flags: flags,
    );
  }

  BibDatumRecord copyWith({
    String? bib,
    String? name,
    String? teamAbbreviation,
    String? grade,
    Color? teamColor,
    BibDatumRecordFlags? flags,
  }) {
    return BibDatumRecord(
      bib: bib ?? this.bib,
      name: name ?? this.name,
      teamAbbreviation: teamAbbreviation ?? this.teamAbbreviation,
      grade: grade ?? this.grade,
      teamColor: teamColor ?? this.teamColor,
      flags: flags ?? this.flags,
    );
  }

  bool get hasErrors => flags.notInDatabase || flags.duplicateBibNumber;
  @override
  bool get isValid => !hasErrors && bib.isNotEmpty;
}

class BibDatumRecordFlags {
  final bool notInDatabase;
  final bool duplicateBibNumber;

  const BibDatumRecordFlags({
    required this.notInDatabase,
    required this.duplicateBibNumber,
  });

  BibDatumRecordFlags copyWith({
    bool? notInDatabase,
    bool? duplicateBibNumber,
  }) {
    return BibDatumRecordFlags(
      notInDatabase: notInDatabase ?? this.notInDatabase,
      duplicateBibNumber: duplicateBibNumber ?? this.duplicateBibNumber,
    );
  }
}
