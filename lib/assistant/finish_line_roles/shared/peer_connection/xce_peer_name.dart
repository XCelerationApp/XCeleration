import 'dart:io';

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

// ── Device name helpers ───────────────────────────────────────────────────────

/// Builds the advertised device name, encoding role and race ID so peers can
/// identify each other without an extra handshake message.
///
/// Format: `xce|<ROLE_CODE>|<RACE_ID>|<HOSTNAME>`
String buildXceAdvertisedName(Role role, int raceId) =>
    'xce|${xceRoleCode(role)}|$raceId|${Platform.localHostname}';

/// Parses a device name built by [buildXceAdvertisedName].
/// Returns `(role, raceId, humanName)` or `null` for non-XCeleration devices.
(Role, int, String)? parseXceDeviceName(String deviceName) {
  final parts = deviceName.split('|');
  if (parts.length < 4 || parts[0] != 'xce') return null;
  final peerRole = _xceRoleFromCode(parts[1]);
  if (peerRole == null) return null;
  final peerRaceId = int.tryParse(parts[2]);
  if (peerRaceId == null) return null;
  // Rejoin remaining parts in case the hostname itself contains '|'.
  final humanName = parts.sublist(3).join('|');
  return (peerRole, peerRaceId, humanName);
}
