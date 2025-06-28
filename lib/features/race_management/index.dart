/// Race management feature module
/// Consolidates all race setup and management functionality
library;

// Controllers
export '../../coach/race_screen/controller/race_screen_controller.dart';
export '../../coach/races_screen/controller/races_controller.dart';
export '../../coach/flows/controller/flow_controller.dart';
export '../../coach/flows/PreRaceFlow/controller/pre_race_controller.dart';
export '../../coach/flows/PostRaceFlow/controller/post_race_controller.dart';

// Models
export '../../shared/models/race.dart';
export '../../coach/flows/model/flow_model.dart';

// Screens
export '../../coach/race_screen/screen/race_screen.dart';
export '../../coach/races_screen/screen/races_screen.dart';

// Services
export '../../coach/race_screen/services/race_service.dart';
export '../../coach/races_screen/services/races_service.dart';

// Widgets - Race Screen
export '../../coach/race_screen/widgets/race_header.dart';
export '../../coach/race_screen/widgets/race_details_tab.dart';
export '../../coach/race_screen/widgets/tab_bar.dart';
export '../../coach/race_screen/widgets/tab_bar_view.dart';
export '../../coach/race_screen/widgets/flow_notification.dart';
export '../../coach/race_screen/widgets/race_status_indicator.dart';

// Widgets - Form Fields
export '../../coach/race_screen/widgets/race_name_field.dart';
export '../../coach/race_screen/widgets/race_location_field.dart';
export '../../coach/race_screen/widgets/race_date_field.dart';
export '../../coach/race_screen/widgets/race_distance_field.dart';
export '../../coach/race_screen/widgets/competing_teams_field.dart';

// Widgets - Races List
export '../../coach/races_screen/widgets/races_list.dart';
export '../../coach/races_screen/widgets/race_card.dart';
export '../../coach/races_screen/widgets/race_creation_sheet.dart';

// Widgets - Flow Components
export '../../coach/flows/widgets/flow_indicator.dart';
export '../../coach/flows/widgets/flow_action_button.dart';
export '../../coach/flows/widgets/flow_section_header.dart';
export '../../coach/flows/widgets/flow_step_content.dart';
