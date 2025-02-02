import 'package:flutter/material.dart';
import 'package:race_timing_app/screens/races_screen.dart';
import 'package:race_timing_app/screens/timing_screen.dart';
import 'package:race_timing_app/screens/bib_number_screen.dart';
import 'package:race_timing_app/utils/app_colors.dart';
import 'utils/sheet_utils.dart';

class RoleOption {
  final String value;
  final String title;
  final String description;
  final IconData icon;
  final Widget screen;

  const RoleOption({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
    required this.screen,
  });
}

final List<RoleOption> roleOptions = [
  RoleOption(
    value: 'coach',
    title: 'Coach',
    description: 'Manage races',
    icon: Icons.person_outlined,
    screen: const RacesScreen(),
  ),
  RoleOption(
    value: 'timer',
    title: 'Timer',
    description: 'Time a race',
    icon: Icons.timer,
    screen: const TimingScreen(),
  ),
  RoleOption(
    value: 'bib recorder',
    title: 'Bib Recorder',
    description: 'Record bib numbers',
    icon: Icons.numbers,
    screen: const BibNumberScreen(),
  ),
];

Widget _buildRoleTitle(RoleOption role, String currentRole) {
  return Row(
    children: [
      Icon(role.icon, size: 55, color: role.value == currentRole
                  ? AppColors.selectedRoleTextColor
                  : AppColors.unselectedRoleTextColor),
      SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: role.value == currentRole
                  ? AppColors.selectedRoleTextColor
                  : AppColors.unselectedRoleTextColor,
            ),
          ),
          Text(
            role.description,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: role.value == currentRole
                    ? AppColors.selectedRoleTextColor
                    : AppColors.unselectedRoleTextColor),
          ),
        ],
      ),
    ],
  );
}

Widget _buildRoleListTile(BuildContext context, RoleOption role, String currentRole) {
  return Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: RadioListTile<String>(
      value: role.value,
      groupValue: currentRole,
      onChanged: (value) {
        Navigator.pop(context);
        if (value == currentRole) return;
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => role.screen,
          ),
        );
      },
      controlAffinity: ListTileControlAffinity.trailing,
      tileColor: currentRole == role.value
          ? AppColors.selectedRoleColor
          : AppColors.unselectedRoleColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: _buildRoleTitle(role, currentRole),
      activeColor: AppColors.selectedRoleTextColor,
      // fillColor: WidgetStateProperty.resolveWith<Color>(
      //   (Set<WidgetState> states) {
      //     if (states.contains(WidgetState.selected)) {
      //       return AppColors.selectedRoleTextColor;
      //     }
      //     return Colors.white; // unselected color
      //   },
      // ),
    ),
  );
}

void changeRole(BuildContext context, String currentRole) {
  showModalBottomSheet(
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    context: context,
    builder: (context) => Container(
      height: 400,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            createSheetHandle(),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Change Role',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkColor,
                ),
              ),
            ),
            ...roleOptions.map((role) => _buildRoleListTile(context, role, currentRole)),
          ],
        ),
      ),
    ),
  );
}

Widget buildRoleBar(BuildContext context, String currentRole, String title) {
  return Container(
    padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          width: 1,
          color: AppColors.darkColor,
        ),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: EdgeInsets.only(right: 10),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: AppColors.navBarColor,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => changeRole(context, currentRole),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.unselectedRoleColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          ),
          child: Text(
            'Role: ${currentRole[0].toUpperCase()}${currentRole.substring(1)}',
            style: TextStyle(color: AppColors.navBarTextColor),
          ),
        ),
      ],
    ),
  );
}