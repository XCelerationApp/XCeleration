// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../controller/merge_conflicts_controller.dart';
// import '../widgets/mock_data_selector.dart';
// import '../widgets/chunk_list.dart';
// import '../model/timing_data.dart';

// import '../../../core/theme/app_colors.dart';
// import '../../../core/theme/typography.dart';

// /// Standalone screen for testing mock data without requiring existing race data
// class MockDataTestScreen extends StatefulWidget {
//   const MockDataTestScreen({super.key});

//   @override
//   State<MockDataTestScreen> createState() => _MockDataTestScreenState();
// }

// class _MockDataTestScreenState extends State<MockDataTestScreen> {
//   late MergeConflictsController _controller;
//   bool _isInitialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeController();
//   }

//   void _initializeController() {
//     // Create controller with empty data
//     _controller = MergeConflictsController(
//       raceId: 999, // Test race ID
//       timingData: TimingData(records: [], endTime: ''),
//       runnerRecords: [],
//     );

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _controller.setContext(context);
//       setState(() {
//         _isInitialized = true;
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!_isInitialized) {
//       return const Scaffold(
//         body: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }

//     return ChangeNotifierProvider.value(
//       value: _controller,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Mock Data Testing'),
//           backgroundColor: Colors.green.shade700,
//           foregroundColor: Colors.white,
//         ),
//         body: Container(
//           color: AppColors.backgroundColor,
//           child: SafeArea(
//             child: Consumer<MergeConflictsController>(
//               builder: (context, controller, child) {
//                 return Column(
//                   children: [
//                     // Mock Data Selector Section
//                     if (controller.timingData.records.isEmpty)
//                       Expanded(
//                         child: SingleChildScrollView(
//                           child: Column(
//                             children: [
//                               const SizedBox(height: 20),
//                               _buildWelcomeHeader(),
//                               const SizedBox(height: 20),
//                               MockDataSelector(controller: controller),
//                             ],
//                           ),
//                         ),
//                       )
//                     else
//                       // Conflict Resolution Section
//                       Expanded(
//                         child: Column(
//                           children: [
//                             _buildDataSummaryHeader(controller),
//                             Expanded(
//                               child: _buildComplexModeView(controller),
//                             ),
//                           ],
//                         ),
//                       ),
//                   ],
//                 );
//               },
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildWelcomeHeader() {
//     return Card(
//       margin: const EdgeInsets.all(16),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           children: [
//             Icon(
//               Icons.science,
//               size: 64,
//               color: Colors.green.shade600,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Mock Data Testing Environment',
//               style: AppTypography.titleLarge.copyWith(
//                 color: Colors.green.shade700,
//                 fontWeight: FontWeight.bold,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Test conflict resolution functionality with realistic race scenarios without needing multiple devices.',
//               style: AppTypography.bodyMedium.copyWith(
//                 color: Colors.grey.shade600,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 16),
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.blue.shade50,
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Colors.blue.shade200),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.info, color: Colors.blue.shade700, size: 20),
//                   const SizedBox(width: 8),
//                   Flexible(
//                     child: Text(
//                       'Select a test scenario below to begin testing',
//                       style: TextStyle(
//                         color: Colors.blue.shade700,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDataSummaryHeader(MergeConflictsController controller) {
//     final conflictCount = controller.useSimpleMode
//         ? 0
//         : controller.getFirstConflict()[0] != null
//             ? 1
//             : 0;

//     return Card(
//       margin: const EdgeInsets.all(16),
//       color: conflictCount > 0 ? Colors.orange.shade50 : Colors.green.shade50,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Row(
//               children: [
//                 Icon(
//                   conflictCount > 0 ? Icons.warning : Icons.check_circle,
//                   color: conflictCount > 0
//                       ? Colors.orange.shade700
//                       : Colors.green.shade700,
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     'Race Data Loaded',
//                     style: AppTypography.titleMedium.copyWith(
//                       fontWeight: FontWeight.bold,
//                       color: conflictCount > 0
//                           ? Colors.orange.shade700
//                           : Colors.green.shade700,
//                     ),
//                   ),
//                 ),
//                 ElevatedButton.icon(
//                   onPressed: () => _showClearDataDialog(),
//                   icon: const Icon(Icons.refresh, size: 16),
//                   label: const Text('Reset'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.grey.shade600,
//                     foregroundColor: Colors.white,
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                     textStyle: const TextStyle(fontSize: 12),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 _buildStatChip(
//                   'Runners',
//                   controller.runnerRecords.length.toString(),
//                   Icons.people,
//                   Colors.blue,
//                 ),
//                 _buildStatChip(
//                   'Records',
//                   controller.timingData.records.length.toString(),
//                   Icons.timer,
//                   Colors.purple,
//                 ),
//                 _buildStatChip(
//                   'Conflicts',
//                   conflictCount.toString(),
//                   Icons.warning,
//                   conflictCount > 0 ? Colors.orange : Colors.green,
//                 ),
//                 _buildStatChip(
//                   'Mode',
//                   controller.useSimpleMode ? 'Simple' : 'Complex',
//                   controller.useSimpleMode ? Icons.science : Icons.settings,
//                   controller.useSimpleMode ? Colors.green : Colors.indigo,
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatChip(
//       String label, String value, IconData icon, Color color) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: color.withValues(alpha: 0.3)),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 16, color: color),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               color: color,
//               fontSize: 14,
//             ),
//           ),
//           Text(
//             label,
//             style: TextStyle(
//               color: color,
//               fontSize: 10,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildComplexModeView(MergeConflictsController controller) {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         ChunkList(controller: controller),
//       ],
//     );
//   }

//   void _showClearDataDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Reset Test Data'),
//           content: const Text(
//               'This will clear all loaded data and return to the scenario selection screen.'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 Navigator.of(context).pop();
//                 await _controller.clearAllData();
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text('Reset'),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
