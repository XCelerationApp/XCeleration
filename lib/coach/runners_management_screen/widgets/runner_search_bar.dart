import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class RunnerSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchAttribute;
  final Function() onSearchChanged;
  final Function(String?) onAttributeChanged;
  final VoidCallback? onDeleteAll;
  final bool isViewMode;

  const RunnerSearchBar({
    super.key,
    required this.controller,
    required this.searchAttribute,
    required this.onSearchChanged,
    required this.onAttributeChanged,
    this.onDeleteAll,
    this.isViewMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 3,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtils.withOpacity(Colors.black, 0.05),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(
                          color: ColorUtils.withOpacity(
                              AppColors.mediumColor, 0.7)),
                      prefixIcon: Icon(Icons.search,
                          color: ColorUtils.withOpacity(
                              AppColors.primaryColor, 0.8)),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.lightColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: AppColors.primaryColor, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.lightColor),
                      ),
                    ),
                    onChanged: (_) => onSearchChanged(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 2,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtils.withOpacity(Colors.black, 0.05),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                    border: Border.all(color: AppColors.lightColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: searchAttribute,
                        onChanged: onAttributeChanged,
                        items: ['Bib Number', 'Name', 'Grade', 'Team']
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      color: AppColors.darkColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ))
                            .toList(),
                        icon: const Icon(Icons.arrow_drop_down,
                            color: AppColors.navBarColor),
                        iconSize: 30,
                        isExpanded: true,
                        focusColor: AppColors.backgroundColor,
                        style:
                            TextStyle(color: AppColors.darkColor, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (!isViewMode)
                SizedBox(
                  height: 48,
                  width: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: ColorUtils.withOpacity(Colors.black, 0.05),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                      border: Border.all(color: AppColors.lightColor),
                    ),
                    child: IconButton(
                      icon:
                          Icon(Icons.delete_outline, color: AppColors.redColor),
                      // tooltip: 'Delete All Runners',
                      onPressed: onDeleteAll,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
