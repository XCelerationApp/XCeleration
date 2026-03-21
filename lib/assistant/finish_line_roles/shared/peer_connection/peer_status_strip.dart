import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/peer_discovery_notifier.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Compact pill row shown at the top of active-race screens.
///
/// Displays a live status pill for each peer the role connects to.
/// Pass the [PeerDiscoveryNotifier] kept alive by the parent screen state.
class PeerStatusStrip extends StatelessWidget {
  const PeerStatusStrip({super.key, required this.notifier});

  final PeerDiscoveryNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (_, __) {
        final peers = kPeerConfig[notifier.role] ?? [];
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Row(
            children: peers.map((peer) {
              final status = notifier.statusFor(peer.role);
              final isConn = status == PeerStatus.connected;
              final dotColor = isConn
                  ? AppColors.statusFinished
                  : status == PeerStatus.found
                      ? AppColors.statusSetup
                      : AppColors.lightColor;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: AnimatedContainer(
                  duration: AppAnimations.standard,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isConn
                        ? AppColors.statusFinished
                            .withValues(alpha: AppOpacity.light)
                        : AppColors.surfaceColor,
                    borderRadius: BorderRadius.circular(AppBorderRadius.full),
                    border: Border.all(
                      color: isConn
                          ? AppColors.statusFinished
                              .withValues(alpha: AppOpacity.medium)
                          : AppColors.borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: AppAnimations.standard,
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          boxShadow: isConn
                              ? [
                                  BoxShadow(
                                    color: AppColors.statusFinished
                                        .withValues(alpha: AppOpacity.strong),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        peer.label,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isConn
                              ? AppColors.statusFinished
                              : AppColors.lightColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
