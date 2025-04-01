import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/instruction_card.dart';
import '../../race_screen/widgets/runner_record.dart';
import '../controller/resolve_bib_number_controller.dart';

class ResolveBibNumberScreen extends StatefulWidget {
  final List<RunnerRecord> records;
  final int raceId;
  final Function(RunnerRecord) onComplete;
  final RunnerRecord record;

  const ResolveBibNumberScreen({
    super.key,
    required this.records,
    required this.raceId,
    required this.onComplete,
    required this.record,
  });

  @override
  State<ResolveBibNumberScreen> createState() => _ResolveBibNumberScreenState();
}

class _ResolveBibNumberScreenState extends State<ResolveBibNumberScreen> {
  late ResolveBibNumberController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ResolveBibNumberController(
      records: widget.records,
      raceId: widget.raceId,
      onComplete: widget.onComplete,
      record: widget.record,
    );
    _controller.setContext(context);
  }

  Widget _buildSearchResults() {
    return Expanded(
      child: ListView.builder(
        itemCount: _controller.searchResults.length,
        itemBuilder: (context, index) {
          final runner = _controller.searchResults[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.primaryColor.withAlpha((0.2 * 255).round()),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  runner.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildInfoChip(
                          'Bib ${runner.bib}',
                          AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        if (runner.grade > 0)
                          _buildInfoChip(
                            'Grade ${runner.grade}',
                            AppColors.mediumColor,
                          ),
                        const SizedBox(width: 8),
                        if (runner.school != '')
                          Expanded(
                            child: _buildInfoChip(
                              runner.school,
                              AppColors.mediumColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                onTap: () => _controller.assignExistingRunner(runner),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCreateNewForm() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _controller.nameController,
              label: 'Runner Name',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _controller.gradeController,
              label: 'Grade',
              icon: Icons.school,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _controller.schoolController,
              label: 'School',
              icon: Icons.business,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _controller.createNewRunner,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
              child: const Text(
                'Create New Runner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    Future<void> Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primaryColor.withAlpha((0.2 * 255).round()),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primaryColor.withAlpha((0.2 * 255).round()),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primaryColor,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.record.error == null) {
      return const Scaffold(
        body: Center(child: Text('No records to resolve')),
      );
    }

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Resolve Bib Numbers'),
      //   elevation: 0,
      //   backgroundColor: AppColors.primaryColor,
      // ),
      body: Container(
        color: AppColors.backgroundColor,
        child: Padding(
          // padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          padding: EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInstructionsCard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Choose Existing Runner',
                      Icons.people,
                      !_controller.showCreateNew,
                      () {
                        _controller.searchRunners(_controller.searchController.text);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      'Create New Runner',
                      Icons.person_add,
                      _controller.showCreateNew,
                      () {
                        setState(() {
                          _controller.showCreateNew = true;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!_controller.showCreateNew) ...[
                _buildTextField(
                  controller: _controller.searchController,
                  label: 'Search runners',
                  icon: Icons.search,
                  onChanged: (value) => _controller.searchRunners(value),
                ),
                const SizedBox(height: 16),
                _buildSearchResults(),
              ] else
                _buildCreateNewForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return InstructionCard(
      title: 'Resolve Bib Number',
      instructions: [
        InstructionItem(
            number: '1',
            text:
                'Choose an existing runner or create a new one to assign to bib #${_controller.record.bib}'),
        const InstructionItem(
            number: '2',
            text:
                'For existing runners, search by name, school, or bib number'),
        const InstructionItem(
            number: '3',
            text: 'For new runners, enter all required information'),
      ],
      initiallyExpanded: true,
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, bool isSelected, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primaryColor : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.primaryColor.withAlpha((0.2 * 255).round()),
            width: 1,
          ),
        ),
        elevation: isSelected ? 3 : 1,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : AppColors.primaryColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: null,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
