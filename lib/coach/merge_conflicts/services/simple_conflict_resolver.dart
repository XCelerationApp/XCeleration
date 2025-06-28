import '../../../shared/models/time_record.dart';
import '../../../core/utils/enums.dart';
import '../../../core/utils/logger.dart';
import '../../race_screen/widgets/runner_record.dart';

/// Simple, direct conflict resolution without complex abstractions
/// Handles the same conflicts as the complex system but with straightforward logic
class SimpleConflictResolver {
  /// Resolves missing time conflicts by directly updating records
  /// Input: List of times from user, conflict details
  /// Output: Updated timing records with conflicts resolved
  static List<TimeRecord> resolveMissingTimes({
    required List<TimeRecord> timingRecords,
    required List<RunnerRecord> runners,
    required List<String> userTimes,
    required int conflictPlace,
  }) {
    Logger.d('SimpleResolver: Resolving missing times at place $conflictPlace');
    Logger.d('SimpleResolver: User provided times: $userTimes');

    // Create a deep copy to avoid modifying original
    List<TimeRecord> updatedRecords =
        timingRecords.map((record) => record.copyWith()).toList();

    // Find and update TBD records with user-provided times
    int timeIndex = 0;
    for (int i = 0; i < updatedRecords.length; i++) {
      final record = updatedRecords[i];

      // If this is a TBD record that needs a time
      if (record.elapsedTime == 'TBD' &&
          record.place != null &&
          record.place! >= conflictPlace &&
          timeIndex < userTimes.length) {
        // Update with user time
        updatedRecords[i] = record.copyWith(
          elapsedTime: userTimes[timeIndex],
          isConfirmed: true,
          clearConflict: true,
        );

        Logger.d(
            'SimpleResolver: Updated place ${record.place} with time ${userTimes[timeIndex]}');
        timeIndex++;
      }

      // Remove conflict markers from related records
      if (record.conflict?.type == RecordType.missingTime) {
        if (record.type == RecordType.missingTime) {
          // Convert missing time record to confirm runner
          updatedRecords[i] = record.copyWith(
            type: RecordType.confirmRunner,
            isConfirmed: true,
            clearConflict: true,
          );
        } else {
          // Just clear conflict from runner time records (use updated record, not original)
          updatedRecords[i] = updatedRecords[i].copyWith(clearConflict: true);
        }
      }
    }

    Logger.d('SimpleResolver: Missing time resolution complete');
    return updatedRecords;
  }

  /// Resolves extra time conflicts by removing unused times
  /// Input: List of times to remove, all timing records
  /// Output: Updated timing records with extra times removed
  static List<TimeRecord> resolveExtraTimes({
    required List<TimeRecord> timingRecords,
    required List<String> timesToRemove,
    required int conflictPlace,
  }) {
    Logger.d('SimpleResolver: Resolving extra times at place $conflictPlace');
    Logger.d('SimpleResolver: Removing times: $timesToRemove');

    // Create a deep copy to avoid modifying original
    List<TimeRecord> updatedRecords =
        timingRecords.map((record) => record.copyWith()).toList();

    // Remove records with the specified times
    updatedRecords
        .removeWhere((record) => timesToRemove.contains(record.elapsedTime));

    // Clear conflict markers from remaining records
    for (int i = 0; i < updatedRecords.length; i++) {
      final record = updatedRecords[i];

      if (record.conflict?.type == RecordType.extraTime) {
        if (record.type == RecordType.extraTime) {
          // Convert extra time record to confirm runner
          updatedRecords[i] = record.copyWith(
            type: RecordType.confirmRunner,
            isConfirmed: true,
            clearConflict: true,
          );
        } else {
          // Just clear conflict from runner time records
          updatedRecords[i] = record.copyWith(clearConflict: true);
        }
      }
    }

    // Update places to be sequential after removal
    _updateSequentialPlaces(updatedRecords);

    Logger.d('SimpleResolver: Extra time resolution complete');
    return updatedRecords;
  }

  /// Identifies all conflicts in timing records
  /// Returns a simple list of conflicts with their types and locations
  static List<ConflictInfo> identifyConflicts(List<TimeRecord> timingRecords) {
    List<ConflictInfo> conflicts = [];

    for (int i = 0; i < timingRecords.length; i++) {
      final record = timingRecords[i];

      if (record.conflict != null) {
        conflicts.add(ConflictInfo(
          type: record.conflict!.type,
          place: record.place ?? i + 1,
          recordIndex: i,
          elapsedTime: record.elapsedTime,
          description: _getConflictDescription(record.conflict!.type),
        ));
      }
    }

    return conflicts;
  }

  /// Cleans up duplicate confirmation records
  /// Removes redundant confirmRunner records, keeping only the last one per place
  static List<TimeRecord> cleanupDuplicateConfirmations(
      List<TimeRecord> timingRecords) {
    Logger.d('SimpleResolver: Cleaning up duplicate confirmations');

    List<TimeRecord> cleanedRecords = [];
    Map<int, TimeRecord> lastConfirmByPlace = {};

    // First pass: collect all records and track last confirm per place
    for (final record in timingRecords) {
      if (record.type == RecordType.confirmRunner && record.place != null) {
        lastConfirmByPlace[record.place!] = record;
      } else {
        cleanedRecords.add(record);
      }
    }

    // Second pass: add only the last confirm record per place
    for (final confirmRecord in lastConfirmByPlace.values) {
      cleanedRecords.add(confirmRecord);
    }

    // Sort by place to maintain order
    cleanedRecords.sort((a, b) => (a.place ?? 0).compareTo(b.place ?? 0));

    Logger.d(
        'SimpleResolver: Removed ${timingRecords.length - cleanedRecords.length} duplicate confirmations');
    return cleanedRecords;
  }

  /// Updates places to be sequential (1, 2, 3, ...) after record removal
  static void _updateSequentialPlaces(List<TimeRecord> records) {
    // Filter to only runner time records and sort by current place
    final runnerTimeRecords = records
        .where((r) => r.type == RecordType.runnerTime && r.place != null)
        .toList();

    runnerTimeRecords.sort((a, b) => a.place!.compareTo(b.place!));

    // Update places to be sequential
    for (int i = 0; i < runnerTimeRecords.length; i++) {
      final record = runnerTimeRecords[i];
      final recordIndex = records.indexOf(record);
      if (recordIndex != -1) {
        records[recordIndex] = record.copyWith(place: i + 1);
      }
    }
  }

  /// Gets a human-readable description of the conflict type
  static String _getConflictDescription(RecordType conflictType) {
    switch (conflictType) {
      case RecordType.missingTime:
        return 'Missing time - need to add time for runner';
      case RecordType.extraTime:
        return 'Extra time - need to remove unused time';
      case RecordType.confirmRunner:
        return 'Confirmation needed';
      default:
        return 'Unknown conflict type';
    }
  }
}

/// Simple data class to represent a conflict
class ConflictInfo {
  final RecordType type;
  final int place;
  final int recordIndex;
  final String elapsedTime;
  final String description;

  ConflictInfo({
    required this.type,
    required this.place,
    required this.recordIndex,
    required this.elapsedTime,
    required this.description,
  });

  @override
  String toString() {
    return 'Conflict at place $place: $description (time: $elapsedTime)';
  }
}
