import 'package:flutter/material.dart';
import 'typography.dart';
import 'app_colors.dart';
import 'enums.dart';

class FlowStepContent extends StatelessWidget {
  final String title;
  final String description;
  final Widget content;
  final int currentStep;
  final int totalSteps;

  const FlowStepContent({
    Key? key,
    required this.title,
    required this.description,
    required this.content,
    required this.currentStep,
    required this.totalSteps,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress indicator at the top
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: List.generate(totalSteps, (index) {
              final isActive = index <= currentStep;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primaryColor : AppColors.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        // Title and description
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleSemibold,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: AppTypography.bodyRegular,
              ),
            ],
          ),
        ),
        // Main content
        Expanded(child: content),
      ],
    );
  }
}

class SearchableButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final ConnectionStatus? connectionStatus;
  final bool showSearchingText;
  final bool isQrCode;

  const SearchableButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon = Icons.person,
    this.connectionStatus,
    this.showSearchingText = true,
    this.isQrCode = false,
  });

  @override
  State<SearchableButton> createState() => _SearchableButtonState();
}

class _SearchableButtonState extends State<SearchableButton> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.isQrCode || widget.connectionStatus != ConnectionStatus.searching ? widget.onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                widget.icon ?? Icons.person,
                color: Colors.black54,
                size: 24,
              ),
              if (widget.isQrCode) ...[
                Expanded(
                  child: Center(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 16),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                ),
                if (widget.showSearchingText && widget.connectionStatus == ConnectionStatus.searching) ...[
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Searching',
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FlowActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isEnabled;

  const FlowActionButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5722),
          disabledBackgroundColor: const Color(0xFFFF5722).withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          label,
          style: AppTypography.bodySemibold.copyWith(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
