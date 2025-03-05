import 'package:flutter/material.dart';
import '../coach/races_screen/screen/races_screen.dart';
import '../assistant/race_timer/timing_screen/screen/timing_screen.dart';
import '../assistant/bib_number_recorder/bib_number_screen/screen/bib_number_screen.dart';
import '../core/theme/app_colors.dart';

class CustomPageRoute extends PageRouteBuilder {
  final Widget child;

  CustomPageRoute({required this.child})
      : super(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Curves.easeInOut;
            var fadeAnimation = animation.drive(CurveTween(curve: curve));

            return FadeTransition(
              opacity: fadeAnimation,
              child: child,
            );
          },
        );
}

Widget buildRoleButton({
  required String text,
  required VoidCallback onPressed,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20.0),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(20.0),
        fixedSize: const Size(300, 75),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 30, color: AppColors.selectedRoleTextColor),
      ),
    ),
  );
}

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryColor,
              AppColors.primaryColor.withAlpha((0.9 * 255).round()),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Text(
                'Welcome to XCelerate',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40, width: double.infinity),
              Text(
                'Please select your role',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300, color: AppColors.backgroundColor),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              buildRoleButton(
                text: 'Coach',
                onPressed: () {
                  Navigator.of(context).push(
                    CustomPageRoute(child: const RacesScreen()),
                  );
                },
              ),
              SizedBox(height: 15),
              buildRoleButton(
                text: 'Assistant',
                onPressed: () {
                  Navigator.of(context).push(
                    CustomPageRoute(child: const AssistantRoleScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AssistantRoleScreen extends StatelessWidget {
  const AssistantRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryColor,
                  AppColors.primaryColor.withAlpha((0.9 * 255).round()),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Assistant Role',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40, width: double.infinity),
                  Text(
                    'Please select your role',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300, color: AppColors.backgroundColor),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                  buildRoleButton(
                    text: 'Timer',
                    onPressed: () {
                      Navigator.of(context).push(
                        CustomPageRoute(child: const TimingScreen()),
                      );
                    },
                  ),
                  SizedBox(height: 15),
                  buildRoleButton(
                    text: 'Recorder',
                    onPressed: () {
                      Navigator.of(context).push(
                        CustomPageRoute(child: const BibNumberScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 8.0),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
