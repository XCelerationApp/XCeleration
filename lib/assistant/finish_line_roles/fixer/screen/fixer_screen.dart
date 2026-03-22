import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/fixer_entry_card.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/connection_setup_screen.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/lobby_scanner.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_status_strip.dart';
import 'package:xceleration/core/components/app_header.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/overflow_menu_button.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_bottom_bar.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_lobby_card.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/fixer_queue_widgets.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';
import 'package:xceleration/shared/role_bar/widgets/role_selector_sheet.dart';
import 'package:xceleration/shared/settings_screen.dart';

/// Entry point for the Fixer role.
///
/// The Fixer resolves entries flagged by the Bib Recorder (DUPLICATE / UNKNOWN)
/// or escalated by the Verifier (✗). Each entry can be resolved by:
///   • Matching to an existing runner via fuzzy name search
///   • Correcting the bib number directly
///   • Marking as a new / unknown runner
class FixerScreen extends StatefulWidget {
  const FixerScreen({super.key});

  @override
  State<FixerScreen> createState() => _FixerScreenState();
}

class _FixerScreenState extends State<FixerScreen> {
  late final FixerController _controller;
  late final LobbyScanner _lobbyScanner;
  final TutorialManager _tutorialManager = TutorialManager();

  // Connection setup state
  bool _connecting = false;
  PeerDiscoveryNotifier? _peerNotifier;

  @override
  void initState() {
    super.initState();
    _controller = FixerController();
    _controller.initialize();
    _lobbyScanner = LobbyScanner(localRole: Role.fixer)..start();
  }

  void _onJoinTapped(int raceId) {
    // Stop the lobby scan now that the user has selected a session.
    _lobbyScanner.dispose();
    final notifier = PeerDiscoveryNotifier(
      role: Role.fixer,
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
            title: 'Fixer',
            currentRole: Role.fixer,
            tutorialManager: _tutorialManager,
            titleStyle: AppTypography.displaySmall,
            onRoleTap: () =>
                RoleSelectorSheet.showRoleSelection(context, Role.fixer),
            onSettingsTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  currentRole: Role.fixer.toValueString(),
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
                      role: Role.fixer,
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
                    Expanded(
                      child: _controller.queue.isEmpty
                          ? const FixerEmptyState()
                          : _FixerQueue(controller: _controller),
                    ),
                    RoleBottomBar(
                      label: 'Leave Race',
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

// ── Body widgets ──────────────────────────────────────────────────────────────

class _FixerQueue extends StatelessWidget {
  const _FixerQueue({required this.controller});

  final FixerController controller;

  @override
  Widget build(BuildContext context) {
    final unresolved =
        controller.queue.where((e) => !e.isResolved).toList();
    final resolved =
        controller.queue.where((e) => e.isResolved).toList();

    return ColoredBox(
      color: AppColors.backgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            FixerStatusPill(unresolvedCount: unresolved.length),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  if (unresolved.isNotEmpty) ...[
                    FixerSectionLabel(label: 'NEEDS FIXING'),
                    const SizedBox(height: AppSpacing.sm),
                    ...unresolved.map(
                      (e) => FixerEntryCard(
                        key: ValueKey(e.id),
                        entry: e,
                        controller: controller,
                      ),
                    ),
                  ],
                  if (resolved.isNotEmpty) ...[
                    FixerSectionLabel(
                      label: 'RESOLVED',
                      topPadding: unresolved.isNotEmpty ? AppSpacing.lg : 0,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...resolved.map(
                      (e) => FixerEntryCard(
                        key: ValueKey(e.id),
                        entry: e,
                        controller: controller,
                      ),
                    ),
                  ],
                  if (unresolved.isEmpty && resolved.isEmpty)
                    const FixerLiveEmptyState(),
                ],
              ),
            ),
          ],
        ),
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
