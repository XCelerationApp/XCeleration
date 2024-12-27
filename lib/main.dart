import 'dart:io';
import 'package:flutter/material.dart';
// import 'screens/timing_screen.dart';
import 'screens/runners_management_screen.dart';
import 'screens/bib_number_screen.dart';
import 'package:provider/provider.dart';
import 'models/timing_data.dart';
import 'screens/races_screen.dart';
// import 'package:audioplayers/audioplayers.dart';

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
        primaryColor: Color(0xFF4CAF50),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.green, // Match the desired color for the FAB
        ).copyWith(
          secondary: Color(0xFF3E4E56),
          onPrimary: Colors.white, // For icon colors
        ),
        scaffoldBackgroundColor: Color(0xFFF4F4F9),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.black, // Cursor color
          selectionColor: Colors.grey[300], // Highlighted text background
          selectionHandleColor: Colors.grey, // Handles on selected text
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF3E4E56),
          foregroundColor: Colors.white, // Text/Icon color in AppBar
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        tabBarTheme: TabBarTheme(
          labelColor: Color(0xFF4CAF50),
          unselectedLabelColor: Colors.grey,
          indicator: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF4CAF50), width: 3),
            ),
          ),
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF212121)),
          bodySmall: TextStyle(color: Color(0xFF757575)),
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Color(0xFF4CAF50),
          textTheme: ButtonTextTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(color: Color(0xFF1B1B1B)),
            foregroundColor: const Color(0xFF1B1B1B), 
            
            // backgroundColor: Color.fromARGB(255, 98, 214, 102), // Default background color
        //     // padding: const EdgeInsets.symmetric(vertical: 16),
        //     shape: RoundedRectangleBorder(
        //       borderRadius: BorderRadius.circular(12),
        //     ),
        //     elevation: 2, // Default elevation
          ),
        ),
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
            RunnersManagementScreen(raceId: 0, shared: true),
          ],
        ),
      ),
    );
  }
}
