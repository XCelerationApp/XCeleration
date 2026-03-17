/// A single bib recording made by the Bib Recorder during a race.
///
/// [correctedTo] is set when the Fixer back-propagates a correction for this
/// entry (e.g. bib 107 was actually bib 114).
class BibEntry {
  final int id;
  final int bib;
  final int? correctedTo;

  const BibEntry({
    required this.id,
    required this.bib,
    this.correctedTo,
  });

  BibEntry copyWith({int? bib, int? correctedTo}) => BibEntry(
        id: id,
        bib: bib ?? this.bib,
        correctedTo: correctedTo ?? this.correctedTo,
      );
}
