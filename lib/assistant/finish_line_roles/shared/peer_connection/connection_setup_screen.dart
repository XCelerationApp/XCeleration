import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

/// Shown after race / session selection, before entering active race mode.
///
/// Displays live peer discovery status for the two peers this role connects to.
/// Calls [onReady] when the user taps Start (at least one peer connected),
/// [onSkip] to start fully offline, or [onLeave] to go back.
class ConnectionSetupScreen extends StatelessWidget {
  const ConnectionSetupScreen({
    super.key,
    required this.role,
    required this.raceId,
    required this.raceName,
    required this.notifier,
    required this.onReady,
    required this.onSkip,
    required this.onLeave,
  });

  final Role role;
  final int raceId;
  final String raceName;

  /// The caller owns this notifier's lifecycle — [ConnectionSetupScreen] will
  /// not dispose it. Pass the same notifier that will be kept alive as the
  /// [PeerStatusStrip] source after the race starts.
  final PeerDiscoveryNotifier notifier;

  final VoidCallback onReady;
  final VoidCallback onSkip;
  final VoidCallback onLeave;

  String get _raceCode {
    final s = raceId.toString().padLeft(4, '0');
    return s.length > 4 ? s.substring(s.length - 4) : s;
  }

  @override
  Widget build(BuildContext context) {
    final peers = kPeerConfig[role] ?? [];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _BackButton(onTap: onLeave),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RaceHeader(
                      raceName: raceName,
                      raceCode: _raceCode,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    ListenableBuilder(
                      listenable: notifier,
                      builder: (_, _) => Column(
                        children: peers
                            .map((p) => _PeerCard(
                                  config: p,
                                  status: notifier.statusFor(p.role),
                                  deviceName: notifier.deviceNameFor(p.role),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _HintBox(raceName: raceName),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
            _BottomActions(
              notifier: notifier,
              onReady: onReady,
              onSkip: onSkip,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: onTap,
          child: Text(
            '‹ Back',
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Race header ───────────────────────────────────────────────────────────────

class _RaceHeader extends StatelessWidget {
  const _RaceHeader({required this.raceName, required this.raceCode});

  final String raceName;
  final String raceCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          raceName,
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.darkColor,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'CONNECTING TO PEERS',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.mediumColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(
              'Race ID',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
              child: Text(
                '#$raceCode',
                style: AppTypography.smallBodySemibold.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                  color: AppColors.darkColor,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '· auto-discovering',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Hint box ──────────────────────────────────────────────────────────────────

class _HintBox extends StatelessWidget {
  const _HintBox({required this.raceName});

  final String raceName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: RichText(
        text: TextSpan(
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.mediumColor,
            height: 1.5,
          ),
          children: [
            const TextSpan(
              text: 'Devices connect automatically when they share '
                  'the same race. Make sure all devices have ',
            ),
            TextSpan(
              text: raceName,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.darkColor,
              ),
            ),
            const TextSpan(text: ' loaded.'),
          ],
        ),
      ),
    );
  }
}

// ── Bottom actions ────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.notifier,
    required this.onReady,
    required this.onSkip,
  });

  final PeerDiscoveryNotifier notifier;
  final VoidCallback onReady;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: ListenableBuilder(
        listenable: notifier,
        builder: (_, _) {
          final anyConn = notifier.anyConnected;
          final allConn = notifier.allConnected;
          final btnLabel = allConn
              ? 'All peers connected — Start →'
              : anyConn
                  ? 'Start with partial connection →'
                  : 'Waiting for peers…';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PrimaryButton(
                label: btnLabel,
                enabled: anyConn,
                onTap: anyConn ? onReady : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _OfflineButton(onTap: onSkip),
            ],
          );
        },
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.standard,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.primaryColor, AppColors.primaryGradientEnd],
                )
              : null,
          color: enabled ? null : AppColors.borderColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primaryColor
                        .withValues(alpha: AppOpacity.strong),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.smallBodySemibold.copyWith(
              color: enabled ? Colors.white : AppColors.mediumColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineButton extends StatelessWidget {
  const _OfflineButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Center(
          child: Text(
            'Start offline — record locally',
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Peer card ─────────────────────────────────────────────────────────────────

class _PeerCard extends StatelessWidget {
  const _PeerCard({
    required this.config,
    required this.status,
    this.deviceName,
  });

  final PeerConfig config;
  final PeerStatus status;
  final String? deviceName;

  Color get _borderColor => switch (status) {
        PeerStatus.connected =>
          AppColors.statusFinished.withValues(alpha: AppOpacity.solid),
        PeerStatus.found =>
          AppColors.statusSetup.withValues(alpha: AppOpacity.solid),
        _ => AppColors.borderColor,
      };

  Color get _bgColor => switch (status) {
        PeerStatus.connected =>
          AppColors.statusFinished.withValues(alpha: AppOpacity.faint),
        PeerStatus.found =>
          AppColors.statusSetup.withValues(alpha: AppOpacity.faint),
        _ => AppColors.surfaceColor,
      };

  @override
  Widget build(BuildContext context) {
    final isConn = status == PeerStatus.connected;
    final isFound = status == PeerStatus.found;
    final showDevice = isConn || isFound;

    return AnimatedContainer(
      duration: AppAnimations.standard,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.label,
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: AppColors.darkColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    config.direction.label,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.lightColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (isConn || isFound) _StatusDot(status: status) else _SpinnerRow(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: AppAnimations.standard,
            child: Align(
              key: ValueKey(showDevice),
              alignment: Alignment.centerLeft,
              child: Text(
                showDevice
                    ? '📱 ${deviceName ?? "Unknown device"}'
                    : 'Waiting for device…',
                style: AppTypography.bodySmall.copyWith(
                  color: isConn ? const Color(0xFF444444) : AppColors.lightColor,
                  fontWeight:
                      isConn ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final PeerStatus status;

  Color get _color => status == PeerStatus.connected
      ? AppColors.statusFinished
      : AppColors.statusSetup;

  String get _label =>
      status == PeerStatus.connected ? 'Connected' : 'Found';

  @override
  Widget build(BuildContext context) {
    final isConn = status == PeerStatus.connected;
    return Row(
      children: [
        AnimatedContainer(
          duration: AppAnimations.standard,
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: isConn
                ? [
                    BoxShadow(
                      color: AppColors.statusFinished
                          .withValues(alpha: AppOpacity.strong),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          _label,
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
      ],
    );
  }
}

// ── Spinner row ───────────────────────────────────────────────────────────────

class _SpinnerRow extends StatefulWidget {
  @override
  State<_SpinnerRow> createState() => _SpinnerRowState();
}

class _SpinnerRowState extends State<_SpinnerRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RotationTransition(
          turns: _ctrl,
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              backgroundColor: AppColors.borderColor,
              color: AppColors.mediumColor.withValues(alpha: AppOpacity.solid),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Searching…',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.lightColor,
          ),
        ),
      ],
    );
  }
}
