import 'dart:io';
import 'package:flutter/material.dart';
// import 'screens/timing_screen.dart';
// import 'screens/runners_management_screen.dart';
import 'screens/timing_screen.dart';
import 'package:provider/provider.dart';
import 'models/timing_data.dart';
import 'screens/bib_number_screen.dart';
import 'models/bib_data.dart';
import 'screens/races_screen.dart';
// import 'models/race.dart';
// import 'package:audioplayers/audioplayers.dart';
import 'utils/app_colors.dart';
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
              bottom: BorderSide(color: AppColors.navBarTextColor, width: 0),
            ),
            // color: AppColors.navBarColor,
          ),
          // indicatorSize: TabBarIndicatorSize.tab,
          // indicatorPadding: EdgeInsets.zero,
          // indicatorColor: AppColors.navBarColor,
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
          ),
        ),
      ),

      home: const WelcomeScreen(),
      // home: const HomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to XCelerate!',
                style: TextStyle(fontSize: 35, fontWeight: FontWeight.w700, color: AppColors.backgroundColor),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'Please select your role',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300, color: AppColors.backgroundColor),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const RacesScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20.0),
                  ),
                  child: Text('Coach', style: TextStyle(fontSize: 30, color: AppColors.selectedRoleTextColor)),
                ),
              ),
              SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const TimingScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20.0),
                  ),
                  child: Text('Timer', style: TextStyle(fontSize: 30, color: AppColors.selectedRoleTextColor)),
                ),
              ),
              SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => BibNumberScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20.0),
                  ),
                  child: Text('Record Bib #s', style: TextStyle(fontSize: 30, color: AppColors.selectedRoleTextColor)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// class HomeScreen extends StatelessWidget {
//   const HomeScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 3, // Number of tabs
//       child: Scaffold(
//         appBar: PreferredSize(
//           preferredSize: Size.fromHeight(80.0),
//           child: AppBar(
//             // title: const Text('Race Timing App'),
//             bottom: const TabBar(
//               tabs: [
//                 Tab(icon: Icon(Icons.flag), text: 'Races'),
//                 Tab(icon: Icon(Icons.timer), text: 'Time Race'),
//                 Tab(icon: Icon(Icons.person), text: 'Team Runners'),
//               ],
//             ),
//           ),
//         ),
//         body: const TabBarView(
//           physics: NeverScrollableScrollPhysics(),
//           children: [
//             RacesScreen(),
//             TimingScreen(),
//             RunnersManagementScreen(raceId: 0, isTeam: true),
//           ],
//         ),
//       ),
//     );
//   }
// }
