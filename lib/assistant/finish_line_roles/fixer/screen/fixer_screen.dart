import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_lobby_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/fixer_entry_card.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/connection_setup_screen.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/core/services/nearby_connections.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_status_strip.dart';
import 'package:xceleration/core/components/app_header.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/device_connection_factory_impl.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/overflow_menu_button.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_bottom_bar.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/fixer_queue_widgets.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
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
  const FixerScreen({super.key, required this.storage});

  final IAssistantStorageService storage;

  @override
  State<FixerScreen> createState() => _FixerScreenState();
}

class _FixerScreenState extends State<FixerScreen> {
  late FixerController _controller;
  final TutorialManager _tutorialManager = TutorialManager();

  // Connection setup state
  bool _connecting = false;
  PeerDiscoveryNotifier? _peerNotifier;
  P2PSessionService? _session;
  String? _selectedRaceName;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _controller = FixerController(storage: widget.storage, raceId: 0);
    _controller.initialize();
    SharedPreferences.getInstance().then((p) => _prefs = p);
  }

  Future<void> _onJoinTapped(RaceRecord race) async {
    _selectedRaceName = race.name;
    _prefs ??= await SharedPreferences.getInstance();
    // Re-create the controller now that the raceId and session are known.
    _session?.dispose();
    _controller.dispose();
    final session = P2PSessionService(
      localRole: Role.fixer,
      raceId: race.raceId,
      nearbyConnections: NearbyConnections(),
      prefs: _prefs!,
    );
    unawaited(session.init());
    _controller = FixerController(
      storage: widget.storage,
      raceId: race.raceId,
      session: session,
    );
    _controller.initialize();
    final notifier = PeerDiscoveryNotifier(
      role: Role.fixer,
      raceId: race.raceId,
      session: session,
    );
    setState(() {
      _connecting = true;
      _peerNotifier = notifier;
      _session = session;
    });
  }

  Future<void> _onConnectionReady() async {
    // Keep notifier alive for PeerStatusStrip during the race.
    setState(() => _connecting = false);
    await _controller.joinRace();
  }

  Future<void> _onConnectionSkip() async {
    // Offline mode: discard notifier and session.
    _peerNotifier?.dispose();
    _session?.dispose();
    setState(() {
      _connecting = false;
      _peerNotifier = null;
      _session = null;
    });
    await _controller.joinRace();
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

  Future<void> _onGetFromCoach() async {
    final devices = const DeviceConnectionFactoryImpl().createDevices(
      DeviceName.fixer,
      DeviceType.browserDevice,
    );
    await sheet(
      context: context,
      title: 'Load a new race from Coach',
      body: DeviceConnectionWidget(devices: devices),
    );
    final data = devices.coach?.data;
    if (data == null || !mounted) return;
    final result = await _controller.processLoadedRaceData(data);
    if (result case Failure(:final error) when mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.userMessage)),
      );
    }
  }

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


