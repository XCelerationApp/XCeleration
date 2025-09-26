import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:xceleration/core/utils/database_helper.dart';
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
  Timer? _nameDebounce;
  Set<String> _existingTeamNamesLower = <String>{};

  @override
  void initState() {
    super.initState();
    // Preload ALL team names from the database (not just this race)
    DatabaseHelper.instance.getAllTeams().then((teams) {
      if (!mounted) return;
      setState(() {
        _existingTeamNamesLower =
            teams.map((t) => (t.name ?? '').trim().toLowerCase()).toSet();
      });
    });
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
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

      setState(() {
        _abbreviationController.text = abbreviation;
        // Avoid showing abbreviation errors while typing the team name
        _abbreviationError = null;
      });
      // Do not validate abbreviation while typing team name
    } else {
      setState(() {
        _abbreviationController.text = '';
        // Avoid showing abbreviation errors while typing the team name
        _abbreviationError = null;
      });
      // Do not validate abbreviation while typing team name
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // No need to show color info; keeping only selected color value

  bool _canCreateTeam() {
    // Enable when all inputs are filled (including programmatic/autofill)
    final hasName = _teamNameController.text.trim().isNotEmpty;
    final hasAbbreviation = _abbreviationController.text.trim().isNotEmpty;
    return hasName && hasAbbreviation && !_isCreating;
  }

  void _validateTeamName(String value) {
    final trimmed = value.trim();
    setState(() {
      _teamNameError = trimmed.isEmpty ? 'Team name is required' : null;
    });

    // Debounced local uniqueness check using preloaded names
    _nameDebounce?.cancel();
    if (trimmed.isNotEmpty) {
      _nameDebounce = Timer(const Duration(milliseconds: 500), () {
        final exists = _existingTeamNamesLower.contains(trimmed.toLowerCase());
        if (!mounted) return;
        if (_teamNameController.text.trim() != trimmed) return;
        setState(() {
          _teamNameError = exists ? 'Team already exists' : null;
        });
      });
    }
  }

  void _validateAbbreviation(String value) {
    final trimmed = value.trim();
    setState(() {
      if (trimmed.isEmpty) {
        _abbreviationError = 'Abbreviation is required';
      } else if (trimmed.length > 3) {
        _abbreviationError = 'Abbreviation must be 3 characters or less';
      } else {
        _abbreviationError = null;
      }
    });
  }

  Future<bool> _validateAll() async {
    final name = _teamNameController.text.trim();
    final abbr = _abbreviationController.text.trim();

    String? nameError;
    String? abbrError;

    if (name.isEmpty) {
      nameError = 'Team name is required';
    }
    // Uniqueness check (local list)
    if (nameError == null &&
        _existingTeamNamesLower.contains(name.toLowerCase())) {
      nameError = 'Team already exists';
    }
    if (abbr.isEmpty) {
      abbrError = 'Abbreviation is required';
    } else if (abbr.length > 3) {
      abbrError = 'Abbreviation must be 3 characters or less';
    }

    setState(() {
      _teamNameError = nameError;
      _abbreviationError = abbrError;
    });

    return nameError == null && abbrError == null;
  }

  void createTeam() async {
    // Validate on submit and surface errors
    final isValid = await _validateAll();
    if (!isValid) return;

    final team = Team(
      name: _teamNameController.text,
      abbreviation: _abbreviationController.text,
      color: _selectedColor,
    );
    setState(() {
      _isCreating = true;
    });
    await widget.createTeam(team);
    if (!mounted) return; // Parent may have popped the sheet in the callback
    setState(() {
      _isCreating = false;
    });
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(team);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
          const SizedBox(height: 16),

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
          const SizedBox(height: 16),

          // Color picker section styled like an input row
          buildInputRow(
            label: 'Team Color',
            inputWidget: Row(
              children: [
                GestureDetector(
                  onTap: _showColorPicker,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showColorPicker,
                    icon: const Icon(Icons.color_lens_outlined, size: 18),
                    label: const Text('Change Color'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      foregroundColor: AppColors.primaryColor,
                      side: BorderSide(color: AppColors.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canCreateTeam() ? createTeam : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
