import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/role_bar/models/role_enums.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/components/coach_mark.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/event_bus.dart';
import '../../../core/services/geo_location_service.dart';
import '../../../core/services/post_frame_callback_scheduler.dart';
import '../../../core/services/i_sync_service.dart';
import '../controller/races_controller.dart';
import '../services/races_service.dart';
import '../widgets/race_tutorial_coach_mark.dart';
import '../../../core/components/app_header.dart';
import '../../../shared/role_bar/widgets/role_selector_sheet.dart';
import '../../../shared/settings_screen.dart';
import '../widgets/races_list.dart';

class RacesScreen extends StatefulWidget {
  final bool canEdit;

  // Optional service overrides — defaults to production implementations.
  // Inject mocks in tests to avoid touching real platform APIs.
  final IRacesService? racesService;
  final IAuthService? authService;
  final IEventBus? eventBus;
  final IGeoLocationService? geoLocationService;
  final IPostFrameCallbackScheduler? postFrameCallbackScheduler;
  final TutorialManager? tutorialManager;

  const RacesScreen({
    super.key,
    this.canEdit = true,
    this.racesService,
    this.authService,
    this.eventBus,
    this.geoLocationService,
    this.postFrameCallbackScheduler,
    this.tutorialManager,
  });

  @override
  RacesScreenState createState() => RacesScreenState();
}

class RacesScreenState extends State<RacesScreen> {
  late final RacesController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RacesController(
      racesService: widget.racesService ?? RacesService(),
      authService: widget.authService ?? AuthService.instance,
      eventBus: widget.eventBus ?? EventBus.instance,
      geoLocationService: widget.geoLocationService ?? GeoLocationService(),
      postFrameCallbackScheduler:
          widget.postFrameCallbackScheduler ?? WidgetsBindingAdapter(),
      tutorialManager: widget.tutorialManager ?? TutorialManager(),
      syncStream: context.read<ISyncService>().syncEvents,
      canEdit: widget.canEdit,
    );
    _controller.initState(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.canEdit ? Role.coach : Role.spectator;
    // Static Scaffold — no outer AnimatedBuilder. RacesList subscribes to
    // _controller directly so only the list rebuilds when races change.
    return TutorialRoot(
        tutorialManager: _controller.tutorialManager,
        child: Scaffold(
            floatingActionButton: widget.canEdit
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main Create Race FAB
                      CoachMark(
                        id: 'create_race_button_tutorial',
                        tutorialManager: _controller.tutorialManager,
                        config: const CoachMarkConfig(
                          title: 'Create Race',
                          alignmentX: AlignmentX.left,
                          alignmentY: AlignmentY.top,
                          description: 'Click here to create a new race',
                          icon: Icons.add,
                          type: CoachMarkType.targeted,
                          backgroundColor: AppColors.statusPreRace,
                          elevation: 12,
                        ),
                        child: FloatingActionButton(
                          heroTag: 'create_race',
                          onPressed: () =>
                              _controller.showCreateRaceSheet(context),
                          backgroundColor: AppColors.primaryColor,
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  )
                : null,
            body: Column(
              children: [
                // Sticky header
                AppHeader(
                  title: 'My Races',
                  currentRole: role,
                  tutorialManager: _controller.tutorialManager,
                  onRoleTap: () =>
                      RoleSelectorSheet.showRoleSelection(context, role),
                  onSettingsTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        currentRole: role.toValueString(),
                      ),
                    ),
                  ),
                ),
                // Scrollable content
                Expanded(
                  child: RaceCoachMark(
                    controller: _controller,
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                          sliver: RacesList(
                            controller: _controller,
                            canEdit: widget.canEdit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )));
  }
}
