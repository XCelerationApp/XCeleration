import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../mock/conflict_mock_data.dart';
import '../../../core/components/button_components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/sheet_utils.dart';
import './mock_create_runner_sheet.dart';

/// Shared resolution list used by both DuplicateStep2Card and UnknownBibCard.
/// Shows unassigned runners with search, plus a "Create New Runner" option.
class RunnerAssignmentList extends StatefulWidget {
  const RunnerAssignmentList({
    super.key,
    required this.targetBib,

    /// For the duplicate case: the bib that cannot be reused for a new runner.
    this.forbiddenBib,
  });

  final int targetBib;
  final int? forbiddenBib;

  @override
  State<RunnerAssignmentList> createState() => _RunnerAssignmentListState();
}

class _RunnerAssignmentListState extends State<RunnerAssignmentList> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MockRunner> _filter(List<MockRunner> runners) {
    if (_query.isEmpty) return runners;
    return runners.where((r) {
      return r.name.toLowerCase().contains(_query) ||
          r.bibNumber.toString().contains(_query) ||
          r.team.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();
    final nearbyRunners = controller.runnersNearBib(widget.targetBib);
    final filtered = _filter(nearbyRunners);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchField(controller: _searchController),
        const SizedBox(height: AppSpacing.sm),
        if (nearbyRunners.isEmpty)
          _EmptyRunnerList(hasRunners: false)
        else if (filtered.isEmpty)
          _EmptyRunnerList(hasRunners: true)
        else
          ...filtered.asMap().entries.map(
                (e) => _AnimatedRunnerRow(
                  index: e.key,
                  runner: e.value,
                  onTap: () => controller.assignRunner(e.value),
                ),
              ),
        const SizedBox(height: AppSpacing.lg),
        _OrDivider(),
        const SizedBox(height: AppSpacing.lg),
        SecondaryButton(
          text: 'Create New Runner',
          icon: Icons.person_add_outlined,
          size: ButtonSize.fullWidth,
          onPressed: () => _openCreateSheet(context, controller),
        ),
      ],
    );
  }

  Future<void> _openCreateSheet(
    BuildContext context,
    ConflictResolutionController controller,
  ) async {
    await sheet(
      context: context,
      title: 'Add New Runner',
      body: MockCreateRunnerSheet(
        forbiddenBib: widget.forbiddenBib,
        allKnownBibs: controller.allKnownBibs,
        onCreated: (name, bib, team, grade) {
          controller.createNewRunner(name, bib, team: team, grade: grade);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTypography.bodyRegular,
      decoration: InputDecoration(
        hintText: 'Search by name, bib, or team…',
        hintStyle: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        prefixIcon: const Icon(Icons.search, color: AppColors.mediumColor, size: 20),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  color: AppColors.mediumColor,
                  onPressed: controller.clear,
                ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        filled: true,
        fillColor: AppColors.lightColor.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _EmptyRunnerList extends StatelessWidget {
  const _EmptyRunnerList({required this.hasRunners});

  final bool hasRunners;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(
          hasRunners
              ? 'No runners match your search.'
              : 'No unassigned runners left — create a new one below.',
          style: AppTypography.smallBodyRegular.copyWith(
            color: AppColors.mediumColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _AnimatedRunnerRow extends StatefulWidget {
  const _AnimatedRunnerRow({
    required this.index,
    required this.runner,
    required this.onTap,
  });

  final int index;
  final MockRunner runner;
  final VoidCallback onTap;

  @override
  State<_AnimatedRunnerRow> createState() => _AnimatedRunnerRowState();
}

class _AnimatedRunnerRowState extends State<_AnimatedRunnerRow> {
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
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                _BibChip(bibNumber: widget.runner.bibNumber),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.runner.name, style: AppTypography.bodyRegular),
                      const SizedBox(height: 2),
                      Text(
                        widget.runner.team,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.mediumColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BibChip extends StatelessWidget {
  const _BibChip({required this.bibNumber});

  final int bibNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
      ),
      child: Text(
        '#$bibNumber',
        style: AppTypography.captionBold.copyWith(
          color: AppColors.primaryColor,
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'or',
            style: AppTypography.caption.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
