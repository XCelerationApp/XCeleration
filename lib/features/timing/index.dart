/// Timing feature module
/// Consolidates all timing-related functionality
library;

// Controllers
export '../../assistant/race_timer/controller/timing_controller.dart';
export '../../assistant/bib_number_recorder/controller/bib_number_controller.dart';

// Models
export '../../assistant/race_timer/model/timing_data.dart' hide TimingData;
export '../../assistant/race_timer/model/timing_utils.dart';
export '../../assistant/race_timer/model/ui_record.dart';
export '../../assistant/bib_number_recorder/model/bib_record.dart';

// Utils
export '../../assistant/race_timer/utils/timing_data_converter.dart';

// Screens
export '../../assistant/race_timer/screen/timing_screen.dart';
export '../../assistant/bib_number_recorder/screen/bib_number_screen.dart';

// Widgets
export '../../assistant/race_timer/widgets/timer_display_widget.dart';
export '../../assistant/race_timer/widgets/race_controls_widget.dart';
export '../../assistant/race_timer/widgets/bottom_controls_widget.dart';
export '../../assistant/race_timer/widgets/records_list_widget.dart';
export '../../assistant/race_timer/widgets/record_list_item.dart';
export '../../assistant/race_timer/widgets/race_info_header_widget.dart';

export '../../assistant/bib_number_recorder/widget/bib_input_widget.dart';
export '../../assistant/bib_number_recorder/widget/bib_list_widget.dart';
export '../../assistant/bib_number_recorder/widget/keyboard_accessory_bar.dart';
export '../../assistant/bib_number_recorder/widget/race_controls_widget.dart'
    hide RaceControlsWidget;
export '../../assistant/bib_number_recorder/widget/race_info_header_widget.dart'
    hide RaceInfoHeaderWidget;
