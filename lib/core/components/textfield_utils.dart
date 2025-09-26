import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

Widget buildDropdown({
  required TextEditingController controller,
  required String hint,
  String? error,
  required Function(String) onChanged,
  required StateSetter setSheetState,
  required List<String> items,
}) {
  const double borderRadius = 12.0;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            onChanged(controller.text);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: error != null
                ? Colors.red.withAlpha((0.05 * 255).round())
                : Colors.grey.withAlpha((0.05 * 255).round()),
            border: Border.all(
                color: error != null
                    ? Colors.red.withAlpha((0.5 * 255).round())
                    : Colors.grey.withAlpha((0.5 * 255).round())),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<String>(
                value: (controller.text.isEmpty ? null : controller.text),
                hint: Text(hint, style: const TextStyle(color: Colors.grey)),
                isExpanded: true,
                items: [
                  ...items.map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      )),
                ],
                onChanged: (value) {
                  setSheetState(() => controller.text = value ?? '');
                  onChanged(value ?? '');
                },
              ),
            ),
          ),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 12),
          child: Text(
            error,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ),
    ],
  );
}

Widget buildTextField({
  required BuildContext context,
  required TextEditingController controller,
  required String hint,
  String? error,
  String? warning,
  TextInputType? keyboardType,
  required Function(String) onChanged,
  required StateSetter setSheetState,
  IconButton? prefixIcon,
  IconButton? suffixIcon,
  VoidCallback? onSuffixIconPressed,
  List<TextInputFormatter>? inputFormatters,
  bool obscureText = false,
  TextAlign textAlign = TextAlign.start,
  int? maxLength,
  bool autofocus = false,
}) {
  const double borderRadius = 12.0;
  const double contentPadding = 16.0;

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
          horizontal: contentPadding,
          vertical: contentPadding,
        ),
        filled: true,
        fillColor: error != null
            ? Colors.red.withAlpha((0.05 * 255).round())
            : (warning != null
                ? Colors.orange.withAlpha((0.08 * 255).round())
                : Colors.grey.withAlpha((0.05 * 255).round())),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(
            color: error != null
                ? Colors.red.withAlpha((0.5 * 255).round())
                : (warning != null
                    ? Colors.orange.withAlpha((0.6 * 255).round())
                    : Colors.grey.withAlpha((0.5 * 255).round())),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(
            color: error != null
                ? Colors.red.withAlpha((0.5 * 255).round())
                : (warning != null
                    ? Colors.orange.withAlpha((0.6 * 255).round())
                    : Colors.grey.withAlpha((0.5 * 255).round())),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
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
        padding: const EdgeInsets.only(bottom: 8),
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
