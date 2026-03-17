import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/fixer_entry_card.dart';
import 'package:xceleration/core/components/app_header.dart';
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/overflow_menu_button.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = FixerController();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
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
                  return _RaceLobby(controller: _controller);
                }
                return Column(
                  children: [
                    Expanded(
                      child: _controller.queue.isEmpty
                          ? const _EmptyState()
                          : _FixerQueue(controller: _controller),
                    ),
                    _BottomBar(controller: _controller),
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
        color: pillColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: pillColor.withValues(alpha: 0.25)),
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
        style: AppTypography.bodySmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
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

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatefulWidget {
  const _BottomBar({required this.controller});

  final FixerController controller;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.controller.leaveRace,
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: _pressed
                      ? AppColors.redColor.withValues(alpha: AppOpacity.light)
                      : AppColors.redColor.withValues(alpha: AppOpacity.faint),
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  border: Border.all(
                    color: AppColors.redColor.withValues(alpha: AppOpacity.strong),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Leave Race',
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: AppColors.redColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OverflowMenuButton(
            items: [
              OverflowMenuItem(
                label: 'Leave Race',
                onTap: widget.controller.leaveRace,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Race lobby ────────────────────────────────────────────────────────────────

class _RaceLobby extends StatelessWidget {
  const _RaceLobby({required this.controller});

  final FixerController controller;

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
            _LobbySectionLabel(label: 'Available'),
            const SizedBox(height: AppSpacing.sm),
            _LobbySessionCard(
              title: 'Demo Fixer Session',
              subtitle: 'Connect to the Verifier',
              onTap: controller.joinRace,
            ),
          ],
        ),
      ),
    );
  }
}

class _LobbySectionLabel extends StatelessWidget {
  const _LobbySectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.mediumColor,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _LobbySessionCard extends StatefulWidget {
  const _LobbySessionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_LobbySessionCard> createState() => _LobbySessionCardState();
}

class _LobbySessionCardState extends State<_LobbySessionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
                    widget.title,
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: AppColors.darkColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.subtitle,
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
                color: AppColors.primaryColor.withValues(alpha: AppOpacity.faint),
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
                border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: AppOpacity.strong),
                ),
              ),
              child: Text(
                'Join',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
