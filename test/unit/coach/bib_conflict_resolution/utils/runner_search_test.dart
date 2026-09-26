import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/bib_conflict_resolution/utils/runner_search.dart';

// Finding a runner by a name typed in a hurry at the finish line.

typedef _R = ({String name, String bib});

const _roster = <_R>[
  (name: 'John Smith', bib: '101'),
  (name: 'Johnathan Reyes', bib: '102'),
  (name: 'Mary-Kate Olsen', bib: '215'),
  (name: 'Sam Smithers', bib: '1101'),
  (name: 'Ava Johnson', bib: '330'),
];

List<String> _find(String query) => searchRunners<_R>(_roster, query,
        nameOf: (r) => r.name, bibOf: (r) => r.bib)
    .map((r) => r.name)
    .toList();

void main() {
  test('a first or last name, or part of one', () {
    expect(_find('smith').first, 'John Smith');
    expect(_find('john'), containsAll(['John Smith', 'Johnathan Reyes']));
    expect(_find('rey'), ['Johnathan Reyes']);
  });

  test('both names in either order', () {
    expect(_find('smith john').first, 'John Smith');
    expect(_find('john smith').first, 'John Smith');
  });

  test('a slip of the thumb still finds them', () {
    expect(_find('jonh smtih').first, 'John Smith');
    expect(_find('olsne'), ['Mary-Kate Olsen']);
  });

  test('a hyphenated name matches either half', () {
    expect(_find('kate'), ['Mary-Kate Olsen']);
  });

  test('a number finds the bib, exact first', () {
    expect(_find('101'), ['John Smith']);
    expect(_find('11'), ['Sam Smithers']);
  });

  test('nothing for a name nobody has', () {
    expect(_find('zelda'), isEmpty);
    expect(_find(''), isEmpty);
  });

  test('closer matches come first', () {
    // "smith" is all of John Smith's last name, the start of Smithers.
    expect(_find('smith'), ['John Smith', 'Sam Smithers']);
  });

  test('shows at most the best few', () {
    final many = [for (var i = 0; i < 20; i++) (name: 'Alex Lee $i', bib: '$i')];
    expect(
        searchRunners<_R>(many, 'alex',
            nameOf: (r) => r.name, bibOf: (r) => r.bib),
        hasLength(8));
  });
}
