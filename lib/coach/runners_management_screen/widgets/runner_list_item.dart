import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/material.dart';
import '../../../shared/models/database/runner.dart';
import '../../../shared/models/database/team.dart';
import '../controller/runners_management_controller.dart';

class RunnerListItem extends StatelessWidget {
  final Runner runner;
  final Team team;
  final Function(String) onAction;
  final RunnersManagementController controller;
  final bool isViewMode;

  const RunnerListItem({
    super.key,
    required this.runner,
    required this.team,
    required this.onAction,
    required this.controller,
    this.isViewMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final bibColor = team.color;

    Widget runnerRow = Container(
      decoration: BoxDecoration(
        color: bibColor!.withAlpha((0.1 * 255).round()),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Text(
                        runner.name!,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        team.abbreviation ??
                            team.name!.substring(0, 1).toUpperCase(),
                        style:
                            const TextStyle(fontSize: 16, color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        runner.grade?.toString() ?? '-',
                        style:
                            const TextStyle(fontSize: 16, color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        runner.bibNumber!,
                        style: TextStyle(
                          color: bibColor,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Colors.grey),
        ],
      ),
    );

    if (isViewMode) {
      return runnerRow;
    }

    return Slidable(
      key: Key(runner.bibNumber!),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onAction('Edit'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
          ),
          SlidableAction(
            onPressed: (_) => onAction('Delete'),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
          ),
        ],
      ),
      child: runnerRow,
    );
  }
}
