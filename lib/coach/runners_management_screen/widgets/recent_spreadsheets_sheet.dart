import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/date_format_utils.dart';
import 'package:xceleration/core/utils/google_drive_service.dart';
import 'package:xceleration/core/utils/google_sheets_service.dart';
import 'package:xceleration/core/utils/recent_drive_selection_service.dart';
import 'package:xceleration/core/utils/recent_local_spreadsheet_service.dart';

/// Shows previously-selected spreadsheets (Google Drive picks stored locally
/// + locally-picked files). Pops with a [File] when the user taps an entry,
/// or with [null] if nothing is selected.
class RecentSpreadsheetsSheet extends StatefulWidget {
  const RecentSpreadsheetsSheet({super.key});

  @override
  State<RecentSpreadsheetsSheet> createState() =>
      _RecentSpreadsheetsSheetState();
}

class _RecentSpreadsheetsSheetState extends State<RecentSpreadsheetsSheet> {
  bool _loading = true;
  List<RecentDriveSelection> _driveFiles = [];
  List<RecentLocalFile> _localFiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      RecentDriveSelectionService.instance.getRecents(),
      RecentLocalSpreadsheetService.instance.getRecents(),
    ]);
    if (mounted) {
      setState(() {
        _driveFiles = results[0] as List<RecentDriveSelection>;
        _localFiles = results[1] as List<RecentLocalFile>;
        _loading = false;
      });
    }
  }

  Future<void> _onDriveFileTap(RecentDriveSelection entry) async {
    if (!mounted) return;

    final result = await DialogUtils.executeWithLoadingDialog<File?>(
      context,
      loadingMessage: 'Downloading ${entry.name}...',
      operation: () async {
        if (entry.mimeType == 'application/vnd.google-apps.spreadsheet') {
          return GoogleSheetsService.instance.downloadGoogleSheet(
            fileId: entry.fileId,
            fileName: entry.name,
          );
        }
        return GoogleDriveService.instance.downloadFile(
            entry.fileId, entry.name);
      },
      allowCancel: true,
    );

    if (!mounted) return;
    if (result == null) {
      DialogUtils.showErrorDialog(
        context,
        message:
            'Could not download "${entry.name}". Your session may have expired — try selecting it via "Select from Google Drive" to refresh access.',
      );
      return;
    }
    Navigator.pop(context, result);
  }

  Future<void> _onLocalFileTap(RecentLocalFile entry) async {
    final file = File(entry.path);
    if (!await file.exists()) {
      if (!mounted) return;
      DialogUtils.showErrorDialog(
        context,
        message:
            '"${entry.name}" is no longer available at its original location. Please re-select it via "Select from Local Files".',
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, file);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_driveFiles.isEmpty && _localFiles.isEmpty)
          _EmptyState()
        else ...[
          if (_driveFiles.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.cloud_outlined,
              label: 'Google Drive',
            ),
            ..._driveFiles.asMap().entries.map(
                  (e) => _AnimatedEntry(
                    index: e.key,
                    child: _FileRow(
                      name: e.value.name,
                      subtitle: _selectionSubtitle(e.value.selectedAt),
                      icon: _driveIcon(e.value.mimeType),
                      iconColor: AppColors.primaryColor,
                      onTap: () => _onDriveFileTap(e.value),
                    ),
                  ),
                ),
          ],
          if (_localFiles.isNotEmpty) ...[
            if (_driveFiles.isNotEmpty)
              const Divider(height: AppSpacing.lg, indent: AppSpacing.lg),
            _SectionHeader(
              icon: Icons.folder_outlined,
              label: 'Local Files',
            ),
            ..._localFiles.asMap().entries.map(
                  (e) => _AnimatedEntry(
                    index: _driveFiles.length + e.key,
                    child: _FileRow(
                      name: e.value.name,
                      subtitle: _selectionSubtitle(e.value.lastUsed),
                      icon: Icons.insert_drive_file_outlined,
                      iconColor: AppColors.mediumColor,
                      onTap: () => _onLocalFileTap(e.value),
                    ),
                  ),
                ),
          ],
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  String _selectionSubtitle(DateTime selectedAt) {
    return 'Selected ${DateFormatUtils.formatRelativeDate(selectedAt).toLowerCase()}';
  }

  IconData _driveIcon(String mimeType) {
    if (mimeType == 'application/vnd.google-apps.spreadsheet') {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history, size: 40, color: AppColors.lightColor),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No previously selected spreadsheets',
              style:
                  AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Files you import will appear here.',
              style:
                  AppTypography.caption.copyWith(color: AppColors.mediumColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.mediumColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.mediumColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _FileRow({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOutCubic,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: AppOpacity.light),
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
              child: Icon(widget.icon, size: 18, color: widget.iconColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: AppTypography.bodyRegular,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.mediumColor),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.mediumColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedEntry extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedEntry({required this.index, required this.child});

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: widget.child,
    );
  }
}
