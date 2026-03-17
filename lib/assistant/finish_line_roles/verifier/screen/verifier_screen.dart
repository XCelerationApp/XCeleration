import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/controller/verifier_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/widgets/verifier_entry_card.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/connection_setup_screen.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_status_strip.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_bottom_bar.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/role_lobby_card.dart';
import 'package:xceleration/core/components/app_header.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
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
  final TutorialManager _tutorialManager = TutorialManager();

  // Connection setup state
  bool _connecting = false;
  PeerDiscoveryNotifier? _peerNotifier;

  @override
  void initState() {
    super.initState();
    _controller = VerifierController();
    _controller.initialize();
  }

  void _onJoinTapped() {
    final notifier = PeerDiscoveryNotifier(
      role: Role.verifier,
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
                      // TODO(XCE-230): use real race ID/name from P2P session.
                      raceId: 1,
                      raceName: 'Demo Verifier Session',
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
                    _StatsBar(controller: _controller),
                    Expanded(
                      child: _controller.entries.isEmpty
                          ? const _EmptyState()
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

// ── Stats bar ─────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.controller});

  final VerifierController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          _StatChip(
            label: 'CORRECT',
            count: controller.confirmed,
            color: AppColors.statusFinished,
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatChip(
            label: 'WRONG',
            count: controller.wrong,
            color: AppColors.redColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatChip(
            label: 'SKIPPED',
            count: controller.skipped,
            color: AppColors.mediumColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatChip(
            label: 'PENDING',
            count: controller.pending,
            color: AppColors.primaryColor,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppOpacity.light),
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: AppTypography.titleSemibold.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: AppTypography.labelTiny.copyWith(
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👀', style: TextStyle(fontSize: 36)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Waiting for finishers',
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Entries from Bib Recorder appear here',
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
              title: 'Demo Verifier Session',
              subtitle: 'Connect to the Bib Recorder',
              onTap: onJoin,
            ),
          ],
        ),
      ),
    );
  }
}
