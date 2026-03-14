import 'package:flutter/material.dart';
import '../coach/races_screen/screen/races_screen.dart';
import '../spectator/races_screen/screen/spectator_races_screen.dart';
import '../assistant/race_timer/screen/timing_screen.dart';
import '../assistant/bib_number_recorder/screen/bib_number_screen.dart';
import '../assistant/bib_number_recorder/controller/bib_number_controller.dart';
import '../assistant/shared/services/assistant_storage_service.dart';
import '../assistant/shared/services/demo_race_generator_impl.dart';
import '../core/services/device_connection_factory_impl.dart';
import '../core/services/post_frame_scheduler.dart';
import '../core/services/tutorial_manager.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';
import '../core/components/page_route_animations.dart';
import '../core/services/auth_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/remote_api_client.dart';
import 'screens/sign_in_screen.dart';

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
                onPressed: () async {
                  if (!AuthService.instance.isSignedIn) {
                    Navigator.of(context).push(
                      InitialPageRouteAnimation(child: SignInScreen(
                    authService: AuthService.instance,
                    profileService: ProfileService(
                      remoteApi: RemoteApiClient(),
                      auth: AuthService.instance,
                    ),
                  )),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    InitialPageRouteAnimation(child: const RacesScreen()),
                  );
                },
              ),
              SizedBox(height: 15),
              buildRoleButton(
                text: 'Assistant',
                onPressed: () {
                  Navigator.of(context).push(
                    InitialPageRouteAnimation(
                        child: const AssistantRoleScreen()),
                  );
                },
              ),
              SizedBox(height: 15),
              buildRoleButton(
                text: 'Spectator',
                onPressed: () async {
                  // Spectators do not require sign-in; go straight to spectator UI
                  Navigator.of(context).push(
                    InitialPageRouteAnimation(
                        child: const SpectatorRacesScreen()),
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
                        InitialPageRouteAnimation(child: const TimingScreen()),
                      );
                    },
                  ),
                  SizedBox(height: 15),
                  buildRoleButton(
                    text: 'Recorder',
                    onPressed: () {
                      Navigator.of(context).push(
                        InitialPageRouteAnimation(
                          child: BibNumberScreen(
                            controller: BibNumberController(
                              storage: AssistantStorageService.instance,
                              tutorialManager: TutorialManager(),
                              demoRaceGenerator: const DemoRaceGeneratorImpl(),
                              deviceConnectionFactory:
                                  const DeviceConnectionFactoryImpl(),
                              scheduler: const PostFrameScheduler(),
                            ),
                          ),
                        ),
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
