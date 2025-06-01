import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/utils/encode_utils.dart';
import 'package:xceleration/coach/merge_conflicts/model/timing_data.dart';
import 'package:xceleration/core/utils/logger.dart';

void main() {
  test('decodeRaceTimesString includes all places from 1 to 21', () async {
    const encoded = '0.95,1.18,1.36,1.54,3.17,3.37,RecordType.confirmRunner 6 6.69,11.10,11.28,11.44,11.61,11.81,RecordType.extraRunner 1 13.97,14.73,14.90,15.05,15.23,RecordType.confirmRunner 14 17.61,18.60,18.77,18.95,TBD,RecordType.missingRunner 1 20.26,RecordType.confirmRunner 18 20.84,24.50,24.70,24.88,RecordType.extraRunner 1 28.50,30.11,RecordType.confirmRunner 21 30.88';
    final TimingData timingData = await decodeRaceTimesString(encoded);
    final recordPlaces = timingData.records.map((r) => r.place).whereType<int>().toList();
    final maxPlace = 21;
    final expectedPlaces = Set<int>.from(List.generate(maxPlace, (i) => i + 1));
    final actualPlaces = Set<int>.from(recordPlaces);
    final missingPlaces = expectedPlaces.difference(actualPlaces);
    if (missingPlaces.isNotEmpty) {
      Logger.e('Test failed: Missing places: $missingPlaces');
    }
    expect(missingPlaces.isEmpty, true, reason: 'All places from 1 to 21 should be present');
  });
} 