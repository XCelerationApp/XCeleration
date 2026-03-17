import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/fixer_entry_card.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/connection_setup_screen.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_status_strip.dart';
import 'package:xceleration/core/components/app_header.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/overflow_menu_button.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_bottom_bar.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_lobby_card.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
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
  final TutorialManager _tutorialManager = TutorialManager();

  // Connection setup state
  bool _connecting = false;
  PeerDiscoveryNotifier? _peerNotifier;

  @override
  void initState() {
    super.initState();
    _controller = FixerController();
    _controller.initialize();
  }

  void _onJoinTapped() {
    final notifier = PeerDiscoveryNotifier(
      role: Role.fixer,
      // TODO(XCE-230): use real race ID from discovered P2P session.
      raceId: 1,
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
                      // TODO(XCE-230): use real race ID/name from P2P session.
                      raceId: 1,
                      raceName: 'Demo Fixer Session',
                      onReady: _onConnectionReady,
                      onSkip: _onConnectionSkip,
                      onLeave: _onConnectionLeave,
                    );
                  }
                  return _RaceLobby(onJoin: _onJoinTapped);
                }
                return Column(
                  children: [
                    if (_peerNotifier != null)
                      PeerStatusStrip(notifier: _peerNotifier!),
                    Expanded(
                      child: _controller.queue.isEmpty
                          ? const _EmptyState()
                          : _FixerQueue(controller: _controller),
                    ),
                    RoleBottomBar(
                      label: 'Leave Race',
                      buttonColor: AppColors.redColor,
                      onTap: _controller.leaveRace,
                      menuItems: [
                        OverflowMenuItem(
                          label: 'Leave Race',
                          onTap: _controller.leaveRace,
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
            _StatusPill(unresolvedCount: unresolved.length),
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
                    _SectionLabel(label: 'NEEDS FIXING'),
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
                    _SectionLabel(
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
                    const _LiveEmptyState(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.unresolvedCount});

  final int unresolvedCount;

  @override
  Widget build(BuildContext context) {
    final hasIssues = unresolvedCount > 0;
    final pillColor =
        hasIssues ? AppColors.primaryColor : AppColors.statusFinished;
    return AnimatedContainer(
      duration: AppAnimations.standard,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: pillColor.withValues(alpha: AppOpacity.strong)),
      ),
      child: Text(
        hasIssues
            ? '$unresolvedCount entr${unresolvedCount == 1 ? "y" : "ies"} need attention'
            : 'All entries resolved ✓',
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w700,
          color: pillColor,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.topPadding = 0});

  final String label;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Text(
        label,
        style: AppTypography.labelTiny.copyWith(
          color: AppColors.mediumColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _LiveEmptyState extends StatelessWidget {
  const _LiveEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 36)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No issues yet',
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Flagged entries from Verifier appear here',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.lightColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔧', style: TextStyle(fontSize: 40)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No conflicts to resolve',
            style: AppTypography.smallBodyRegular.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Flagged entries from the Verifier will appear here.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.lightColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Race lobby ────────────────────────────────────────────────────────────────

class _RaceLobby extends StatelessWidget {
  const _RaceLobby({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundColor,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          children: [
            const RoleLobbySectionLabel(label: 'Available'),
            const SizedBox(height: AppSpacing.sm),
            RoleLobbySessionCard(
              title: 'Demo Fixer Session',
              subtitle: 'Connect to the Verifier',
              onTap: onJoin,
            ),
          ],
        ),
      ),
    );
  }
}

