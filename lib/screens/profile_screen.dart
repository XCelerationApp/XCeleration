import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
import '../utils/typography.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AppTypography.titleSemibold.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Personal Information',
            [
              _buildInfoTile('Name', 'John Doe'),
              _buildInfoTile('Email', 'john.doe@example.com'),
              _buildInfoTile('Role', 'Coach'),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Preferences',
            [
              _buildSwitchTile('Dark Mode', true),
              _buildSwitchTile('Notifications', true),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            child: Text(
              'Sign Out',
              style: AppTypography.bodySemibold.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.titleSemibold,
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: AppTypography.bodySemibold,
          ),
          Text(
            value,
            style: AppTypography.bodyRegular,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String label, bool value) {
    return SwitchListTile(
      title: Text(
        label,
        style: AppTypography.bodyRegular,
      ),
      value: value,
      onChanged: (bool value) {},
    );
  }
}
