import 'package:flutter/material.dart';
import 'package:xceleration/core/services/connectivity_sync_service.dart';
import 'package:xceleration/shared/role_bar/role_bar.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart'
    as role_enums;
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/spectator/receive_race/screen/receive_race_screen.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';

/// A thin wrapper that renders the coach races screen in read-only mode
class SpectatorRacesScreen extends StatefulWidget {
  const SpectatorRacesScreen({super.key});

  @override
  State<SpectatorRacesScreen> createState() => _SpectatorRacesScreenState();
}

class _SpectatorRacesScreenState extends State<SpectatorRacesScreen> {
  @override
  void initState() {
    super.initState();
    ConnectivitySyncService.instance.start();
  }

  @override
  void dispose() {
    ConnectivitySyncService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Start with an empty spectator home; races are not saved locally
      body: Column(
        children: [
          RoleBar(
            currentRole: role_enums.Role.spectator,
            tutorialManager: TutorialManager(),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Icon(Icons.wifi_tethering, size: 48, color: Colors.black54),
                    SizedBox(height: 12),
                    Text(
                      'No races loaded yet',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap Receive Race to get a race from a nearby coach.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'receive_race',
            onPressed: () async {
              await sheet(
                context: context,
                title: 'Receive Race',
                body: const ReceiveRaceScreen(),
                takeUpScreen: false,
              );
            },
            icon: const Icon(Icons.wifi),
            label: const Text('Receive Race'),
          ),
          const SizedBox(height: 12),
          // FloatingActionButton.extended(
          //   heroTag: 'add_coach',
          //   onPressed: () async {
          //     await Navigator.of(context).push(
          //         MaterialPageRoute(builder: (_) => const AddCoachScreen()));
          //   },
          //   icon: const Icon(Icons.person_add_alt_1),
          //   label: const Text('Add Coach'),
          // ),
          // const SizedBox(height: 12),
          // FloatingActionButton.extended(
          //   heroTag: 'linked_coaches',
          //   onPressed: () async {
          //     await Navigator.of(context).push(MaterialPageRoute(
          //         builder: (_) => const LinkedCoachesScreen()));
          //   },
          //   icon: const Icon(Icons.people_outline),
          //   label: const Text('Linked Coaches'),
          // ),
        ],
      ),
    );
  }
}
