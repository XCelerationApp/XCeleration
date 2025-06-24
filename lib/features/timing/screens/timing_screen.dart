import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/components/button_components.dart';
import '../../../shared/constants/app_constants.dart';
import '../controllers/timing_controller.dart';
import '../services/timing_service.dart';
import '../../../core/services/event_bus.dart';

/// Consolidated timing screen for race timing and bib recording
class TimingScreen extends StatefulWidget {
  const TimingScreen({super.key});

  @override
  State<TimingScreen> createState() => _TimingScreenState();
}

class _TimingScreenState extends State<TimingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TimingController _timingController;
  final _bibController = TextEditingController();
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize timing controller
    _timingController = TimingController(
      timingService: TimingService(),
      eventBus: EventBus.instance,
    );

    // Load existing records
    _timingController.loadRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timingController.dispose();
    _bibController.dispose();
    _nameController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _timingController,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Race Timing'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Timer', icon: Icon(Icons.timer)),
              Tab(text: 'Bib Numbers', icon: Icon(Icons.assignment)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTimerTab(),
            _buildBibTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerTab() {
    return Consumer<TimingController>(
      builder: (context, controller, child) {
        return Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            children: [
              // Timer Display
              Container(
                padding: const EdgeInsets.all(AppConstants.largePadding),
                decoration: BoxDecoration(
                  color: AppColors.lightColor,
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: Column(
                  children: [
                    Text(
                      'Elapsed Time',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(controller.elapsedTime),
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.largePadding),

              // Timer Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ActionButton(
                    text: controller.isTimerRunning
                        ? 'Stop Timer'
                        : 'Start Timer',
                    icon: controller.isTimerRunning
                        ? Icons.stop
                        : Icons.play_arrow,
                    onPressed: controller.isLoading
                        ? null
                        : () {
                            if (controller.isTimerRunning) {
                              controller.stopTimer();
                            } else {
                              controller.startTimer();
                            }
                          },
                    backgroundColor: controller.isTimerRunning
                        ? AppColors.redColor
                        : AppColors.primaryColor,
                    size: ButtonSize.large,
                  ),
                  ActionButton(
                    text: 'Record Time',
                    icon: Icons.add_circle,
                    onPressed:
                        controller.isTimerRunning && !controller.isLoading
                            ? controller.recordTime
                            : null,
                    size: ButtonSize.large,
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.largePadding),

              // Recent Times
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recorded Times (${controller.timingRecords.length})',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: controller.timingRecords.isEmpty
                          ? Center(
                              child: Text(
                                'No times recorded yet',
                                style: AppTypography.bodyRegular.copyWith(
                                  color: AppColors.mediumColor,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: controller.timingRecords.length,
                              itemBuilder: (context, index) {
                                final record = controller.timingRecords[index];
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primaryColor,
                                      child: Text(
                                        '${record.place ?? index + 1}',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    title: Text(
                                      record.elapsedTime,
                                      style: AppTypography.titleMedium,
                                    ),
                                    subtitle: Text(
                                      record.hasBibNumber
                                          ? 'Bib: ${record.bibNumber}'
                                          : 'No bib assigned',
                                    ),
                                    trailing: record.isConfirmed
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.green)
                                        : const Icon(Icons.pending,
                                            color: Colors.orange),
                                    onTap: () =>
                                        controller.selectRecord(record),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBibTab() {
    return Consumer<TimingController>(
      builder: (context, controller, child) {
        return Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            children: [
              // Bib Input Form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Bib Number',
                        style: AppTypography.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _bibController,
                        decoration: const InputDecoration(
                          labelText: 'Bib Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.confirmation_number),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Runner Name (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _schoolController,
                        decoration: const InputDecoration(
                          labelText: 'School (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ActionButton(
                        text: 'Record Bib',
                        icon: Icons.add,
                        onPressed: controller.isLoading ? null : _recordBib,
                        size: ButtonSize.fullWidth,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppConstants.defaultPadding),

              // Recorded Bibs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recorded Bibs (${controller.bibRecords.length})',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: controller.bibRecords.isEmpty
                          ? Center(
                              child: Text(
                                'No bib numbers recorded yet',
                                style: AppTypography.bodyRegular.copyWith(
                                  color: AppColors.mediumColor,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: controller.bibRecords.length,
                              itemBuilder: (context, index) {
                                final record = controller.bibRecords[index];
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: record.isValid
                                          ? Colors.green
                                          : Colors.orange,
                                      child: Text(
                                        record.bibNumber,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      record.name.isEmpty
                                          ? 'Bib ${record.bibNumber}'
                                          : record.name,
                                      style: AppTypography.bodyRegular,
                                    ),
                                    subtitle: record.school.isNotEmpty
                                        ? Text(record.school)
                                        : null,
                                    trailing: record.isValid
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.green)
                                        : const Icon(Icons.warning,
                                            color: Colors.orange),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _recordBib() {
    final bibNumber = _bibController.text.trim();
    if (bibNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a bib number')),
      );
      return;
    }

    _timingController.addBibRecord(
      bibNumber,
      name: _nameController.text.trim(),
      school: _schoolController.text.trim(),
    );

    // Clear form
    _bibController.clear();
    _nameController.clear();
    _schoolController.clear();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
