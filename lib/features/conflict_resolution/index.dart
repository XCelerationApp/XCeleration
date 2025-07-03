/// Conflict resolution feature module
/// Consolidates all conflict resolution functionality
library;

// Controllers
export '../../coach/merge_conflicts/controller/merge_conflicts_controller.dart';
export '../../coach/resolve_bib_number_screen/controller/resolve_bib_number_controller.dart';
export '../../coach/flows/PostRaceFlow/steps/load_results/controller/load_results_controller.dart';

// Models
export '../../coach/merge_conflicts/model/chunk.dart';
export '../../coach/merge_conflicts/model/joined_record.dart';
export '../../coach/merge_conflicts/model/resolve_information.dart';
export '../../coach/merge_conflicts/model/timing_data.dart';

// Screens
export '../../coach/merge_conflicts/screen/merge_conflicts_screen.dart';
export '../../coach/resolve_bib_number_screen/screen/resolve_bib_number_screen.dart';

// Services
export '../../coach/merge_conflicts/services/merge_conflicts_service.dart';

// Widgets - Merge Conflicts
export '../../coach/merge_conflicts/widgets/chunk_list.dart';
export '../../coach/merge_conflicts/widgets/header_widgets.dart';
export '../../coach/merge_conflicts/widgets/mock_data_selector.dart';
export '../../coach/merge_conflicts/widgets/runner_time_record.dart';
export '../../coach/merge_conflicts/widgets/runner_info_widgets.dart'
    hide InfoChip;
export '../../coach/merge_conflicts/widgets/runner_time_cells.dart';
export '../../coach/merge_conflicts/widgets/save_button.dart';

// Widgets - Bib Resolution
export '../../coach/resolve_bib_number_screen/widgets/bib_conflicts_overview.dart';
export '../../coach/resolve_bib_number_screen/widgets/search_results.dart';
export '../../coach/resolve_bib_number_screen/widgets/info_chip.dart';

// Widgets - Load Results
export '../../coach/flows/PostRaceFlow/steps/load_results/widgets/load_results_widget.dart';
export '../../coach/flows/PostRaceFlow/steps/load_results/widgets/conflict_button.dart';
export '../../coach/flows/PostRaceFlow/steps/load_results/widgets/reload_button.dart';
export '../../coach/flows/PostRaceFlow/steps/load_results/widgets/success_message.dart';
