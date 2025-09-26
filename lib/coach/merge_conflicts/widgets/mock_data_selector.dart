// import 'package:flutter/material.dart';
// import '../demo/mock_data_generator.dart';
// import '../controller/merge_conflicts_controller.dart';

// /// Widget for selecting and loading mock data scenarios
// class MockDataSelector extends StatefulWidget {
//   final MergeConflictsController controller;

//   const MockDataSelector({
//     super.key,
//     required this.controller,
//   });

//   @override
//   State<MockDataSelector> createState() => _MockDataSelectorState();
// }

// class _MockDataSelectorState extends State<MockDataSelector> {
//   MockRaceData? selectedScenario;
//   bool isLoading = false;

//   @override
//   Widget build(BuildContext context) {
//     final scenarios = MockDataGenerator.getPresetScenarios();

//     return Card(
//       margin: const EdgeInsets.all(16),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Row(
//               children: [
//                 const Icon(Icons.science, color: Colors.blue),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Mock Data for Testing',
//                   style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                         fontWeight: FontWeight.bold,
//                       ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Load realistic race scenarios with conflicts to test the resolution system without needing multiple devices.',
//               style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                     color: Colors.grey[600],
//                   ),
//             ),
//             const SizedBox(height: 16),

//             // Scenario Selector
//             DropdownButtonFormField<String>(
//               value: selectedScenario?.scenarioName,
//               decoration: const InputDecoration(
//                 labelText: 'Select Test Scenario',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.playlist_play),
//               ),
//               isExpanded: true,
//               items: scenarios.map((scenario) {
//                 return DropdownMenuItem<String>(
//                   value: scenario.scenarioName,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         scenario.scenarioName,
//                         style: const TextStyle(fontWeight: FontWeight.w500),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       Text(
//                         scenario.description,
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.grey[600],
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                         maxLines: 1,
//                       ),
//                     ],
//                   ),
//                 );
//               }).toList(),
//               onChanged: (String? value) {
//                 setState(() {
//                   selectedScenario = scenarios.firstWhere(
//                     (scenario) => scenario.scenarioName == value,
//                     orElse: () => scenarios.first,
//                   );
//                 });
//               },
//             ),

//             if (selectedScenario != null) ...[
//               const SizedBox(height: 12),
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.blue[50],
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.blue[200]!),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Scenario Details:',
//                       style: TextStyle(
//                         fontWeight: FontWeight.w500,
//                         color: Colors.blue[800],
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       '• ${selectedScenario!.runners.length} runners',
//                       style: const TextStyle(fontSize: 13),
//                     ),
//                     Text(
//                       '• ${selectedScenario!.timingData.records.length} timing records',
//                       style: const TextStyle(fontSize: 13),
//                     ),
//                     Text(
//                       '• ${selectedScenario!.conflictSummary}',
//                       style: const TextStyle(fontSize: 13),
//                     ),
//                   ],
//                 ),
//               ),
//             ],

//             const SizedBox(height: 16),

//             // Load Button
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: selectedScenario == null || isLoading
//                     ? null
//                     : _loadSelectedScenario,
//                 icon: isLoading
//                     ? const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                     : const Icon(Icons.upload),
//                 label: Text(isLoading ? 'Loading...' : 'Load Mock Data'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                 ),
//               ),
//             ),

//             const SizedBox(height: 8),

//             // Clear Button
//             SizedBox(
//               width: double.infinity,
//               child: TextButton.icon(
//                 onPressed: isLoading ? null : _clearData,
//                 icon: const Icon(Icons.clear_all),
//                 label: const Text('Clear All Data'),
//                 style: TextButton.styleFrom(
//                   foregroundColor: Colors.red,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _loadSelectedScenario() async {
//     if (selectedScenario == null) return;

//     setState(() {
//       isLoading = true;
//     });

//     try {
//       // Load the mock data into the controller
//       await widget.controller.loadMockData(
//         selectedScenario!.runners,
//         selectedScenario!.timingData,
//       );

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Loaded ${selectedScenario!.scenarioName} successfully!',
//             ),
//             backgroundColor: Colors.green,
//             duration: const Duration(seconds: 2),
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error loading mock data: $e'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _clearData() async {
//     setState(() {
//       isLoading = true;
//     });

//     try {
//       await widget.controller.clearAllData();

//       if (mounted) {
//         setState(() {
//           selectedScenario = null;
//         });

//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('All data cleared successfully!'),
//             backgroundColor: Colors.orange,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error clearing data: $e'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           isLoading = false;
//         });
//       }
//     }
//   }
// }
