import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/manage_mode_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_lobby_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_mode_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/connection_setup_screen.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/core/services/nearby_connections.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_status_strip.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/components/app_header.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/device_connection_factory_impl.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';
import 'package:xceleration/shared/role_bar/widgets/role_selector_sheet.dart';
import 'package:xceleration/shared/settings_screen.dart';

/// Entry point for the new Bib Recorder (v2) role.
///
/// Creates and owns [BibRecorderV2Controller], initialises it once, then
/// routes between the four screens based on controller state:
///   - No race selected      → [RaceLobbyWidget]
///   - Race selected, connecting → [ConnectionSetupScreen]
///   - Race active           → [RaceModeWidget]
///   - Race stopped          → [ManageModeWidget]
class BibRecorderV2Screen extends StatefulWidget {
  const BibRecorderV2Screen({super.key, required this.storage});

  final IAssistantStorageService storage;

  @override
  State<BibRecorderV2Screen> createState() => _BibRecorderV2ScreenState();
}

class _BibRecorderV2ScreenState extends State<BibRecorderV2Screen> {
  late final BibRecorderV2Controller _controller;
  final TutorialManager _tutorialManager = TutorialManager();
  bool _initialising = true;

  // Connection setup state
  bool _connecting = false;
  PeerDiscoveryNotifier? _peerNotifier;
  P2PSessionService? _session;
  RaceRecord? _previousRace;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _controller = BibRecorderV2Controller(
      storage: widget.storage,
    );
    _controller.addListener(_onControllerChanged);
    _controller.initialize().then((_) {
      if (mounted) setState(() => _initialising = false);
    });
    SharedPreferences.getInstance().then((p) => _prefs = p);
  }

  Future<void> _onControllerChanged() async {
    // Detect race selection: null → non-null transition.
    if (_previousRace == null && _controller.selectedRace != null) {
      final race = _controller.selectedRace!;
      _prefs ??= await SharedPreferences.getInstance();
      final session = P2PSessionService(
        localRole: Role.bibRecorderV2,
        raceId: race.raceId,
        nearbyConnections: NearbyConnections(),
        prefs: _prefs!,
      );
      _controller.attachSession(session);
      unawaited(session.init());
      final notifier = PeerDiscoveryNotifier(
        role: Role.bibRecorderV2,
        raceId: race.raceId,
        session: session,
      );
      setState(() {
        _connecting = true;
        _peerNotifier = notifier;
        _session = session;
      });
    }
    _previousRace = _controller.selectedRace;
  }

  void _onConnectionReady() {
    // Keep notifier alive to show PeerStatusStrip during the race.
    setState(() => _connecting = false);
  }

  void _onConnectionSkip() {
    // Offline mode: discard the notifier and session.
    _peerNotifier?.dispose();
    _session?.dispose();
    setState(() {
      _connecting = false;
      _peerNotifier = null;
      _session = null;
    });
  }

  void _onConnectionLeave() {
    _peerNotifier?.dispose();
    _session?.dispose();
    _controller.leaveRace();
    setState(() {
      _connecting = false;
      _peerNotifier = null;
      _session = null;
    });
  }

  Future<void> _onGetFromCoach() async {
    final devices = const DeviceConnectionFactoryImpl().createDevices(
      DeviceName.bibRecorderV2,
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

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _peerNotifier?.dispose();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Bib Recorder V2',
            currentRole: Role.bibRecorderV2,
            tutorialManager: _tutorialManager,
            titleStyle: AppTypography.displaySmall,
            onRoleTap: () =>
                RoleSelectorSheet.showRoleSelection(context, Role.bibRecorderV2),
            onSettingsTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  currentRole: Role.bibRecorderV2.toValueString(),
                ),
              ),
            ),
          ),
          Expanded(
            child: _initialising
                ? const _LoadingBody()
                : ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      if (_controller.selectedRace == null) {
                        return RaceLobbyWidget(
                          races: _controller.races,
                          onSelectRace: _controller.selectRace,
                          onDeleteRace: _controller.deleteRaceFromLobby,
                          onGetFromCoach: _onGetFromCoach,
                        );
                      }
                      if (_connecting) {
                        return ConnectionSetupScreen(
                          role: Role.bibRecorderV2,
                          raceId: _controller.selectedRace!.raceId,
                          raceName: _controller.selectedRace!.name,
                          notifier: _peerNotifier!,
                          onReady: _onConnectionReady,
                          onSkip: _onConnectionSkip,
                          onLeave: _onConnectionLeave,
                        );
                      }
                      if (_controller.raceStopped) {
                        return ManageModeWidget(controller: _controller);
                      }
                      return Column(
                        children: [
                          if (_peerNotifier != null)
                            PeerStatusStrip(notifier: _peerNotifier!),
                          Expanded(
                            child: RaceModeWidget(controller: _controller),
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

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primaryColor),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Loading voice model…',
            style: AppTypography.smallBodyRegular.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
        ],
      ),
    );
  }
}
