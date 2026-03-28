import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/utils/logger.dart';

/// A single recorded Drive pick — stores everything needed to re-download the
/// file without a `files.list` API call (which requires broader scope than
/// `drive.file`).
class RecentDriveSelection {
  final String fileId;
  final String name;
  final String mimeType;
  final DateTime selectedAt;

  const RecentDriveSelection({
    required this.fileId,
    required this.name,
    required this.mimeType,
    required this.selectedAt,
  });

  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'name': name,
        'mimeType': mimeType,
        'selectedAt': selectedAt.millisecondsSinceEpoch,
      };

  factory RecentDriveSelection.fromJson(Map<String, dynamic> json) =>
      RecentDriveSelection(
        fileId: json['fileId'] as String,
        name: json['name'] as String,
        mimeType: (json['mimeType'] as String?) ?? '',
        selectedAt:
            DateTime.fromMillisecondsSinceEpoch(json['selectedAt'] as int),
      );
}

/// Persists the full metadata (file ID, name, MIME type, selection timestamp)
/// for each Google Drive file the user has picked via the Google Picker.
/// This is the source of truth for the "Previously Selected" list — no Drive
/// API list call required.
class RecentDriveSelectionService {
  static const _key = 'recent_drive_spreadsheet_selections';
  static const _maxEntries = 20;

  static RecentDriveSelectionService? _instance;
  static RecentDriveSelectionService get instance =>
      _instance ??= RecentDriveSelectionService._();
  RecentDriveSelectionService._();

  /// Records that the user selected [fileId] / [name] / [mimeType] right now.
  /// Moves an existing entry for the same ID to the top; trims to [_maxEntries].
  Future<void> record(String fileId, String name, String mimeType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = await _load(prefs);
      entries.removeWhere((e) => e.fileId == fileId);
      entries.insert(
        0,
        RecentDriveSelection(
          fileId: fileId,
          name: name,
          mimeType: mimeType,
          selectedAt: DateTime.now(),
        ),
      );
      final trimmed = entries.take(_maxEntries).toList();
      await prefs.setString(
        _key,
        jsonEncode(trimmed.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      Logger.e('[RecentDrive] Error recording selection: $e');
    }
  }

  /// Returns all recorded Drive picks, most-recently selected first.
  Future<List<RecentDriveSelection>> getRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await _load(prefs);
    } catch (e) {
      Logger.e('[RecentDrive] Error loading recents: $e');
      return [];
    }
  }

  Future<List<RecentDriveSelection>> _load(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) =>
            RecentDriveSelection.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
