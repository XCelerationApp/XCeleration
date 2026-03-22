import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/controller/verifier_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/widgets/verifier_entry_card.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/connection_setup_screen.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/lobby_scanner.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_status_strip.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_bottom_bar.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_lobby_card.dart';
import 'package:xceleration/core/components/app_header.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/widgets/verifier_stats_bar.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/overflow_menu_button.dart';
import 'package:xceleration/shared/role_bar/widgets/role_selector_sheet.dart';
import 'package:xceleration/shared/settings_screen.dart';

/// Entry point for the Verifier role.
///
/// The Verifier is stationed at the chute exit and visually confirms each
/// runner's name against the bib number shown on screen.
class VerifierScreen extends StatefulWidget {
  const VerifierScreen({super.key});

  @override
  State<VerifierScreen> createState() => _VerifierScreenState();
}

class _VerifierScreenState extends State<VerifierScreen> {
  late final VerifierController _controller;
  late final LobbyScanner _lobbyScanner;
  final TutorialManager _tutorialManager = TutorialManager();

  // Connection setup state
  bool _connecting = false;
  PeerDiscoveryNotifier? _peerNotifier;

  @override
  void initState() {
    super.initState();
    _controller = VerifierController();
    _controller.initialize();
    _lobbyScanner = LobbyScanner(localRole: Role.verifier)..start();
  }

  void _onJoinTapped(int raceId) {
    // Stop the lobby scan now that the user has selected a session.
    _lobbyScanner.dispose();
    final notifier = PeerDiscoveryNotifier(
      role: Role.verifier,
      raceId: raceId,
    )..startDiscovery();
    setState(() {
      _connecting = true;
      _peerNotifier = notifier;
    });
  }

  void _onConnectionReady() {
    // Keep notifier alive for PeerStatusStrip during the race.
    setState(() => _connecting = false);
    _controller.joinRace();
  }

  void _onConnectionSkip() {
    _peerNotifier?.dispose();
    setState(() {
      _connecting = false;
      _peerNotifier = null;
    });
    _controller.joinRace();
  }

  void _onConnectionLeave() {
    _peerNotifier?.dispose();
    setState(() {
      _connecting = false;
      _peerNotifier = null;
    });
  }

  /// Tears down the active P2P session and returns to the lobby.
  void _leaveRace() {
    _peerNotifier?.dispose();
    setState(() => _peerNotifier = null);
    _controller.leaveRace();
  }

  @override
  void dispose() {
    _controller.dispose();
    _lobbyScanner.dispose();
    _peerNotifier?.dispose();
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
                      raceName: 'Race #${_peerNotifier!.raceId}',
                      onReady: _onConnectionReady,
                      onSkip: _onConnectionSkip,
                      onLeave: _onConnectionLeave,
                    );
                  }
                  return _RaceLobby(
                    scanner: _lobbyScanner,
                    onJoin: _onJoinTapped,
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

// ── Race lobby ────────────────────────────────────────────────────────────────

class _RaceLobby extends StatelessWidget {
  const _RaceLobby({required this.scanner, required this.onJoin});

  final LobbyScanner scanner;
  final void Function(int raceId) onJoin;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundColor,
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: scanner,
          builder: (_, __) {
            final sessions = scanner.sessions;
            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              children: [
                const RoleLobbySectionLabel(label: 'Available'),
                const SizedBox(height: AppSpacing.sm),
                if (sessions.isEmpty)
                  const RoleLobbySearchingCard(
                    subtitle: 'Looking for a Bib Recorder on this network…',
                  )
                else
                  for (final s in sessions)
                    RoleLobbySessionCard(
                      title: 'Race #${s.raceId}',
                      subtitle: s.hostName,
                      onTap: () => onJoin(s.raceId),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
