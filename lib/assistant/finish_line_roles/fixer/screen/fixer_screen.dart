import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/fixer_entry_card.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/connection_setup_screen.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_status_strip.dart';
import 'package:xceleration/core/components/app_header.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/device_connection_factory_impl.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/overflow_menu_button.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_bottom_bar.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_lobby_card.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/fixer_queue_widgets.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
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
  String? _selectedRaceName;

  @override
  void initState() {
    super.initState();
    _controller = FixerController(storage: widget.storage, raceId: 0);
    _controller.initialize();
  }

  void _onJoinTapped(RaceRecord race) {
    _selectedRaceName = race.name;
    // Re-create the controller now that the raceId is known.
    _controller.dispose();
    _controller = FixerController(storage: widget.storage, raceId: race.raceId);
    _controller.initialize();
    final notifier = PeerDiscoveryNotifier(
      role: Role.fixer,
      raceId: race.raceId,
    )..startDiscovery();
    setState(() {
      _connecting = true;
      _peerNotifier = notifier;
    });
  }

  Future<void> _onConnectionReady() async {
    // Keep notifier alive for PeerStatusStrip during the race.
    setState(() => _connecting = false);
    await _controller.joinRace();
  }

  Future<void> _onConnectionSkip() async {
    _peerNotifier?.dispose();
    setState(() {
      _connecting = false;
      _peerNotifier = null;
    });
    await _controller.joinRace();
  }

  void _onConnectionLeave() {
    _peerNotifier?.dispose();
    setState(() {
      _connecting = false;
      _peerNotifier = null;
    });
  }

  Future<void> _onGetFromCoach() async {
    final devices = const DeviceConnectionFactoryImpl().createDevices(
      DeviceName.fixer,
      DeviceType.browserDevice,
    );
    await sheet(
      context: context,
      title: 'Get Race from Coach',
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
    setState(() => _peerNotifier = null);
    _controller.leaveRace();
  }

  @override
  void dispose() {
    _controller.dispose();
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
                      raceName: _selectedRaceName ?? 'Race #${_peerNotifier!.raceId}',
                      onReady: _onConnectionReady,
                      onSkip: _onConnectionSkip,
                      onLeave: _onConnectionLeave,
                    );
                  }
                  return _RaceLobby(
                    controller: _controller,
                    onJoin: _onJoinTapped,
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

// ── Race lobby ────────────────────────────────────────────────────────────────

class _RaceLobby extends StatelessWidget {
  const _RaceLobby({
    required this.controller,
    required this.onJoin,
    required this.onGetFromCoach,
  });

  final FixerController controller;
  final void Function(RaceRecord race) onJoin;
  final VoidCallback onGetFromCoach;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundColor,
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (_, __) {
            final localRaces = controller.races;
            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              children: [
                if (localRaces.isNotEmpty) ...[
                  const RoleLobbySectionLabel(label: 'Your Races'),
                  const SizedBox(height: AppSpacing.sm),
                  for (final race in localRaces)
                    _PreloadedRaceCard(
                      race: race,
                      onTap: () => onJoin(race),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _GetFromCoachButton(
                  onTap: onGetFromCoach,
                  isSecondary: localRaces.isNotEmpty,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Coach transfer widgets ─────────────────────────────────────────────────────

class _PreloadedRaceCard extends StatefulWidget {
  const _PreloadedRaceCard({required this.race, required this.onTap});

  final RaceRecord race;
  final VoidCallback onTap;

  @override
  State<_PreloadedRaceCard> createState() => _PreloadedRaceCardState();
}

class _PreloadedRaceCardState extends State<_PreloadedRaceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          curve: AppAnimations.spring,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: _pressed
                ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
                : Colors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.race.formattedName,
                      style: AppTypography.smallBodySemibold.copyWith(
                        color: AppColors.darkColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.race.formattedDate,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mediumColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.statusPreRace.withValues(alpha: AppOpacity.light),
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                  border: Border.all(
                    color: AppColors.statusPreRace.withValues(alpha: AppOpacity.medium),
                  ),
                ),
                child: Text(
                  'Pre-loaded',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.statusPreRace,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GetFromCoachButton extends StatefulWidget {
  const _GetFromCoachButton({required this.onTap, required this.isSecondary});

  final VoidCallback onTap;
  final bool isSecondary;

  @override
  State<_GetFromCoachButton> createState() => _GetFromCoachButtonState();
}

class _GetFromCoachButtonState extends State<_GetFromCoachButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isPrimary = !widget.isSecondary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isPrimary
              ? (_pressed
                  ? AppColors.darkPrimaryColor
                  : AppColors.primaryColor)
              : (_pressed
                  ? AppColors.primaryColor.withValues(alpha: AppOpacity.light)
                  : AppColors.primaryColor.withValues(alpha: AppOpacity.faint)),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : AppColors.primaryColor.withValues(alpha: AppOpacity.strong),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_rounded,
              size: 18,
              color: isPrimary ? Colors.white : AppColors.primaryColor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isPrimary ? 'Get Race from Coach' : 'Sync a new race from Coach',
              style: AppTypography.smallBodySemibold.copyWith(
                color: isPrimary ? Colors.white : AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
