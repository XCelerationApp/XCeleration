import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/core/utils/logger.dart';

/// A single entry in the local spreadsheet recents list.
class RecentLocalFile {
  final String name;
  final String path;
  final DateTime lastUsed;

  const RecentLocalFile({
    required this.name,
    required this.path,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'lastUsed': lastUsed.millisecondsSinceEpoch,
      };

  factory RecentLocalFile.fromJson(Map<String, dynamic> json) =>
      RecentLocalFile(
        name: json['name'] as String,
        path: json['path'] as String,
        lastUsed:
            DateTime.fromMillisecondsSinceEpoch(json['lastUsed'] as int),
      );
}

/// Persists a short list of recently-used local spreadsheet files in
/// SharedPreferences so they can be shown in the "Recent Spreadsheets" picker.
class RecentLocalSpreadsheetService {
  static const _key = 'recent_local_spreadsheets';
  static const _maxEntries = 10;

  static RecentLocalSpreadsheetService? _instance;
  static RecentLocalSpreadsheetService get instance =>
      _instance ??= RecentLocalSpreadsheetService._();
  RecentLocalSpreadsheetService._();

  /// Records [name] + [path] as the most-recently used local file.
  /// Moves an existing entry for the same path to the top; trims to [_maxEntries].
  Future<void> record(String name, String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = await _load(prefs);
      entries.removeWhere((e) => e.path == path);
      entries.insert(
        0,
        RecentLocalFile(name: name, path: path, lastUsed: DateTime.now()),
      );
      final trimmed = entries.take(_maxEntries).toList();
      await prefs.setString(
        _key,
        jsonEncode(trimmed.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      Logger.e('[RecentLocal] Error recording file: $e');
    }
  }

  /// Returns recently-used local files, most-recent first.
  Future<List<RecentLocalFile>> getRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await _load(prefs);
    } catch (e) {
      Logger.e('[RecentLocal] Error loading recents: $e');
      return [];
    }
  }

  Future<List<RecentLocalFile>> _load(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => RecentLocalFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
