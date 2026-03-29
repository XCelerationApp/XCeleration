/// A single bib recording made by the Bib Recorder during a race.
///
/// [correctedTo] is set when the Fixer back-propagates a bib correction
/// (e.g. bib 107 was actually bib 114).
///
/// [isNewRunner] is set when the Fixer resolves the entry as a new runner
/// without changing the bib number.
class BibEntry {
  final int id;
  final int bib;
  final int? correctedTo;
  final bool isNewRunner;

  const BibEntry({
    required this.id,
    required this.bib,
    this.correctedTo,
    this.isNewRunner = false,
  });

  BibEntry copyWith({
    int? bib,
    int? Function()? correctedTo,
    bool? isNewRunner,
  }) =>
      BibEntry(
        id: id,
        bib: bib ?? this.bib,
        correctedTo: correctedTo != null ? correctedTo() : this.correctedTo,
        isNewRunner: isNewRunner ?? this.isNewRunner,
      );
}
