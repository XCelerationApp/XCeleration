import 'dart:io';
import 'package:flutter/material.dart';
// import 'screens/timing_screen.dart';
import 'runners_management.dart';
import 'screens/bib_number_screen.dart';
import 'package:provider/provider.dart';
import 'models/timing_data.dart';
import 'screens/races_screen.dart';
import 'package:audioplayers/audioplayers.dart';

Process? _flaskProcess;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await AudioPlayer.platformPath;
  // await startFlaskServer();
  runApp(
    ChangeNotifierProvider(
      create: (context) => TimingData(),
      child: const MyApp(),
    ),
  );
}

Future<void> startFlaskServer() async {
  print('Starting Flask Server...');
  _flaskProcess =  await Process.start('python', ['lib/server/mnist_image_classification.py']);
}

void stopFlaskServer() {
  print('Stopping Flask Server');
  _flaskProcess?.kill(); // Stop the Flask server
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  void dispose() {
    stopFlaskServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Race Timing App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Number of tabs
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(80.0),
          child: AppBar(
            // title: const Text('Race Timing App'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.person), text: 'Races'),
                Tab(icon: Icon(Icons.numbers), text: 'Record Bib Numbers'),
                Tab(icon: Icon(Icons.person), text: 'Shared Runner Data'),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            RacesScreen(),
            BibNumberScreen(),
            RunnersManagement(raceId: 0, shared: true),
          ],
        ),
      ),
    );
  }
}
