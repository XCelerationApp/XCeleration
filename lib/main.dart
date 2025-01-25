import 'dart:io';
import 'package:flutter/material.dart';
// import 'screens/timing_screen.dart';
import 'screens/runners_management_screen.dart';
import 'screens/timing_screen.dart';
import 'package:provider/provider.dart';
import 'models/timing_data.dart';
import 'models/bib_data.dart';
import 'screens/races_screen.dart';
// import 'package:audioplayers/audioplayers.dart';
import 'constants.dart';
import 'package:flutter/services.dart';

Process? _flaskProcess;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock the orientation to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => TimingData(),
        ),
        ChangeNotifierProvider(
          create: (context) => BibRecordsProvider(),
        ),
      ],
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
        primaryColor: AppColors.backgroundColor,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blueGrey, // Match the desired color for the FAB
        ).copyWith(
          secondary: AppColors.backgroundColor,
          onPrimary: AppColors.lightColor, // For icon colors
        ),
        scaffoldBackgroundColor: AppColors.backgroundColor,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.darkColor, // Cursor color
          selectionColor: Colors.grey[300], // Highlighted text background
          selectionHandleColor: AppColors.mediumColor, // Handles on selected text
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.navBarColor,
          foregroundColor: AppColors.navBarTextColor, // Text/Icon color in AppBar
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        tabBarTheme: TabBarTheme(
          labelColor: AppColors.navBarTextColor,
          unselectedLabelColor: AppColors.backgroundColor,
          indicator: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.navBarTextColor, width: 3),
            ),
          ),
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: AppColors.darkColor),
          bodySmall: TextStyle(color: AppColors.mediumColor),
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: AppColors.navBarTextColor,
          textTheme: ButtonTextTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.mediumColor),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: TextStyle(color: AppColors.darkColor),
            foregroundColor: AppColors.darkColor, 
            
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
                Tab(icon: Icon(Icons.flag), text: 'Races'),
                Tab(icon: Icon(Icons.timer), text: 'Time Race'),
                Tab(icon: Icon(Icons.person), text: 'Shared Runner Data'),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            RacesScreen(),
            TimingScreen(),
            RunnersManagementScreen(raceId: 0, isTeam: true),
          ],
        ),
      ),
    );
  }
}
