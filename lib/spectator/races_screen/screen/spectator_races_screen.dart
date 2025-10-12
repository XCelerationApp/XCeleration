import 'package:flutter/material.dart';
import 'package:xceleration/core/services/connectivity_sync_service.dart';
import 'package:xceleration/shared/role_bar/role_bar.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart'
    as role_enums;
import 'package:xceleration/core/services/tutorial_manager.dart';
import 'package:xceleration/spectator/receive_race/screen/receive_race_screen.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/spectator/services/spectator_storage_service.dart';
import 'package:xceleration/core/utils/race_share_decoder.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/spectator/races_screen/widgets/spectator_race_card.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/components/connection_components.dart';
import 'package:xceleration/shared/services/race_results_service.dart';
import 'package:xceleration/coach/race_results/widgets/team_results_widget.dart';
import 'package:xceleration/coach/race_results/widgets/individual_results_widget.dart';
import 'package:xceleration/core/theme/app_colors.dart';

/// Spectator races screen showing saved races and allowing receiving new ones
class SpectatorRacesScreen extends StatefulWidget {
  const SpectatorRacesScreen({super.key});

  @override
  State<SpectatorRacesScreen> createState() => _SpectatorRacesScreenState();
}

class _SpectatorRacesScreenState extends State<SpectatorRacesScreen> {
  List<Map<String, dynamic>> _savedRaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    ConnectivitySyncService.instance.start();
    _loadSavedRaces();
  }

  @override
  void dispose() {
    ConnectivitySyncService.instance.stop();
    super.dispose();
  }

  Future<void> _loadSavedRaces() async {
    try {
      final races = await SpectatorStorageService.instance.getAllRaces();
      if (mounted) {
        setState(() {
          _savedRaces = races;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.e('Failed to load saved races: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _viewRace(Map<String, dynamic> race) async {
    try {
      final encodedPayload = race['encoded_payload'] as String;
      final decoded = RaceShareDecoder.decodeWithRaw(encodedPayload);
      final raceName = race['race_name'] as String? ?? 'Race Results';

      if (!mounted) return;

      // Show in a sheet instead of navigating
      await sheet(
        context: context,
        title: raceName,
        body: _RaceResultsSheet(
          data: decoded.results,
          encodedPayload: decoded.rawEncoded,
          onShare: () => _shareRace(race),
        ),
      );
    } catch (e) {
      Logger.e('Failed to view race: $e');
      if (mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to load race');
      }
    }
  }

  Future<void> _shareRace(Map<String, dynamic> race) async {
    try {
      final encodedPayload = race['encoded_payload'] as String;
      final raceName = race['race_name'] as String? ?? 'Race';

      if (!mounted) return;

      final devices = DeviceConnectionService.createDevices(
        DeviceName.spectator,
        DeviceType.advertiserDevice,
        data: encodedPayload,
        toSpectator: true, // Share to another spectator
      );

      await sheet(
        context: context,
        title: 'Share "$raceName"',
        body: WirelessConnectionWidget(
          devices: devices,
          callback: () {
            // Share complete callback
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      );
    } catch (e) {
      Logger.e('Failed to share race: $e');
      if (mounted) {
        DialogUtils.showErrorDialog(context, message: 'Failed to share race');
      }
    }
  }

  Future<void> _deleteRace(int raceId, String raceName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Race'),
        content: Text('Are you sure you want to delete "$raceName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SpectatorStorageService.instance.deleteRace(raceId);
        _loadSavedRaces();
      } catch (e) {
        Logger.e('Failed to delete race: $e');
        if (mounted) {
          DialogUtils.showErrorDialog(context,
              message: 'Failed to delete race');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
        child: Column(
          children: [
            RoleBar(
              currentRole: role_enums.Role.spectator,
              tutorialManager: TutorialManager(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _savedRaces.isEmpty
                      ? Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: const [
                                Text(
                                  'No races received yet',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap Receive Race to get a race from a nearby coach or spectator.',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black54),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadSavedRaces,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ..._savedRaces.map((race) {
                                    final raceName =
                                        race['race_name'] as String? ??
                                            'Unnamed Race';
                                    final raceId = race['id'] as int;

                                    return SpectatorRaceCard(
                                      race: race,
                                      onTap: () => _viewRace(race),
                                      onShare: () => _shareRace(race),
                                      onDelete: () =>
                                          _deleteRace(raceId, raceName),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'receive_race',
        onPressed: () async {
          // Ask user who they are receiving from
          final result = await sheet(
            context: context,
            title: 'Receive Race From',
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person,
                              color: AppColors.primaryColor),
                        ),
                        title: const Text(
                          'Coach',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: const Text('Receive race from a coach'),
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.visibility,
                              color: AppColors.primaryColor),
                        ),
                        title: const Text(
                          'Another Spectator',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle:
                            const Text('Receive race from another spectator'),
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          final bool? fromSpectator = result as bool?;
          if (fromSpectator == null) return;
          if (!context.mounted) return;

          await sheet(
              context: context,
              title: 'Receive Race',
              body: ReceiveRaceScreen(fromSpectator: fromSpectator),
              takeUpScreen: false);

          // Refresh the list after receiving a race
          _loadSavedRaces();
        },
        icon: const Icon(Icons.wifi),
        label: const Text('Receive Race'),
      ),
    );
  }
}

/// Sheet widget to show race results
class _RaceResultsSheet extends StatelessWidget {
  final RaceResultsData data;
  final String encodedPayload;
  final VoidCallback onShare;

  const _RaceResultsSheet({
    required this.data,
    required this.encodedPayload,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Results content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TeamResultsWidget(raceResultsData: data),
                    IndividualResultsWidget(
                      raceResultsData: data,
                      initialVisibleCount: 10,
                    ),
                    const SizedBox(height: 80), // Extra padding for FAB
                  ],
                ),
              ),
            ),
          ],
        ),
        // Floating action button for sharing
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: onShare,
            backgroundColor: AppColors.primaryColor,
            child: const Icon(Icons.ios_share, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
