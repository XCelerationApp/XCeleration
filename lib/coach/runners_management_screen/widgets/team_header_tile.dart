import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/shared/models/database/team.dart';
import '../controller/runners_management_controller.dart';

class TeamHeaderTile extends StatelessWidget {
  final Team team;
  final int runnerCount;
  final RunnersManagementController controller;
  final bool isViewMode;

  const TeamHeaderTile({
    super.key,
    required this.team,
    required this.runnerCount,
    required this.controller,
    this.isViewMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color? teamColor = team.color;

    final headerContent = Container(
      decoration: BoxDecoration(
        color: teamColor?.withAlpha((0.12 * 255).round()),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      margin: const EdgeInsets.only(right: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          Icon(
            Icons.school,
            size: 18,
            color: teamColor,
          ),
          const SizedBox(width: 8),
          Text(
            team.name!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: teamColor,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(teamColor!, 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$runnerCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: teamColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (isViewMode) {
      return headerContent;
    }

    return Slidable(
      key: ValueKey('team-${team.teamId}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => controller.showEditTeamSheet(context, team),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
          ),
          SlidableAction(
            onPressed: (_) async {
              await controller.confirmAndDeleteTeam(context, team);
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
          ),
        ],
      ),
      child: headerContent,
    );
  }
}
