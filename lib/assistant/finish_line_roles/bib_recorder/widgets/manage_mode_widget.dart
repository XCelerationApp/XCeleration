import 'package:flutter/material.dart';
import 'package:xceleration/assistant/bib_number_recorder/widgets/runners_loaded_sheet.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/overflow_menu_button.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/confirm_bottom_sheet.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/swipe_bib_row_widget.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/services/device_connection_factory_impl.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_shadows.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Post-race management screen. Shows the entry list for review and editing,
/// and lets the user resume recording, share results, or leave the race.
class ManageModeWidget extends StatelessWidget {
  const ManageModeWidget({super.key, required this.controller});

  final BibRecorderV2Controller controller;

  int get _conflictCount => controller.entries
      .where((e) =>
          controller.flagFor(e.bib, excludeId: e.id) != null)
      .length;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasConflicts = _conflictCount > 0;

        return ColoredBox(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHeader(hasConflicts),
                _buildShareButton(context),
                Expanded(child: _buildList()),
                _buildBottomBar(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool hasConflicts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.selectedRace?.name ?? '',
                style: AppTypography.smallBodySemibold.copyWith(
                  color: AppColors.darkColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (hasConflicts) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '⚠ $_conflictCount',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: GestureDetector(
        onTap: () => _onShareTap(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryColor, AppColors.primaryGradientEnd],
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            boxShadow: AppShadows.high,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Share Bibs',
                style: AppTypography.smallBodySemibold.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (controller.entries.isEmpty) {
      return Center(
        child: Text(
          'No records',
          style: AppTypography.smallBodyRegular.copyWith(
            color: AppColors.lightColor,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: controller.entries.length,
      itemBuilder: (_, i) {
        final entry = controller.entries[i];
        return SwipeBibRowWidget(
          key: ValueKey(entry.id),
          entry: entry,
          position: i + 1,
          controller: controller,
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
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
            child: _ResumeButton(onTap: controller.resumeRace),
          ),
          const SizedBox(width: AppSpacing.sm),
          OverflowMenuButton(
            items: [
              OverflowMenuItem(
                label: 'View Runners',
                onTap: () => sheet(
                  context: context,
                  title: 'Loaded Runners',
                  body: RunnersLoadedSheet(
                    runners: controller.runners
                        .map((r) => BibDatum(
                              bib: r.bibNumber,
                              name: r.name,
                              teamAbbreviation: r.teamAbbreviation,
                              grade: r.grade,
                              teamColor: r.teamColor,
                            ))
                        .toList(),
                  ),
                ),
              ),
              OverflowMenuItem(
                label: 'Clear All Records',
                danger: true,
                onTap: () => _showClearConfirm(context),
              ),
              OverflowMenuItem(
                label: 'Delete Race',
                danger: true,
                onTap: () => _showDeleteConfirm(context),
              ),
              OverflowMenuItem(
                label: 'Leave Race',
                onTap: controller.leaveRace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onShareTap(BuildContext context) async {
    final encodedData = await controller.getEncodedBibData();
    if (!context.mounted) return;
    sheet(
      context: context,
      title: 'Share Bib Numbers',
      body: DeviceConnectionWidget(
        devices: const DeviceConnectionFactoryImpl().createDevices(
          DeviceName.bibRecorder,
          DeviceType.advertiserDevice,
          data: encodedData,
        ),
      ),
    );
  }

  void _showClearConfirm(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmBottomSheet(
        title: 'Clear All Records?',
        message:
            'Permanently deletes all ${controller.entries.length} bib records.',
        confirmLabel: 'Clear All',
        onConfirm: controller.clearEntries,
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmBottomSheet(
        title: 'Delete Race?',
        message:
            'Permanently deletes all ${controller.entries.length} records.',
        confirmLabel: 'Delete',
        onConfirm: controller.deleteRace,
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────


class _ResumeButton extends StatefulWidget {
  const _ResumeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ResumeButton> createState() => _ResumeButtonState();
}

class _ResumeButtonState extends State<_ResumeButton> {
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.statusFinished.withValues(alpha: AppOpacity.medium)
              : AppColors.statusFinished.withValues(alpha: AppOpacity.light),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(color: AppColors.statusFinished),
          boxShadow: [
            BoxShadow(
              color: AppColors.statusFinished.withValues(alpha: AppOpacity.medium),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Resume Recording',
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.statusFinished,
            ),
          ),
        ),
      ),
    );
  }
}

