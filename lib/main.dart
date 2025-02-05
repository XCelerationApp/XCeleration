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
import 'package:flutter_native_splash/flutter_native_splash.dart';

Process? _flaskProcess;

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
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
      title: 'XCelerate',
      theme: ThemeData(
        primaryColor: AppColors.backgroundColor,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.deepOrange,
        ).copyWith(
          secondary: AppColors.backgroundColor,
          onPrimary: AppColors.lightColor,
        ),
        scaffoldBackgroundColor: AppColors.backgroundColor,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.darkColor,
          selectionColor: Colors.grey[300],
          selectionHandleColor: AppColors.mediumColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.navBarColor,
          foregroundColor: AppColors.navBarTextColor,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        tabBarTheme: TabBarTheme(
          labelColor: AppColors.navBarTextColor,
          unselectedLabelColor: AppColors.backgroundColor,
          indicator: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.navBarTextColor, width: 0),
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
          ),
        ),
      ),
      home: const InitializationScreen(),
    );
  }
}

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  InitializationScreenState createState() => InitializationScreenState();
}

class InitializationScreenState extends State<InitializationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Color?> _backgroundAnimation;
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 33.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.5)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 67.0,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 80.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 20.0,
      ),
    ]).animate(_controller);

    _backgroundAnimation = ColorTween(
      begin: const Color(0xFFFF5722), // Deep Orange (matches splash screen)
      end: AppColors.primaryColor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeInOut),
    ));

    // Start with a tiny delay to ensure smooth transition from splash screen
    Future.delayed(const Duration(milliseconds: 100), () async {
      FlutterNativeSplash.remove();
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Start the animation
      _controller.forward();
      
      // After 1 second, show the text
      // await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        setState(() {
          _showText = true;
        });
      }

      // After animation completes, navigate to welcome screen
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
              opacity: animation,
              child: const WelcomeScreen(),
            ),
            transitionDuration: const Duration(milliseconds: 2000),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Handle error case if needed
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _backgroundAnimation.value,
          body: Center(
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_showText) ...[
                      const SizedBox(height: 60),
                    ],
                    Image.asset(
                      'assets/icon/icon.png',
                      width: MediaQuery.of(context).size.height / 3,
                      height: MediaQuery.of(context).size.height / 3,
                    ),
                    if (_showText) ...[
                      const SizedBox(height: 20),
                      Text(
                        'XCelerate',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppColors.backgroundColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
