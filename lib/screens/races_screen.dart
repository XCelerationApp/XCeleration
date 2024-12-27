import 'package:flutter/material.dart';
import '../models/race.dart';
import '../database_helper.dart';
// import 'race_detail_screen.dart';
// import 'race_info_screen.dart';
import 'race_screen.dart';

class RacesScreen extends StatefulWidget {
  const RacesScreen({super.key});

  @override
  _RacesScreenState createState() => _RacesScreenState();
}


class _RacesScreenState extends State<RacesScreen> {
  List<Race> races = [];
  
  @override
  void initState() {
    super.initState();
    _loadRaces();
  }
  
  Future<void> _loadRaces() async {
    final races = await DatabaseHelper.instance.getAllRaces();
    setState(() {
      this.races = races;
    });
  }

  void _showCreateRaceDialog(BuildContext context) {
    final nameController = TextEditingController(text: 'Untitled Race');
    final locationController = TextEditingController(text: '');
    final dateController = TextEditingController(text: '');
    final distanceController = TextEditingController(text: '');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create New Race'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                  hintText: 'Untitled Race',
                  ),
                ),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    hintText: 'Location',
                  ),
                ),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    hintText: 'Date (YYYY-MM-DD)',
                  ),
                ),
                TextField(
                  controller: distanceController,
                  decoration: InputDecoration(
                    hintText: 'Distance',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    locationController.text.isEmpty ||
                    dateController.text.isEmpty ||
                    distanceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please fill in all the fields'),
                    ),
                  );
                  return;
                }
                DateTime date;
                double distance;
                try {
                  date = DateTime.parse(dateController.text);
                  if (date.year < 1900) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Date must be in the future'),
                      ),
                    );
                    return;
                  }
                  distance = double.parse(distanceController.text);
                  if (distance < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Distance must be positive'),
                      ),
                    );
                    return;
                  }
                } on FormatException {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invalid date or distance'),
                    ),
                  );
                  return;
                }

                final id = await DatabaseHelper.instance.insertRace({
                    'race_name': nameController.text,
                    'location': locationController.text,
                    'race_date': dateController.text,
                    'distance': distance,
                });
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RaceScreen(race:  Race(
                      raceId: id,
                      raceName: nameController.text,
                      location: locationController.text,
                      raceDate: date,
                      distance: distance,
                    )),
                  ),
                );
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Races'),
      ),
      body: FutureBuilder<List<Race>>(
        future: DatabaseHelper.instance.getAllRaces(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No races found.'));
          }
          races = snapshot.data ?? [];

          return ListView.builder(
              itemCount: races.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    trailing: GestureDetector(
                      child: Icon(Icons.delete, color: Colors.grey),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text('Delete race'),
                              content: Text('Are you sure you want to delete ${races[index].race_name}?'),
                              actions: [
                                TextButton(
                                  child: Text('Cancel'),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                TextButton(
                                  child: Text('Delete'),
                                  onPressed: () async {
                                    await DatabaseHelper.instance.deleteRace(races[index].raceId);
                                    final newRaces = await DatabaseHelper.instance.getAllRaces();
                                    setState(() {
                                      races = newRaces;
                                    });
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    title: Text(races[index].race_name),
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => RaceScreen(
                            race: races[index],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRaceDialog(context),
        tooltip: 'Create new race',
        child: Icon(Icons.add),
      ),
    );
  }
}
