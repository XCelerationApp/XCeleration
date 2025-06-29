import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';
import 'role_screen.dart';
import '../coach/races_screen/screen/races_screen.dart';
import '../core/components/dialog_utils.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import '../coach/merge_conflicts/screen/mock_data_test_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String currentRole;

  const SettingsScreen({
    super.key,
    required this.currentRole,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole;
  }

  void _changeRole(String role) {
    if (role == _selectedRole) return;
    setState(() {
      _selectedRole = role;
      DialogUtils.showSuccessDialog(context,
          message: 'Role changed successfully');
    });

    if (mounted) {
      if (role == 'coach') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RacesScreen()),
          (route) => false,
        );
      } else if (role == 'assistant') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) =>
                  const AssistantRoleScreen(showBackArrow: false)),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.backgroundColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            children: [
              // Role Selection Section
              _buildSectionHeader('Role'),
              _buildRoleSelection(context),

              // Development Tools Section (only in debug mode)
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('Development Tools'),
                _buildDevelopmentTools(context),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: AppTypography.titleSemibold.copyWith(
          color: AppColors.darkColor,
        ),
      ),
    );
  }

  Widget _buildRoleSelection(BuildContext context) {
    return Column(
      children: [
        _buildRoleItem(
          context,
          'Coach',
          'Manage races and view results',
          Icons.person,
          isSelected: _selectedRole == 'coach',
          onTap: () => _changeRole('coach'),
        ),
        _buildRoleItem(
          context,
          'Assistant',
          'Timer or bib recorder roles',
          Icons.support_agent,
          isSelected: _selectedRole == 'assistant' ||
              _selectedRole == 'timer' ||
              _selectedRole == 'bib recorder',
          onTap: () => _changeRole('assistant'),
        ),
      ],
    );
  }

  Widget _buildDevelopmentTools(BuildContext context) {
    return Column(
      children: [
        _buildRoleItem(
          context,
          'Mock Data Testing',
          'Test conflict resolution with realistic scenarios',
          Icons.science,
          isSelected: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MockDataTestScreen(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleItem(
    BuildContext context,
    String title,
    String description,
    IconData icon, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorUtils.withOpacity(AppColors.primaryColor, 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryColor
                    : ColorUtils.withOpacity(AppColors.primaryColor, 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySemibold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.mediumColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primaryColor,
                size: 24,
              )
            else
              Icon(
                Icons.circle_outlined,
                color: AppColors.mediumColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
