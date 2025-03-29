import 'package:flutter/material.dart';
import 'package:xcelerate/shared/settings_screen.dart';
import '../../../shared/models/race.dart';
import '../../../utils/database_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../flows/widgets/flow_section_header.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/components/coach_mark.dart';
import '../controller/races_controller.dart';
import '../widgets/race_card.dart';
import '../widgets/race_tutorial_coach_mark.dart';

class RacesScreen extends StatefulWidget {
  const RacesScreen({super.key});

  @override
 RacesScreenState createState() => RacesScreenState();
}


class RacesScreenState extends State<RacesScreen> {
  final RacesController _controller = RacesController();

  @override
  void initState() {
    super.initState();
    _controller.setContext(context);
    _controller.initState();
  }

  // CoachMark _buildSwipeTutorial(Widget child, RacesController controller) {
  //   return CoachMark(
  //     id: 'race_swipe_tutorial',
  //     tutorialManager: controller.tutorialManager,
  //     config: const CoachMarkConfig(
  //       title: 'Swipe Actions',
  //       description: 'Swipe right on a race to edit/delete',
  //       icon: Icons.swipe,
  //       type: CoachMarkType.general,
  //       backgroundColor: Color(0xFF1976D2),
  //     ),
  //     child: child,
  //   );
  // }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Widget _buildCreateRaceSheetContent(StateSetter setSheetState, {bool isEditing = false, int? raceId}) {
  //   return SingleChildScrollView(
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.stretch,
  //       children: [
  //         _buildRaceNameField(_controller, setSheetState),
  //         SizedBox(height: 12),
  //         _buildCompetingTeamsField(_controller, setSheetState),
  //         SizedBox(height: 12),
  //         _buildRaceLocationField(_controller, setSheetState),
  //         SizedBox(height: 12),
  //         _buildRaceDateField(_controller, setSheetState),
  //         SizedBox(height: 12),
  //         _buildRaceDistanceField(_controller, setSheetState),
  //         SizedBox(height: 12),
  //         _buildActionButton(_controller, isEditing: isEditing, raceId: raceId),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildActionButton(RacesController controller, {bool isEditing = false, int? raceId}) {
  //   return ElevatedButton(
  //       onPressed: () async {
  //         final error = controller.getFirstError();
  //         if (error != null) {
  //           DialogUtils.showErrorDialog(
  //             context,
  //             message: error,
  //           );
  //           return;
  //         }

  //         final race = Race(
  //           raceId: isEditing && raceId != null ? raceId : 0,
  //           raceName: controller.nameController.text,
  //           location: controller.locationController.text,
  //           raceDate: DateTime.parse(controller.dateController.text),
  //           distance: double.parse(controller.distanceController.text),
  //           distanceUnit: controller.unitController.text,
  //           teams: controller.teamControllers
  //               .map((controller) => controller.text.trim())
  //               .where((text) => text.isNotEmpty)
  //               .toList(),
  //           teamColors: controller.teamColors,
  //           flowState: 'setup',
  //         );

  //         if (isEditing && raceId != null) {
  //           final flowState = (await DatabaseHelper.instance.getRaceById(raceId))!.flowState;
  //           await DatabaseHelper.instance.updateRace(race.copyWith(flowState: flowState));
  //         } else {
  //           await DatabaseHelper.instance.insertRace(race);
  //         }
  //         await controller.loadRaces();

  //         if (mounted) {
  //           Navigator.pop(context);
  //         }
  //       },
  //       style: ElevatedButton.styleFrom(
  //         padding: const EdgeInsets.symmetric(vertical: 16),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(16),
  //         ),
  //         backgroundColor: AppColors.primaryColor,
  //         fixedSize: const Size.fromHeight(64),
  //       ),
  //       child: Text(
  //         isEditing ? 'Save Changes' : 'Create Race',
  //         style: const TextStyle(fontSize: 24, color: Colors.white),
  //       ),
  //   );
  // }

  // Widget _buildRaceNameField(RacesController controller, StateSetter setSheetState) {
  //   return buildInputRow(
  //     label: 'Name',
  //     inputWidget: buildTextField(
  //       context: context,
  //       controller: controller.nameController,
  //       hint: 'Enter race name',
  //       error: controller.nameError,
  //       onChanged: (_) => controller.validateName(controller.nameController.text, setSheetState),
  //       setSheetState: setSheetState,
  //     ),
  //   );
  // }

  // Widget _buildCompetingTeamsField(RacesController controller, StateSetter setSheetState) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Padding(
  //         padding: const EdgeInsets.only(bottom: 8),
  //         child: Text(
  //           'Competing Teams',
  //           style: AppTypography.bodySemibold,
  //         ),
  //       ),
  //       if (controller.teamsError != null)
  //         Padding(
  //           padding: const EdgeInsets.only(top: 8),
  //           child: Text(
  //             controller.teamsError!,
  //             style: TextStyle(
  //               color: Colors.red,
  //               fontSize: 12,
  //             ),
  //           ),
  //         ),
  //       ...controller.teamControllers.asMap().entries.map((entry) {
  //         int index = entry.key;
  //         TextEditingController textController = entry.value;
  //         return Padding(
  //           padding: const EdgeInsets.only(bottom: 8.0),
  //           child: Row(
  //             children: [
  //               Expanded(
  //                 child: buildTextField(
  //                   context: context,
  //                   controller: textController,
  //                   hint: 'Team name',
  //                   onChanged: (value) {
  //                     setSheetState(() {
  //                       controller.teamsError = controller.teamControllers.every(
  //                         (textController) => textController.text.trim().isEmpty)
  //                           ? 'Please enter in team name'
  //                           : null;
  //                     });
  //                   },
  //                   setSheetState: setSheetState,
  //                 ),
  //               ),
  //               const SizedBox(width: 12),
  //               GestureDetector(
  //                 onTap: () => controller.showColorPicker(setSheetState, textController),
  //                 child: Container(
  //                   width: 40,
  //                   height: 40,
  //                   decoration: BoxDecoration(
  //                     color: controller.teamColors[index],
  //                     shape: BoxShape.circle,
  //                     border: Border.all(color: Colors.grey[300]!),
  //                     boxShadow: [
  //                       BoxShadow(
  //                         color: Colors.black.withAlpha((0.1 * 255).round()),
  //                         blurRadius: 4,
  //                         offset: Offset(0, 2),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //               if (controller.teamControllers.length > 1)
  //                 IconButton(
  //                   icon: Icon(Icons.remove_circle_outline, color: Colors.red),
  //                   onPressed: () {
  //                     setSheetState(() {
  //                       controller.teamControllers.removeAt(index);
  //                       controller.teamColors.removeAt(index);
  //                     });
  //                   },
  //                 ),
  //             ],
  //           ),
  //         );
  //       }),
  //       const SizedBox(height: 12),
  //       TextButton.icon(
  //         onPressed: () {
  //           setSheetState(() {
  //             controller.addTeamField();
  //           });
  //         },
  //         icon: Icon(Icons.add_circle_outline, color: AppColors.primaryColor),
  //         label: Text(
  //           'Add Another Team',
  //           style: TextStyle(
  //             color: AppColors.primaryColor,
  //             fontWeight: FontWeight.w600,
  //           ),
  //         ),
  //         style: TextButton.styleFrom(
  //           padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(8),
  //             side: BorderSide(color: AppColors.primaryColor),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildRaceLocationField(RacesController controller, StateSetter setSheetState) {
  //   return buildInputRow(
  //     label: 'Location',
  //     inputWidget: Row(
  //       children: [
  //         Expanded(
  //           flex: 2,
  //           child: buildTextField(
  //             context: context,
  //             controller: controller.locationController,
  //             hint: (Platform.isIOS || Platform.isAndroid)
  //                 ? 'Other location'
  //                 : 'Enter race location',
  //             error: controller.locationError,
  //             setSheetState: setSheetState,
  //             onChanged: (_) => controller.validateLocation(controller.locationController.text, setSheetState),
  //             keyboardType: TextInputType.text,
  //           ),
  //         ),
  //         if (controller.isLocationButtonVisible && (Platform.isIOS || Platform.isAndroid)) ...[
  //          const SizedBox(width: 12),
  //           Expanded(
  //             flex: 1,
  //             child: IconButton(
  //               icon: Icon(Icons.my_location, color: AppColors.primaryColor),
  //               onPressed: controller.getCurrentLocation,
  //             )
  //           ),
  //         ]
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildRaceDateField(RacesController controller, StateSetter setSheetState) {
  //   return buildInputRow(
  //     label: 'Date',
  //     inputWidget: buildTextField(
  //       context: context,
  //       controller: controller.dateController,
  //       hint: 'YYYY-MM-DD',
  //       error: controller.dateError,
  //       suffixIcon: IconButton(
  //         icon: Icon(Icons.calendar_today, color: AppColors.primaryColor),
  //         onPressed: () => controller.selectDate(context),
  //       ),
  //       setSheetState: setSheetState,
  //       onChanged: (_) => controller.validateDate(controller.dateController.text, setSheetState),
  //     ),
  //   );
  // }

  // Widget _buildRaceDistanceField(RacesController controller, StateSetter setSheetState) {
  //   return buildInputRow(
  //     label: 'Distance',
  //     inputWidget: Row(
  //       children: [
  //         Expanded(
  //           flex: 2,
  //           child: buildTextField(
  //             context: context,
  //             controller: controller.distanceController,
  //             hint: '0.0',
  //             error: controller.distanceError,
  //             setSheetState: setSheetState,
  //             onChanged: (_) => controller.validateDistance(controller.distanceController.text, setSheetState),
  //             keyboardType: TextInputType.numberWithOptions(decimal: true),
  //           ),
  //         ),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           flex: 1,
  //           child: buildDropdown(
  //             controller: controller.unitController,
  //             hint: 'mi',
  //             error: null,
  //             setSheetState: setSheetState,
  //             items: ['mi', 'km'],
  //             onChanged: (value) => controller.unitController.text = value,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return TutorialRoot(
      tutorialManager: _controller.tutorialManager,
      child: Scaffold(
        floatingActionButton: CoachMark(
          id: 'create_race_button_tutorial',
          tutorialManager: _controller.tutorialManager,
          config: const CoachMarkConfig(
            title: 'Create Race',
            alignmentX: AlignmentX.left,
            alignmentY: AlignmentY.top,
            description: 'Click here to create a new race',
            icon: Icons.add,
            type: CoachMarkType.targeted,
            backgroundColor: Color(0xFF1976D2),
            elevation: 12,
          ),
          child: FloatingActionButton(
            onPressed: () => _controller.showCreateRaceSheet(context),
            // tooltip: 'Create new race',
            backgroundColor: AppColors.primaryColor,
            child: Icon(Icons.add),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.fromLTRB(24.0, 56.0, 24.0, 24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Races',
                      style: AppTypography.displaySmall,
                    ),
                    Row(
                      children: [
                        CoachMark(
                          id: 'settings_button_tutorial',
                          tutorialManager: _controller.tutorialManager,
                          config: const CoachMarkConfig(
                            title: 'Settings',
                            alignmentX: AlignmentX.left,
                            alignmentY: AlignmentY.bottom,
                            description: 'Click here to open settings',
                            icon: Icons.settings,
                            type: CoachMarkType.targeted,
                            backgroundColor: Color(0xFF1976D2),
                            elevation: 12,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => SettingsScreen(currentRole: 'coach')),
                              );
                            },
                            child: Icon(Icons.settings, color: AppColors.darkColor, size: 36)
                          ),
                        )
                      ]
                    ),
                  ],
                ),
                RaceCoachMark(
                  controller: _controller,
                  child: FutureBuilder<List<Race>>(
                    future: DatabaseHelper.instance.getAllRaces(),
                    builder: (context, snapshot){
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: AppTypography.bodyRegular.copyWith(color: Colors.red)));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(child: Text('No races found.', style: AppTypography.bodyRegular));
                      }

                      final List<Race> raceData = snapshot.data ?? [];
                      final finishedRaces = raceData.where((race) => race.flowState == 'finished').toList();
                      final raceInProgress = raceData.where((race) => race.flowState == 'post-race' || race.flowState == 'pre-race').toList();
                      final upcomingRaces = raceData.where((race) => race.flowState == 'setup').toList();
                      return SingleChildScrollView(
                        controller: ScrollController(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (raceInProgress.isNotEmpty) ...[
                              FlowSectionHeader(title: 'In Progress'),
                              ...raceInProgress.map((race) => RaceCard(race: race, flowState: race.flowState, controller: _controller)),
                            ],
                            if (upcomingRaces.isNotEmpty) ...[
                              FlowSectionHeader(title: 'Upcoming'),
                              ...upcomingRaces.map((race) => RaceCard(race: race, flowState: race.flowState, controller: _controller)),
                            ],
                            if (finishedRaces.isNotEmpty) ...[
                              FlowSectionHeader(title: 'Finished'),
                              ...finishedRaces.map((race) => RaceCard(race: race, flowState: race.flowState, controller: _controller)),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ]
            ),
          ),
        )
      )
    );
  }
}