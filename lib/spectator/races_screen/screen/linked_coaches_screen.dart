import 'package:flutter/material.dart';
import 'package:xceleration/core/services/auth_service.dart';
import 'package:xceleration/core/services/parent_link_service.dart';
import 'package:xceleration/core/services/remote_api_client.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';

class LinkedCoachesScreen extends StatefulWidget {
  const LinkedCoachesScreen({super.key, ParentLinkService? parentLinkService})
      : _parentLinkService = parentLinkService;

  final ParentLinkService? _parentLinkService;

  @override
  State<LinkedCoachesScreen> createState() => _LinkedCoachesScreenState();
}

class _LinkedCoachesScreenState extends State<LinkedCoachesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _coaches = const [];

  ParentLinkService get _parentLinkService =>
      widget._parentLinkService ??
      ParentLinkService(
          remoteApi: RemoteApiClient(), auth: AuthService.instance);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _parentLinkService.listLinkedCoachesWithProfiles();
    if (!mounted) return;
    setState(() {
      _coaches = rows;
      _loading = false;
    });
  }

  Future<void> _unlink(String coachUserId) async {
    await _parentLinkService.unlinkCoach(coachUserId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        leading: const BackButton(),
        title: const Text('Linked Coaches'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _coaches.isEmpty
              ? Center(
                  child: Text('No linked coaches',
                      style: AppTypography.bodyRegular),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _coaches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final coach = _coaches[index];
                    final email = coach['email']?.toString() ?? '';
                    final name = coach['display_name']?.toString() ?? '';
                    final id = coach['coach_user_id']?.toString() ?? '';
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.person),
                        ),
                        title: Text(
                          name.isNotEmpty
                              ? name
                              : (email.isNotEmpty ? email : id),
                          style: AppTypography.bodySemibold,
                        ),
                        subtitle: email.isNotEmpty && name.isNotEmpty
                            ? Text(email)
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.link_off),
                          color: Colors.redAccent,
                          onPressed: () => _unlink(id),
                          tooltip: 'Unlink',
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
