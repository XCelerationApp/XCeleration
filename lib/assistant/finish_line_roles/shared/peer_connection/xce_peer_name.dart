import 'dart:convert';
import 'dart:io';

import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

// ── Service type ──────────────────────────────────────────────────────────────

/// Fixed Bonjour service type (≤ 15 chars) declared in ios/Runner/Info.plist
/// under NSBonjourServices as `_xce-finline._tcp`.
const kXceServiceType = 'xce-finline';

// ── Role encoding ─────────────────────────────────────────────────────────────

/// Encodes a [Role] as a short uppercase code used in the advertised name.
String xceRoleCode(Role role) => switch (role) {
      Role.bibRecorderV2 => 'BIB',
      Role.verifier => 'VFR',
      Role.fixer => 'FIX',
      _ => 'UNK',
    };

Role? _xceRoleFromCode(String code) => switch (code) {
      'BIB' => Role.bibRecorderV2,
      'VFR' => Role.verifier,
      'FIX' => Role.fixer,
      _ => null,
    };

// ── Race key ──────────────────────────────────────────────────────────────────

/// Short key identifying a race across phones.
///
/// Every phone loaded the race from the same Coach, so they share its id, name
/// and date. The Coach's local race id alone is not enough: two coaches at the
/// same meet can both have a race #3.
String xceRaceKey(RaceRecord race) => _fnv1a32(
        '${race.raceId}|${race.name}|${race.date.millisecondsSinceEpoch}')
    .toRadixString(16)
    .padLeft(8, '0');

/// 32-bit FNV-1a over UTF-8 bytes. Unlike [String.hashCode] it is stable
/// across devices, platforms and Dart versions.
int _fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

// ── Device name helpers ───────────────────────────────────────────────────────

/// Multipeer Connectivity rejects display names longer than 63 UTF-8 bytes.
const int kMaxAdvertisedNameBytes = 63;

/// Builds the advertised device name, encoding role and race key so peers can
/// identify each other without an extra handshake message.
///
/// Format: `xce|<ROLE_CODE>|<RACE_KEY>|<HOSTNAME>`, with the hostname
/// shortened so the whole name fits in [kMaxAdvertisedNameBytes].
String buildXceAdvertisedName(Role role, String raceKey, {String? hostname}) {
  final prefix = 'xce|${xceRoleCode(role)}|$raceKey|';
  var host = hostname ?? Platform.localHostname;
  final budget = kMaxAdvertisedNameBytes - utf8.encode(prefix).length;
  // Drop whole characters (not bytes) until the name fits.
  while (utf8.encode(host).length > budget) {
    final chars = host.runes.toList()..removeLast();
    host = String.fromCharCodes(chars);
  }
  return '$prefix$host';
}

/// Parses a device name built by [buildXceAdvertisedName].
/// Returns `null` if the name does not match the expected format.
(Role, String, String)? parseXceDeviceName(String deviceName) {
  final parts = deviceName.split('|');
  if (parts.length < 4 || parts[0] != 'xce') return null;
  final peerRole = _xceRoleFromCode(parts[1]);
  if (peerRole == null) return null;
  final raceKey = parts[2];
  if (raceKey.isEmpty) return null;
  // Rejoin remaining parts in case the hostname itself contains '|'.
  final humanName = parts.sublist(3).join('|');
  return (peerRole, raceKey, humanName);
}
