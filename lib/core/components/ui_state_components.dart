import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/typography.dart';

/// UI state components for different application states
/// This file contains widgets for loading, error, and empty states

/// Reusable loading indicator with consistent styling
class LoadingWidget extends StatelessWidget {
  final String? message;
  final bool isCompact;

  const LoadingWidget({
    super.key,
    this.message,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
          if (message != null) ...[
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              message!,
              style: AppTypography.bodyRegular
                  .copyWith(color: AppColors.mediumColor),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable error widget with consistent styling
class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool isCompact;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16.0 : 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: isCompact ? 48 : 64,
              color: AppColors.redColor,
            ),
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              'Oops! Something went wrong',
              style: isCompact
                  ? AppTypography.titleMedium
                  : AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isCompact ? 8 : 12),
            Text(
              message,
              style: AppTypography.bodyRegular
                  .copyWith(color: AppColors.mediumColor),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: isCompact ? 16 : 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable empty state widget
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool isCompact;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onAction,
    this.actionLabel,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16.0 : 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.inbox,
              size: isCompact ? 48 : 64,
              color: AppColors.mediumColor,
            ),
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              title,
              style: isCompact
                  ? AppTypography.titleMedium
                  : AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: isCompact ? 8 : 12),
              Text(
                subtitle!,
                style: AppTypography.bodyRegular
                    .copyWith(color: AppColors.mediumColor),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              SizedBox(height: isCompact ? 16 : 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
