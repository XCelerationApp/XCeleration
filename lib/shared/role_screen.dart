import 'package:flutter/material.dart';
import '../coach/races_screen/screen/races_screen.dart';
import '../features/timing/screens/timing_screen.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';

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
        elevation: 5,
        shadowColor: Colors.black,
        minimumSize: const Size(300, 75),
      ),
      child: Text(
        text,
        style: AppTypography.displaySmall.copyWith(
          fontWeight: FontWeight.w400,
          // fontSize: AppTypography.titleLargeSize,
          color: AppColors.selectedRoleTextColor,
        ),
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
          color: AppColors.primaryColor,
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Welcome to XCeleration',
                style: AppTypography.displaySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30, width: double.infinity),
              Text(
                'Please select your role',
                style: AppTypography.titleRegular.copyWith(
                    fontWeight: FontWeight.w300,
                    color: AppColors.backgroundColor),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
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
  const AssistantRoleScreen({super.key, this.showBackArrow = true});

  final bool showBackArrow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Assistant Role',
                    style: AppTypography.displayMedium.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30, width: double.infinity),
                  Text(
                    'Please select your role',
                    style: AppTypography.titleRegular.copyWith(
                        fontWeight: FontWeight.w300,
                        color: AppColors.backgroundColor),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40),
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
                        CustomPageRoute(child: const TimingScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (showBackArrow)
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
