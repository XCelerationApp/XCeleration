import 'package:flutter/material.dart';
import 'package:race_timing_app/database_helper.dart';
import 'package:race_timing_app/models/race.dart';
import 'package:race_timing_app/utils/sheet_utils.dart';
import 'package:race_timing_app/utils/app_colors.dart'; // Import AppColors

class RaceInfoScreen extends StatefulWidget {
  final int raceId;
  const RaceInfoScreen({
    super.key, 
    required this.raceId,
  });

  @override
  _RaceInfoScreenState createState() => _RaceInfoScreenState();
}

class _RaceInfoScreenState extends State<RaceInfoScreen> {
  late String _name = '';
  late String _location = '';
  late String _date = '';
  late String _distance = '';
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _dateController;
  late TextEditingController _distanceController;
  late int raceId;
  Race? race;

  @override
  void initState() {
    super.initState();
    raceId = widget.raceId;
    _loadRaceData();
  }

  Future<void> _loadRaceData() async {
    final raceData = await DatabaseHelper.instance.getRaceById(raceId);
    if (raceData != null) {
      setState(() {
        race = toRace(raceData);
        _name = race!.race_name;
        _location = race!.location;
        _date = race!.race_date.toString();
        _distance = race!.distance;
        final stringDate = DateTime.parse(race!.race_date.toString()).toIso8601String().split('T').first;

        _nameController = TextEditingController(text: _name);
        _locationController = TextEditingController(text: _location);
        _dateController = TextEditingController(text: stringDate);
        _distanceController = TextEditingController(text: _distance.toString());
      });
    }
    else {
      print('raceData is null');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required void Function(String) onChanged,
    TextInputType? keyboardType,
    String? hintText,
    Widget? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
              hintText: hintText,
              prefixIcon: prefixIcon,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.blueAccent,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (race == null) {
      return Center(
        child: CircularProgressIndicator(), // Show loading indicator
      );
    }

    bool hasChanges = _name != race!.race_name || 
                     _location != race!.location || 
                     _date != race!.race_date.toString() || 
                     _distance != race!.distance;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(
                        //   'Race Information',
                        //   style: TextStyle(
                        //     fontSize: 24,
                        //     fontWeight: FontWeight.bold,
                        //     color: Colors.grey[800],
                        //   ),
                        // ),
                        // const SizedBox(height: 24),
                        createSheetHandle(height: 15.0, width: 75.0),
                        _buildTextField(
                          label: 'Race Name',
                          controller: _nameController,
                          onChanged: (value) => setState(() => _name = value),
                          prefixIcon: const Icon(Icons.emoji_events_outlined),
                        ),
                        _buildTextField(
                          label: 'Location',
                          controller: _locationController,
                          onChanged: (value) => setState(() => _location = value),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                        ),
                        _buildTextField(
                          label: 'Date',
                          controller: _dateController,
                          onChanged: (value) {
                            setState(() => _date = value);
                            final date = DateTime.tryParse(value);
                            if (date != null) {
                              setState(() => _date = date.toString());
                            }
                          },
                          prefixIcon: IconButton(
                            icon: Icon(Icons.calendar_today),
                            onPressed: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                                firstDate: DateTime(2000), 
                                lastDate: DateTime(2101), 
                              );
                              if (pickedDate != null) {
                                _dateController.text = pickedDate.toLocal().toString().split(' ')[0];
                                setState(() => _date = pickedDate.toString()); 
                              }
                            },
                          ),
                          hintText: 'YYYY-MM-DD',
                          keyboardType: TextInputType.datetime,
                        ),
                        _buildTextField(
                          label: 'Distance',
                          controller: _distanceController,
                          onChanged: (value) {
                            final doubleDistance = double.tryParse(value);
                            if (doubleDistance != null) {
                              final distancePart = _distance.split(' ')[0];
                              setState(() => _distance.replaceAll(distancePart, doubleDistance.toString()));
                            }
                          },
                          keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
                          prefixIcon: const Icon(Icons.straighten),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasChanges) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.instance.updateRace({
                  'race_id': race?.race_id,
                  'race_name': _name,
                  'location': _location,
                  'race_date': _date,
                  'distance': _distance,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Changes saved successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
        ],
      ],
    );
  }
}