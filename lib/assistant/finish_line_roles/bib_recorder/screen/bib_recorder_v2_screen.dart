import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/manage_mode_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_lobby_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_mode_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/connection_setup_screen.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_status_strip.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/components/app_header.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';
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
  RaceRecord? _previousRace;

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
  }

  void _onControllerChanged() {
    // Detect race selection: null → non-null transition.
    if (_previousRace == null && _controller.selectedRace != null) {
      final race = _controller.selectedRace!;
      final notifier = PeerDiscoveryNotifier(
        role: Role.bibRecorderV2,
        raceId: race.raceId,
      )..startDiscovery();
      setState(() {
        _connecting = true;
        _peerNotifier = notifier;
      });
    }
    _previousRace = _controller.selectedRace;
  }

  void _onConnectionReady() {
    // Keep notifier alive to show PeerStatusStrip during the race.
    setState(() => _connecting = false);
  }

  void _onConnectionSkip() {
    // Offline mode: discard the notifier.
    _peerNotifier?.dispose();
    setState(() {
      _connecting = false;
      _peerNotifier = null;
    });
  }

  void _onConnectionLeave() {
    _peerNotifier?.dispose();
    _controller.leaveRace();
    setState(() {
      _connecting = false;
      _peerNotifier = null;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _peerNotifier?.dispose();
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
                        return RaceLobbyWidget(controller: _controller);
                      }
                      if (_connecting) {
                        return ConnectionSetupScreen(
                          role: Role.bibRecorderV2,
                          raceId: _controller.selectedRace!.raceId,
                          raceName: _controller.selectedRace!.name,
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
          const SizedBox(height: 16),
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
