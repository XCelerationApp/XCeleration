import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_lobby_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/controller/verifier_controller.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/widgets/verifier_entry_card.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/get_from_coach.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/connection_setup_screen.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/core/services/nearby_connections.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_status_strip.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_bottom_bar.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/core/components/app_header.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/widgets/verifier_stats_bar.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/overflow_menu_button.dart';
import 'package:xceleration/shared/role_bar/widgets/role_selector_sheet.dart';
import 'package:xceleration/shared/settings_screen.dart';

/// Entry point for the Verifier role.
///
/// The Verifier is stationed at the chute exit and visually confirms each
/// runner's name against the bib number shown on screen.
class VerifierScreen extends StatefulWidget {
  const VerifierScreen({super.key, required this.storage});

  final IAssistantStorageService storage;

  @override
  State<VerifierScreen> createState() => _VerifierScreenState();
}

class _VerifierScreenState extends State<VerifierScreen> {
  late final VerifierController _controller;
  final TutorialManager _tutorialManager = TutorialManager();

  // Connection setup state
  bool _connecting = false;
  PeerDiscoveryNotifier? _peerNotifier;
  P2PSessionService? _session;
  String? _selectedRaceName;
  int _selectedRaceId = 0;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _controller = VerifierController(storage: widget.storage);
    _controller.initialize();
    SharedPreferences.getInstance().then((p) => _prefs = p);
  }

  Future<void> _onJoinTapped(RaceRecord race) async {
    _selectedRaceName = race.name;
    _selectedRaceId = race.raceId;
    _prefs ??= await SharedPreferences.getInstance();
    final session = P2PSessionService(
      localRole: Role.verifier,
      raceId: race.raceId,
      nearbyConnections: NearbyConnections(),
      prefs: _prefs!,
    );
    _controller.attachSession(session);
    unawaited(session.init());
    final notifier = PeerDiscoveryNotifier(
      role: Role.verifier,
      raceId: race.raceId,
      session: session,
    );
    setState(() {
      _connecting = true;
      _peerNotifier = notifier;
      _session = session;
    });
  }

  void _onConnectionReady() {
    // Keep notifier alive for PeerStatusStrip during the race.
    setState(() => _connecting = false);
    _controller.joinRace(raceId: _selectedRaceId);
  }

  void _onConnectionSkip() {
    // Offline mode: discard notifier and session.
    _peerNotifier?.dispose();
    _session?.dispose();
    setState(() {
      _connecting = false;
      _peerNotifier = null;
      _session = null;
    });
    _controller.joinRace(raceId: _selectedRaceId);
  }

  void _onConnectionLeave() {
    _peerNotifier?.dispose();
    _session?.dispose();
    setState(() {
      _connecting = false;
      _peerNotifier = null;
      _session = null;
    });
  }

  Future<void> _onGetFromCoach() => getFromCoach(
        context: context,
        deviceName: DeviceName.verifier,
        onData: _controller.processLoadedRaceData,
      );

  /// Tears down the active P2P session and returns to the lobby.
  void _leaveRace() {
    _peerNotifier?.dispose();
    _session?.dispose();
    setState(() {
      _peerNotifier = null;
      _session = null;
    });
    _controller.leaveRace();
  }

  @override
  void dispose() {
    _controller.dispose();
    _peerNotifier?.dispose();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          AppHeader(
            title: 'Verifier',
            currentRole: Role.verifier,
            tutorialManager: _tutorialManager,
            titleStyle: AppTypography.displaySmall,
            onRoleTap: () =>
                RoleSelectorSheet.showRoleSelection(context, Role.verifier),
            onSettingsTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  currentRole: Role.verifier.toValueString(),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                if (!_controller.isInRace) {
                  if (_connecting) {
                    return ConnectionSetupScreen(
                      role: Role.verifier,
                      raceId: _peerNotifier!.raceId,
                      raceName: _selectedRaceName ?? 'Race #${_peerNotifier!.raceId}',
                      notifier: _peerNotifier!,
                      onReady: _onConnectionReady,
                      onSkip: _onConnectionSkip,
                      onLeave: _onConnectionLeave,
                    );
                  }
                  return RaceLobbyWidget(
                    races: _controller.races,
                    onSelectRace: _onJoinTapped,
                    onDeleteRace: _controller.deleteRaceFromLobby,
                    onGetFromCoach: _onGetFromCoach,
                  );
                }
                return Column(
                  children: [
                    if (_peerNotifier != null)
                      PeerStatusStrip(notifier: _peerNotifier!),
                    VerifierStatsBar(controller: _controller),
                    Expanded(
                      child: _controller.entries.isEmpty
                          ? const VerifierEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                                bottom: AppSpacing.xxl,
                              ),
                              itemCount: _controller.entries.length,
                              itemBuilder: (_, i) => VerifierEntryCard(
                                key: ValueKey(_controller.entries[i].id),
                                entry: _controller.entries[i],
                                controller: _controller,
                              ),
                            ),
                    ),
                    RoleBottomBar(
                      label: 'Stop Race',
                      buttonColor: AppColors.redColor,
                      onTap: _leaveRace,
                      menuItems: [
                        OverflowMenuItem(
                          label: 'Leave Race',
                          onTap: _leaveRace,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


