import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';

/// A dropdown field that manages its own display state via [setState],
/// so callers do not need to pass a [StateSetter].
class AppDropdownField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? error;
  final Function(String) onChanged;
  final List<String> items;

  const AppDropdownField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.items,
    this.error,
  });

  @override
  State<AppDropdownField> createState() => _AppDropdownFieldState();
}

class _AppDropdownFieldState extends State<AppDropdownField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              widget.onChanged(widget.controller.text);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: widget.error != null
                  ? Colors.red.withValues(alpha: AppOpacity.faint)
                  : Colors.grey.withValues(alpha: AppOpacity.faint),
              border: Border.all(
                  color: widget.error != null
                      ? Colors.red.withValues(alpha: AppOpacity.solid)
                      : Colors.grey.withValues(alpha: AppOpacity.solid)),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: DropdownButtonHideUnderline(
              child: ButtonTheme(
                alignedDropdown: true,
                child: DropdownButton<String>(
                  value: widget.controller.text.isEmpty
                      ? null
                      : widget.controller.text,
                  hint: Text(widget.hint,
                      style: const TextStyle(color: Colors.grey)),
                  isExpanded: true,
                  items: widget.items
                      .map((item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => widget.controller.text = value ?? '');
                    widget.onChanged(value ?? '');
                  },
                ),
              ),
            ),
          ),
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.xs, left: AppSpacing.md),
            child: Text(
              widget.error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

Widget buildTextField({
  required BuildContext context,
  required TextEditingController controller,
  required String hint,
  String? error,
  String? warning,
  TextInputType? keyboardType,
  required Function(String) onChanged,
  IconButton? prefixIcon,
  IconButton? suffixIcon,
  VoidCallback? onSuffixIconPressed,
  List<TextInputFormatter>? inputFormatters,
  bool obscureText = false,
  TextAlign textAlign = TextAlign.start,
  int? maxLength,
  bool autofocus = false,
}) {
  // Shared helpers for error/warning state styling — used by border, enabledBorder, and fillColor.
  Color fieldFillColor() => error != null
      ? Colors.red.withValues(alpha: AppOpacity.faint)
      : (warning != null
          ? Colors.orange.withValues(alpha: AppOpacity.light)
          : Colors.grey.withValues(alpha: AppOpacity.faint));

  BorderSide fieldBorderSide() => BorderSide(
        color: error != null
            ? Colors.red.withValues(alpha: AppOpacity.solid)
            : (warning != null
                ? Colors.orange.withValues(alpha: AppOpacity.border)
                : Colors.grey.withValues(alpha: AppOpacity.solid)),
      );

  return Focus(
    onFocusChange: (hasFocus) {
      if (!hasFocus) {
        onChanged(controller.text);
      }
    },
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textAlign: textAlign,
      maxLength: maxLength,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.grey,
          fontSize: 16,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        filled: true,
        fillColor: fieldFillColor(),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: fieldBorderSide(),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: fieldBorderSide(),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: BorderSide(
            color: error != null
                ? Colors.red
                : (warning != null ? Colors.orange : AppColors.primaryColor),
            width: 2,
          ),
        ),
        errorText: error,
        errorStyle: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          height: 1,
        ),
        errorMaxLines: 3,
        helperText: (error == null) ? warning : null,
        helperStyle: const TextStyle(
          color: Colors.orange,
          fontSize: 12,
          height: 1,
        ),
        helperMaxLines: 3,
        counterText: '', // Hide the built-in counter
      ),
      onTapOutside: (_) {
        if (context.mounted) {
          FocusScope.of(context).unfocus();
        }
        onChanged(controller.text);
      },
      onChanged: onChanged,
    ),
  );
}

Widget buildInputRow({
  required String label,
  required Widget inputWidget,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
      inputWidget,
    ],
  );
}
