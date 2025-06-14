import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
// import '../controller/merge_conflicts_controller.dart';
// import 'package:xceleration/core/utils/color_utils.dart';

// class TimeSelector extends StatefulWidget {
//   const TimeSelector({
//     super.key,
//     required this.controller,
//     required this.timeController,
//     required this.manualController,
//     required this.times,
//     required this.conflictIndex,
//     required this.manual,
//     required this.timeIndex,
//   });

//   final MergeConflictsController controller;
//   final TextEditingController timeController;
//   final TextEditingController? manualController;
//   final List<String> times;
//   final int conflictIndex;
//   final bool manual;
//   final int timeIndex;

//   @override
//   State<TimeSelector> createState() => _TimeSelectorState();
// }

// class _TimeSelectorState extends State<TimeSelector> {
//   bool _dropdownOpen = false;
//   OverlayEntry? _overlayEntry;
//   final GlobalKey _buttonKey = GlobalKey();
//   late final String _dropdownId;

//   @override
//   void initState() {
//     super.initState();
//     _dropdownId = UniqueKey().toString();
//     // Prefill the timeController if empty and available times exist
//     if (widget.timeController.text.isEmpty &&
//         widget.timeIndex < widget.times.length) {
//       widget.timeController.text = widget.times[widget.timeIndex];
//     }
//   }

//   void _toggleDropdown() {
//     if (_dropdownOpen) {
//       _closeDropdown();
//       widget.controller.setOpenDropdownForConflict(widget.conflictIndex, null);
//     } else {
//       widget.controller.setOpenDropdownForConflict(widget.conflictIndex, _dropdownId);
//       _openDropdown();
//     }
//   }

//   void _openDropdown() {
//     setState(() {
//       _dropdownOpen = true;
//     });
//     _overlayEntry = _createOverlayEntry();
//     Overlay.of(context).insert(_overlayEntry!);
//   }

//   void _closeDropdown() {
//     setState(() {
//       _dropdownOpen = false;
//     });
//     _overlayEntry?.remove();
//     _overlayEntry = null;
//   }

//   void _updateDropdownPosition() {
//     if (_dropdownOpen && _overlayEntry != null) {
//       _overlayEntry!.markNeedsBuild();
//     }
//   }

//   OverlayEntry _createOverlayEntry() {
//     final availableOptions = widget.times
//         .where((time) =>
//             time == widget.timeController.text ||
//             !widget.controller.selectedTimes[widget.conflictIndex].contains(time))
//         .toList();

//     return OverlayEntry(
//       builder: (context) {
//         // Get current position each time the overlay rebuilds
//         final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
//         if (renderBox == null) return const SizedBox.shrink();
        
//         final Size size = renderBox.size;
//         final Offset offset = renderBox.localToGlobal(Offset.zero);
        
//         return Stack(
//           children: [
//             // Full-screen GestureDetector to detect double-tap outside the dropdown
//             Positioned.fill(
//               child: GestureDetector(
//                 behavior: HitTestBehavior.translucent,
//                 onDoubleTap: () {
//                   _closeDropdown();
//                 },
//                 // Absorb pointer events so dropdown itself still works
//                 child: Container(),
//               ),
//             ),
//             // Dropdown content - positioned based on current button position
//             Positioned(
//               left: offset.dx,
//               top: offset.dy + size.height + 4,
//               width: MediaQuery.of(context).size.width * 0.6,
//               child: GestureDetector(
//                 // Prevent taps on the dropdown from closing it
//                 onTap: () {},
//                 child: Material(
//                   elevation: 8, // Increased elevation for better visibility
//                   borderRadius: BorderRadius.circular(8),
//                   color: Colors.white,
//                   child: ConstrainedBox(
//                     constraints: const BoxConstraints(maxHeight: 250),
//                     child: ListView(
//                       padding: EdgeInsets.zero,
//                       shrinkWrap: true,
//                       children: [
//                         if (widget.manual)
//                           Padding(
//                             padding: const EdgeInsets.all(8.0),
//                             child: ValueListenableBuilder<TextEditingValue>(
//                               valueListenable: widget.manualController!,
//                               builder: (context, value, child) {
//                                 final bool isManualSet = value.text.isNotEmpty;
//                                 return Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     TextField(
//                                       controller: widget.manualController,
//                                       enabled: !isManualSet,
//                                       style: AppTypography.smallBodySemibold.copyWith(
//                                         color: isManualSet ? Colors.grey : AppColors.darkColor,
//                                       ),
//                                       cursorColor: AppColors.primaryColor,
//                                       decoration: InputDecoration(
//                                         hintText: 'Enter time',
//                                         hintStyle: AppTypography.smallBodyRegular.copyWith(
//                                           color: Colors.grey[500],
//                                         ),
//                                         border: const OutlineInputBorder(),
//                                       ),
//                                       onChanged: (value) {
//                                         final previousValue = widget.timeController.text;
//                                         if (value.isNotEmpty) {
//                                           widget.timeController.text = value;
//                                           widget.controller.updateSelectedTime(
//                                               widget.conflictIndex, value, previousValue);
//                                         } else {
//                                           // Reset selected time if manual entry cleared
//                                           widget.timeController.text = '';
//                                           widget.controller.updateSelectedTime(
//                                               widget.conflictIndex, '', previousValue);
//                                         }
//                                       },
//                                     ),
//                                     if (isManualSet)
//                                       Padding(
//                                         padding: const EdgeInsets.only(top: 4.0),
//                                         child: Text(
//                                           'Manual time set. Clear to enter a new one.',
//                                           style: AppTypography.smallBodyRegular.copyWith(
//                                             color: Colors.grey[600],
//                                             fontSize: 12,
//                                           ),
//                                         ),
//                                       ),
//                                   ],
//                                 );
//                               },
//                             ),
//                           ),
//                         ...availableOptions.map(
//                           (time) => ListTile(
//                             title: Text(
//                               time,
//                               style: AppTypography.smallBodySemibold.copyWith(
//                                 color: AppColors.darkColor,
//                               ),
//                             ),
//                             onTap: () {
//                               final previousValue = widget.timeController.text;
//                               widget.timeController.text = time;
//                               widget.controller.updateSelectedTime(
//                                   widget.conflictIndex, time, previousValue);
//                               if (widget.manualController != null) {
//                                 widget.manualController?.clear();
//                               }
//                               _closeDropdown();
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   void dispose() {
//     _overlayEntry?.remove();
//     _controllerListener?.call();
//     super.dispose();
//   }

//   VoidCallback? _controllerListener;

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _controllerListener?.call(); // Remove previous listener if any
//     _controllerListener = () {
//       final openDropdownId = widget.controller.getOpenDropdownForConflict(widget.conflictIndex);
//       if (openDropdownId != _dropdownId && _dropdownOpen) {
//         _closeDropdown();
//       }
//     };
//     widget.controller.addListener(_controllerListener!);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return NotificationListener<ScrollNotification>(
//       onNotification: (ScrollNotification notification) {
//         // Update dropdown position when scrolling occurs
//         if (_dropdownOpen) {
//           _updateDropdownPosition();
//         }
//         return false; // Allow the scroll notification to continue
//       },
//       child: GestureDetector(
//         onTap: _toggleDropdown,
//         child: Container(
//           key: _buttonKey, // Add key to track this widget's position
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(8),
//           border: _dropdownOpen
//               ? Border.all(color: AppColors.primaryColor, width: 2)
//               : null,
//           boxShadow: [
//             BoxShadow(
//               color: ColorUtils.withOpacity(Color.fromRGBO(0, 0, 0, 1.0), 0.05),
//               blurRadius: 4,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Expanded(
//               child: Text(
//                 widget.timeController.text.isEmpty
//                     ? 'Select Time'
//                     : widget.timeController.text,
//                 style: AppTypography.smallBodySemibold.copyWith(
//                   color: AppColors.darkColor,
//                 ),
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//             Icon(
//               _dropdownOpen
//                   ? Icons.arrow_drop_up
//                   : Icons.arrow_drop_down,
//               color: AppColors.primaryColor,
//               size: 28,
//             ),
//           ],
//         ),
//       ),
//     ));
//   }
// }

class ConfirmedTime extends StatelessWidget {
  const ConfirmedTime({
    super.key,
    required this.time,
  });
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.darkColor,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
