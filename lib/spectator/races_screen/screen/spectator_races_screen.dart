import 'package:flutter/material.dart';
import 'package:xceleration/coach/races_screen/screen/races_screen.dart';
import 'package:xceleration/spectator/races_screen/screen/add_coach_screen.dart';
import 'package:xceleration/spectator/races_screen/screen/linked_coaches_screen.dart';
import 'package:xceleration/core/services/connectivity_sync_service.dart';

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
      body: const RacesScreen(canEdit: false),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_coach',
            onPressed: () async {
              await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddCoachScreen()));
            },
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add Coach'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'linked_coaches',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LinkedCoachesScreen()));
            },
            icon: const Icon(Icons.people_outline),
            label: const Text('Linked Coaches'),
          ),
        ],
      ),
    );
  }
}
