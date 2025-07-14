import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../theme/app_colors.dart';
import 'textfield_utils.dart';
import '../../shared/models/database/master_race.dart';
import '../../shared/models/database/team.dart';

class CreateTeamSheet extends StatefulWidget {
  final MasterRace masterRace;
  final Future<void> Function(Team) createTeam;

  const CreateTeamSheet({
    super.key,
    required this.masterRace,
    required this.createTeam,
  });

  @override
  State<CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<CreateTeamSheet> {
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _abbreviationController = TextEditingController();

  Color _selectedColor = Team.generateColor(0); // Default color
  String? _teamNameError;
  String? _abbreviationError;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _abbreviationController.dispose();
    super.dispose();
  }


  /// Generate abbreviation from first letter of each word (up to 3 words)
  void _generateAbbreviation(String teamName) {
    if (teamName.isNotEmpty) {
      final words = teamName.trim().split(RegExp(r'\s+'));
      final abbreviation = words
          .take(3) // Take first 3 words
          .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
          .join('');

      _abbreviationController.text = abbreviation;
      _validateAbbreviation(abbreviation);
    } else {
      _abbreviationController.text = '';
      _validateAbbreviation('');
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Done'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  bool _canCreateTeam() {
    return _teamNameError == null &&
        _abbreviationError == null &&
        _teamNameController.text.trim().isNotEmpty &&
        !_isCreating;
  }

  void _validateTeamName(String value) {
    if (value.trim().isEmpty) {
      setState(() {
        _teamNameError = 'Team name is required';
      });
      return;
    }
  }

  void _validateAbbreviation(String value) {
    if (value.trim().length > 3) {
      setState(() {
        _abbreviationError = 'Abbreviation must be 3 characters or less';
      });
    }
    if (value.trim().isEmpty) {
      setState(() {
        _abbreviationError = 'Abbreviation is required';
      });
    }
  }

  void createTeam() async {
    final team = Team(
      name: _teamNameController.text,
      abbreviation: _abbreviationController.text,
      color: _selectedColor,
    );
    setState(() {
      _isCreating = true;
    });
    await widget.createTeam(team);
    setState(() {
      _isCreating = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team name field
          buildInputRow(
            label: 'Team Name',
            inputWidget: buildTextField(
              context: context,
              controller: _teamNameController,
              hint: 'Enter team name',
              error: _teamNameError,
              setSheetState: setState,
              onChanged: (value) {
                _validateTeamName(value);
                _generateAbbreviation(value);
              },
            ),
          ),
          const SizedBox(height: 24),

          // Abbreviation field
          buildInputRow(
            label: 'Abbreviation',
            inputWidget: buildTextField(
              context: context,
              controller: _abbreviationController,
              hint: 'Team abbreviation',
              error: _abbreviationError,
              setSheetState: setState,
              onChanged: _validateAbbreviation,
            ),
          ),
          const SizedBox(height: 24),

          // Color picker section
          const Text(
            'Team Color',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Color picker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Selected color preview and picker button
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Color',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _showColorPicker,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryColor,
                              side: BorderSide(color: AppColors.primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text('Choose Color'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canCreateTeam() ? createTeam : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Create Team',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
