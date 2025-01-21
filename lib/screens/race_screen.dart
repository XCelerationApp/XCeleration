// import 'dart:io';
import 'package:flutter/material.dart';
import 'timing_screen.dart';
import 'runners_management_screen.dart';
import 'bib_number_screen.dart';
// import 'package:provider/provider.dart';
import '../database_helper.dart';
import '../models/race.dart';
import 'race_info_screen.dart';
import 'results_screen.dart';
import '../main.dart';
// import 'races_screen.dart';
import 'edit_and_resolve_screen.dart';

class RaceScreen extends StatefulWidget {
  final Race race;
  final int initialTabIndex;
  final Map<String, dynamic> timingData;

  const RaceScreen({
    super.key, 
    required this.race,
    this.initialTabIndex = 0,
    this.timingData = const {'records': [], 'endTime': null, 'bibs': []},
  });

  @override
  _RaceScreenState createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  late Race race;
  String raceName = '';
  late Map<String, dynamic> timingData;


  @override
  void initState() {
    super.initState();
    race = widget.race;
    raceName = widget.race.race_name;
    timingData = widget.timingData;
    print('timingData: $timingData');
    _fetchRaceData();
  }

  void _fetchRaceData() async {
    // Fetch race data from the database
    final raceData = await DatabaseHelper.instance.getRaceById(race.race_id);
    setState(() {
      raceName = raceData?['race_name'] ?? 'Default Race Name'; // Update the race name
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: DatabaseHelper.instance.getRaceResults(race.race_id),
      builder: (context, snapshot) {
        final showResults = snapshot.hasData && snapshot.data!.isNotEmpty && snapshot.data!.every((runner) => runner['bib_number'] != null);
        List<Tab> tabs = showResults ? [
            Tab(icon: Icon(Icons.info_outline), text: 'Race Info'),
            Tab(icon: Icon(Icons.timer), text: 'Results'),
            Tab(icon: Icon(Icons.numbers), text: 'Record Bib Numbers'),
            Tab(icon: Icon(Icons.person), text: 'Runner Data'),
          ] : [
            Tab(icon: Icon(Icons.info_outline), text: 'Race Info'),
            // Tab(icon: Icon(Icons.timer), text: 'Time Race'),
            if (timingData['records'] != null && timingData['records']!.isNotEmpty && timingData['bibs'] != null && timingData['bibs']!.isNotEmpty)
              Tab(icon: Icon(Icons.checklist), text: 'Resolve Conflicts'),
            Tab(icon: Icon(Icons.numbers), text: 'Record Bib Numbers'),
            Tab(icon: Icon(Icons.person), text: 'Runner Data'),
          ];
        return DefaultTabController(
          length: tabs.length, 
          initialIndex: widget.initialTabIndex,
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: 48.0, // Set a smaller height
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, size: 20), // Reduce icon size if needed
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(-1.0, 0.0); // Move from left to right
                        const end = Offset.zero; // Final position
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        );
                      },
                    ),
                  );
                },
              ),
              title: Text(
                raceName,
                style: TextStyle(fontSize: 18), // Adjust font size
              ),
              bottom: TabBar(
                tabs: tabs,
                indicatorWeight: 3,
              ),
            ),
            body: TabBarView(
                children: [
                    RaceInfoScreen(raceId: race.race_id),
                    if (showResults) ResultsScreen(raceId: race.race_id), //else TimingScreen(race: race),
                    if (!showResults && (timingData['records'] != null && timingData['records']!.isNotEmpty && timingData['bibs'] != null && timingData['bibs']!.isNotEmpty)) EditAndResolveScreen(race: race, timingData: timingData),
                    BibNumberScreen (race: race),
                    RunnersManagementScreen(raceId: race.race_id, shared: false),
                ],
            ),
          ),
        );
      } 
    );
  }
}
