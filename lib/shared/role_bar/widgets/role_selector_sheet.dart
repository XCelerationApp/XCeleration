import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import '../models/role_enums.dart';
import '../../../core/components/page_route_animations.dart';
import '../../../core/services/auth_service.dart';
import '../../role_screen.dart';

/// Sheet for selecting roles or profiles
class RoleSelectorSheet {
  /// Show a sheet for selecting assistant roles
  static Future<void> showRoleSelection(
    BuildContext context,
    Role currentRole,
  ) async {
    final newRole = await _showRoleSheet(
      context: context,
      currentValue: currentRole,
    );

    if (newRole == null || newRole == currentRole) return;
    if (!context.mounted) return;

    _navigateToRoleScreen(context, newRole);
  }

  static Future<Role?> _showRoleSheet({
    required BuildContext context,
    required Role currentValue,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showModalBottomSheet<Role>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => _RoleSelectorSheetContent(
        roles: Role.values.toList(),
        currentValue: currentValue,
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    return result;
  }

  static void _navigateToRoleScreen(BuildContext context, Role role) {
    if (role == Role.coach || role == Role.spectator) {
      if (!AuthService.instance.isSignedIn) {
        Navigator.of(context).push(
          RolePageRouteAnimation(child: const RoleScreen()),
        );
        return;
      }
    }
    Navigator.of(context).pushAndRemoveUntil(
      RolePageRouteAnimation(child: role.screen),
      (route) => false,
    );
  }
}

// ── Sheet content ────────────────────────────────────────────────────────────

class _RoleSelectorSheetContent extends StatelessWidget {
  const _RoleSelectorSheetContent({
    required this.roles,
    required this.currentValue,
  });

  final List<Role> roles;
  final Role currentValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            const _SheetHeader(),
            _SheetDivider(),
            _RoleCardList(
              roles: roles,
              currentRole: currentValue,
              onRoleSelected: (role) {
                if (role != currentValue) Navigator.of(context).pop(role);
              },
            ),
            if (currentValue == Role.coach) const _SignOutButton(),
          ],
        ),
      ),
    );
  }
}

// ── Handle ───────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.lightColor,
            borderRadius: BorderRadius.circular(AppBorderRadius.full),
          ),
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select New Role', style: AppTypography.titleSemibold),
          const SizedBox(height: 2),
          Text(
            "Choose how you'll participate in this race",
            style: AppTypography.caption.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Divider ──────────────────────────────────────────────────────────────────

class _SheetDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.lightColor,
      margin: const EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: AppSpacing.lg,
      ),
    );
  }
}

// ── Role card list ────────────────────────────────────────────────────────────

class _RoleCardList extends StatelessWidget {
  const _RoleCardList({
    required this.roles,
    required this.currentRole,
    required this.onRoleSelected,
  });

  final List<Role> roles;
  final Role currentRole;
  final ValueChanged<Role> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          for (int i = 0; i < roles.length; i++) ...[
            _StaggeredItem(
              index: i,
              child: _RoleCard(
                role: roles[i],
                isSelected: roles[i] == currentRole,
                onTap: () => onRoleSelected(roles[i]),
              ),
            ),
            if (i < roles.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

// ── Stagger wrapper ───────────────────────────────────────────────────────────

class _StaggeredItem extends StatefulWidget {
  const _StaggeredItem({required this.child, required this.index});

  final Widget child;
  final int index;

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 35), () {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: AppAnimations.reveal,
      curve: AppAnimations.enter,
      child: widget.child,
    );
  }
}

// ── Role card ────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  final Role role;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: AppAnimations.fast,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          curve: AppAnimations.spring,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.selectedRoleColor
                : AppColors.unselectedRoleColor,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primaryColor.withValues(alpha: AppOpacity.strong)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _RoleIconWrap(
                  role: widget.role, isSelected: widget.isSelected),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _RoleText(
                    role: widget.role, isSelected: widget.isSelected),
              ),
              _CheckBadge(isSelected: widget.isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role icon wrap ────────────────────────────────────────────────────────────

class _RoleIconWrap extends StatelessWidget {
  const _RoleIconWrap({required this.role, required this.isSelected});

  final Role role;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppAnimations.fast,
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryColor.withValues(alpha: AppOpacity.light)
            : AppColors.mediumColor.withValues(alpha: AppOpacity.faint),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Icon(
        role.icon,
        size: 18,
        color: isSelected ? AppColors.primaryColor : AppColors.mediumColor,
      ),
    );
  }
}

// ── Role text ────────────────────────────────────────────────────────────────

class _RoleText extends StatelessWidget {
  const _RoleText({required this.role, required this.isSelected});

  final Role role;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          role.displayName,
          style: AppTypography.bodySemibold.copyWith(
            color:
                isSelected ? AppColors.primaryColor : AppColors.darkColor,
          ),
        ),
        Text(
          role.description,
          style: AppTypography.caption.copyWith(
            color: AppColors.mediumColor,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

// ── Check badge ──────────────────────────────────────────────────────────────

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.0 : 0.7,
      duration: AppAnimations.fast,
      child: AnimatedOpacity(
        opacity: isSelected ? 1.0 : 0.0,
        duration: AppAnimations.fast,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.primaryColor,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 11),
        ),
      ),
    );
  }
}

// ── Sign out button ───────────────────────────────────────────────────────────

class _SignOutButton extends StatefulWidget {
  const _SignOutButton();

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Center(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () async {
            await AuthService.instance.signOut();
            if (!context.mounted) return;
            Navigator.of(context).pop();
            Navigator.of(context).pushAndRemoveUntil(
              RolePageRouteAnimation(child: const RoleScreen()),
              (route) => false,
            );
          },
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: _pressed
                  ? AppColors.redColor.withValues(alpha: AppOpacity.faint)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout,
                  size: 14,
                  color: AppColors.mediumColor,
                ),
                const SizedBox(width: 5),
                Text(
                  'Sign out',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.mediumColor,
                    fontWeight: FontWeight.w600,
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
